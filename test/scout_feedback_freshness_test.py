#!/usr/bin/env python3
"""Actual native Scout components with no device connection and mock CAN frames.

Own a private ROS master, temporary keys, and random local UDP in 20000..40000.
No device, SocketCAN interface, live station, or production HOLD endpoint is used.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time
import xmlrpc.client

from ros_device_output_test import free_port, stop, wait_for


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', required=True)
    args = parser.parse_args()
    processes = []
    with tempfile.TemporaryDirectory(prefix='scout-feedback-freshness-') as temporary:
        directory = Path(temporary)
        master_port = free_port(socket.SOCK_STREAM)
        udp_port = free_port(socket.SOCK_DGRAM)
        environment = os.environ.copy()
        environment.update(ROS_MASTER_URI=f'http://127.0.0.1:{master_port}', ROS_IP='127.0.0.1',
                           ROS_HOSTNAME='127.0.0.1', ROS_HOME=str(directory/'ros-home'),
                           ROS_LOG_DIR=str(directory/'ros-log'))
        key = directory/'hold.key'
        key.write_text('1 ' + base64.b64encode(secrets.token_bytes(32)).decode() + '\n')
        key.chmod(0o600)
        mode_file = directory/'mode'
        mode_file.write_text('absent')
        log_path = directory/'process.log'
        with log_path.open('w+') as log:
            def launch(command):
                process = subprocess.Popen(command, env=environment, stdout=log,
                                           stderr=subprocess.STDOUT, start_new_session=True)
                processes.append(process)
                return process

            def cli(method, *words):
                result = subprocess.run(['xgc2-hold', '--endpoint', f'127.0.0.1:{udp_port}',
                                         '--key-file', str(key), '--timeout-ms', '1000', method, *words],
                                        env=environment, capture_output=True, text=True, timeout=4)
                assert result.returncode == 0, f'{method}: {result.stdout} {result.stderr}'
                return json.loads(result.stdout)['reply']

            def state():
                return cli('state')['robots'][0]

            def mode(name):
                pending = directory/'mode-next'
                pending.write_text(name)
                pending.replace(mode_file)

            def stays_zero_written(duration=.45):
                deadline = time.monotonic() + duration
                while time.monotonic() < deadline:
                    current = state()
                    assert current['held'] and current['stage'] == 'zero_written', current
                    time.sleep(.04)

            try:
                master = launch(['roscore', '-p', str(master_port)])

                def ready():
                    assert master.poll() is None, 'private ROS master exited'
                    try:
                        return xmlrpc.client.ServerProxy(environment['ROS_MASTER_URI']).getPid('/fixture')[0] == 1
                    except OSError:
                        return False

                wait_for(ready, 'private ROS master readiness')
                host = launch([args.host, '_hold_robot_id:=scout-feedback-fixture',
                               f'_hold_port:={udp_port}', f'_hold_key_file:={key}',
                               f'_fixture_mode_file:={mode_file}'])
                time.sleep(.4)
                assert host.poll() is None, log_path.read_text()
                instance = cli('describe')['instance']
                engaged = cli('engage', '--all')['robots'][0]
                assert engaged['held'] and engaged['stage'] == 'zero_written', engaged
                stays_zero_written()  # default SDK zeros are not measurements
                for invalid in ('system', 'short', 'oversized', 'unknown'):
                    mode(invalid)
                    stays_zero_written()

                # One genuine rest frame cannot become a stream of fresh rest
                # just because PublishStateToROS/ControlTick keep polling it.
                mode('once')
                time.sleep(.06)
                mode('absent')
                stays_zero_written(.5)
                mode('moving')
                stays_zero_written()

                mode('rest')
                wait_for(lambda: state()['stage'] == 'stopped', 'fresh motion rest did not satisfy dwell',
                         interval=.05)
                stopped = state()
                assert stopped['stopped_at_ms'] - stopped['zero_written_at_ms'] >= 300, stopped
                mode('system')  # other status traffic cannot keep motion fresh
                wait_for(lambda: state()['stage'] == 'zero_written', 'stale motion feedback kept stopped',
                         interval=.04)
                stays_zero_written()

                # A new hold cannot reuse a rest sample from the previous hold.
                revision = state()['revision']
                cli('release', '--instance', instance, '--robot', f'scout-feedback-fixture={revision}')
                cli('engage', '--all')
                stays_zero_written()
                mode('rest')
                wait_for(lambda: state()['stage'] == 'stopped', 'fresh rest did not recover after stale interval',
                         interval=.05)
                mode('moving')
                wait_for(lambda: state()['stage'] == 'zero_written', 'fresh moving telemetry kept stopped',
                         interval=.04)
                stop(host)
                mode('rest')
                plain = launch([args.host, '_hold_robot_id:=scout-feedback-fixture',
                                f'_hold_port:={udp_port}', f'_hold_key_file:={key}',
                                f'_fixture_mode_file:={mode_file}', '_fixture_plain_base:=true'])
                time.sleep(.4)
                assert plain.poll() is None, log_path.read_text()
                assert cli('describe')['instance'] != instance
                cli('engage', '--all')
                stays_zero_written(.6)  # legacy plain base has no trusted receipt
                print(f'PASS Scout feedback: absent/invalid/stale motion stays unknown; '
                      f'fresh tracked rest dwells; plain base stays unknown; '
                      f'no Connect, in-memory CAN, master {master_port}, UDP {udp_port}')
            except Exception:
                log.flush()
                print(log_path.read_text()[-10000:])
                raise
            finally:
                for process in reversed(processes):
                    stop(process)


if __name__ == '__main__':
    main()
