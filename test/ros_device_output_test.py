#!/usr/bin/env python3
"""Exercise the Scout udp.v1 HOLD host with its actual simulated SDK output.

Owns a private ROS master and temporary keys. A fixture-only sleep barrier
keeps ROS receipt and UDP IO running while delaying the native control loop.
"""
import argparse
import base64
import collections
import json
import os
from pathlib import Path
import re
import secrets
import signal
import socket
import subprocess
import tempfile
import time
import xmlrpc.client


def wait_for(check, label, seconds=5, interval=.02):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(interval)
    raise AssertionError(label)


def stop(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGINT)
        try:
            process.wait(5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise AssertionError('process did not quiesce on SIGINT')
    else:
        process.wait()


def free_port(kind):
    for _ in range(100):
        port = 20000 + secrets.randbelow(20001)
        with socket.socket(socket.AF_INET, kind) as reservation:
            try:
                reservation.bind(('127.0.0.1', port))
                return port
            except OSError:
                pass
    raise AssertionError('no private port available in 20000..40000')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--devel', required=True, type=Path)
    parser.add_argument('--helpers', required=True, type=Path)
    args = parser.parse_args()
    processes = []
    with tempfile.TemporaryDirectory(prefix='scout-hold-') as temporary:
        directory = Path(temporary)
        port = free_port(socket.SOCK_STREAM)
        hold_port = free_port(socket.SOCK_DGRAM)
        console = directory/'rosconsole.config'
        console.write_text('log4j.logger.ros.scout_base=DEBUG\n')
        env = os.environ.copy()
        env.update(ROS_MASTER_URI=f'http://127.0.0.1:{port}', ROS_HOSTNAME='127.0.0.1',
                   ROS_IP='127.0.0.1', ROS_HOME=str(directory/'ros-home'),
                   ROS_LOG_DIR=str(directory/'ros-log'), ROSCONSOLE_CONFIG_FILE=str(console),
                   ROSCONSOLE_STDOUT_LINE_BUFFERED='1')
        os.environ.update({key: env[key] for key in
                           ('ROS_MASTER_URI', 'ROS_HOSTNAME', 'ROS_IP', 'ROS_HOME', 'ROS_LOG_DIR')})
        barrier = directory/'loop-barrier'
        key_file = directory/'hold.key'
        wrong_key = directory/'wrong.key'
        unreadable_key = directory/'unreadable.key'
        for path in (key_file, wrong_key, unreadable_key):
            path.write_text('1 ' + base64.b64encode(secrets.token_bytes(32)).decode('ascii') + '\n')
            path.chmod(0o600)
            assert path.stat().st_uid == os.geteuid() and path.stat().st_mode & 0o777 == 0o600
        unreadable_key.chmod(0o000)
        log_path = directory/'process.log'
        log = log_path.open('w+')

        def launch(command, extra=None, capture=False):
            configuration = env.copy()
            configuration.update(extra or {})
            process = subprocess.Popen(command, env=configuration,
                                       stdout=subprocess.PIPE if capture else log,
                                       stderr=subprocess.STDOUT, text=True, start_new_session=True)
            processes.append(process)
            return process

        def cli_command(*words, key=key_file, timeout=2000):
            return ['xgc2-hold', '--endpoint', f'127.0.0.1:{hold_port}',
                    '--key-file', str(key), '--timeout-ms', str(timeout), *words]

        def cli(*words, key=key_file, timeout=2000, code=0):
            result = subprocess.run(cli_command(*words, key=key, timeout=timeout),
                                    env=env, capture_output=True, text=True, timeout=6)
            assert result.returncode == code, f'CLI {words}: {result.stdout} {result.stderr}'
            return json.loads(result.stdout)

        def state():
            return cli('state', '--robot', 'scout-fixture')['reply']['robots'][0]

        def writes(since=0):
            return [(float(linear), float(angular)) for linear, angular in re.findall(
                r'Scout motion command written: linear=([^ ]+) angular=([^\s\x1b]+)',
                log_path.read_text()[since:])]

        try:
            core = launch(['roscore', '-p', str(port)])

            def master_ready():
                assert core.poll() is None, 'private roscore startup failed'
                try:
                    return xmlrpc.client.ServerProxy(env['ROS_MASTER_URI']).getPid('/fixture')[0] == 1
                except (ConnectionError, OSError):
                    return False

            wait_for(master_ready, 'private roscore timeout')
            import rospy
            from geometry_msgs.msg import Twist
            from scout_msgs.msg import ScoutStatus
            rospy.init_node('scout_hold_fixture', disable_signals=True)
            values = collections.deque(maxlen=2000)
            subscriber = rospy.Subscriber('/fixture/scout_status', ScoutStatus,
                lambda msg: values.append((time.monotonic(), msg.linear_velocity, msg.angular_velocity)))
            publisher = rospy.Publisher('/fixture/cmd_vel', Twist, queue_size=100)

            def driver(key=key_file, *options):
                # Private parameters outlive a node on the master. Each launch
                # must test its own defaults, not the preceding node's settings.
                if rospy.has_param('/scout_odom'):
                    rospy.delete_param('/scout_odom')
                preload = str(args.helpers/'libscout_loop_barrier.so')
                runtime = env.get('SCOUT_TEST_RUNTIME_PRELOAD', '')
                if runtime:
                    preload = runtime + ':' + preload
                return launch([str(args.devel/'lib/scout_base/scout_base_node'),
                               '_simulated_robot:=true', '_hold_robot_id:=scout-fixture',
                               f'_hold_port:={hold_port}', f'_hold_key_file:={key}',
                               '/cmd_vel:=/fixture/cmd_vel', '/scout_status:=/fixture/scout_status',
                               *options], {'LD_PRELOAD': preload, 'SCOUT_TEST_LOOP_BARRIER': str(barrier)})

            def connected(process):
                assert process.poll() is None, 'driver exited unexpectedly'
                return publisher.get_num_connections() == 1

            def publish(value):
                twist = Twist()
                twist.linear.x, twist.angular.z = value, value/2
                publisher.publish(twist)

            def saw(value, since):
                return any(linear == value for linear, _ in writes(since))

            scout = driver()
            wait_for(lambda: connected(scout), 'driver ROS startup timeout')
            described = cli('describe')['reply']
            instance = described['instance']
            assert described['robots'] == ['scout-fixture'] and described['feedback']['scout-fixture']
            initial = state()
            assert not initial['held'] and initial['revision'] == 0 and initial['stage'] == 'released'
            offset = log_path.stat().st_size
            publish(.2)
            wait_for(lambda: saw(.2, offset), 'released command did not reach Scout output')
            wait_for(lambda: any(linear == .2 for _, linear, _ in list(values)), 'simulated state did not move')

            engaged = cli('engage', '--robot', 'scout-fixture')['reply']['robots'][0]
            assert engaged['outcome'] == 'engaged' and engaged['revision'] == 1
            assert engaged['stage'] == 'zero_written', 'native tick did not write zero for engage'
            assert state()['stage'] == 'zero_written'
            offset = log_path.stat().st_size
            for _ in range(15):
                publish(.4)
                time.sleep(.01)
            held_writes = writes(offset)
            assert len(held_writes) >= 5, 'zero output was not re-asserted across control ticks'
            assert all(command == (0, 0) for command in held_writes), 'held command reached Scout output'

            def stopped_state():
                current = state()
                return current if current['stage'] == 'stopped' else None

            stopped = wait_for(stopped_state, 'resting Scout state did not report stopped', interval=.08)
            assert stopped['zero_written_at_ms'] <= stopped['stopped_at_ms']
            assert stopped['stopped_at_ms'] - stopped['zero_written_at_ms'] >= 300

            stale = cli('release', '--robot', 'scout-fixture=0', '--instance', instance, code=1)
            assert stale['reply']['robots'][0]['outcome'] == 'conflict' and state()['held']
            stale_instance = ('1' if instance[0] != '1' else '2') + instance[1:]
            rejected = cli('release', '--robot', 'scout-fixture=1', '--instance', stale_instance, code=2)
            assert rejected['status'] == 'conflict' and state()['held']
            unauthenticated = cli('engage', '--all', key=wrong_key, timeout=250, code=2)
            assert unauthenticated['disposition'] == 'outcome_unknown' and 'reply' not in unauthenticated
            released = cli('release', '--robot', 'scout-fixture=1', '--instance', instance)['reply']['robots'][0]
            assert released['outcome'] == 'released' and released['revision'] == 2
            offset = log_path.stat().st_size
            time.sleep(.10)
            assert not writes(offset), 'release replayed a command received while held'
            publish(.3)
            wait_for(lambda: saw(.3, offset), 'release did not accept a fresh command')

            engaged = cli('engage', '--all')['reply']['robots'][0]
            assert engaged['held'] and engaged['revision'] == 3
            barrier.touch()
            wait_for(lambda: Path(str(barrier)+'.paused').exists(), 'native control loop did not pause')
            offset = log_path.stat().st_size
            publish(.6)
            time.sleep(.10)  # ROS IO receives it while the main loop sleeps.
            pending = launch(cli_command('release', '--robot', 'scout-fixture=3', '--instance', instance), capture=True)
            time.sleep(.20)
            assert pending.poll() is None, 'release did not wait for the native tick'
            barrier.unlink()
            output, _ = pending.communicate(timeout=6)
            assert pending.returncode == 0 and json.loads(output)['reply']['robots'][0]['outcome'] == 'released'
            wait_for(lambda: 'Scout motion command dropped: held=false' in log_path.read_text()[offset:],
                     'queued receipt was not dropped after the release opened the gate')
            assert not saw(.6, offset), 'pre-release receipt reached Scout output after release'
            publish(.7)
            wait_for(lambda: saw(.7, offset), 'fresh command rejected after queued release')
            stop(scout)
            assert scout.returncode == 0, 'normal driver shutdown failed'
            wait_for(lambda: publisher.get_num_connections() == 0, 'driver subscriber did not close')

            boot = driver(key_file, '_hold_boot_held:=true')
            wait_for(lambda: connected(boot), 'boot-held driver startup timeout')
            assert state()['held'] and state()['revision'] == 1
            assert cli('describe')['reply']['instance'] != instance, 'restart reused the HOLD instance'
            offset = log_path.stat().st_size
            publish(.8)
            time.sleep(.12)
            assert not saw(.8, offset), 'boot-held driver accepted motion'
            stop(boot)
            assert boot.returncode == 0
            wait_for(lambda: publisher.get_num_connections() == 0, 'boot-held subscriber did not close')

            # Missing and unreadable keys must obey the same required/optional rule.
            bad_keys = [directory/'missing.key']
            if os.geteuid() != 0:
                bad_keys.append(unreadable_key)
            for key in bad_keys:
                required = driver(key)
                required.wait(timeout=6)
                assert required.returncode != 0, 'hold_required accepted an unusable key'
                offset = log_path.stat().st_size
                optional = driver(key, '_hold_required:=false', '_hold_boot_held:=true')
                wait_for(lambda: connected(optional), 'optional HOLD driver failed to start')
                publish(.9)
                wait_for(lambda: saw(.9, offset), 'optional HOLD without a key did not pass commands')
                absent = cli('describe', timeout=250, code=2)
                assert 'reply' not in absent, 'optional HOLD exposed a service without a key'
                stop(optional)
                assert optional.returncode == 0
                assert log_path.read_text()[offset:].count('HOLD unavailable; driving without HOLD:') == 1
                wait_for(lambda: publisher.get_num_connections() == 0, 'optional subscriber did not close')
            subscriber.unregister()
            publisher.unregister()
            print(f'PASS Scout HOLD: receipt fence, zero ticks, state feedback, CAS, keys, boot and shutdown '
                  f'(master {port}, UDP {hold_port}, ROS_HOME {env["ROS_HOME"]})')
        except Exception:
            print(log_path.read_text()[-10000:])
            raise
        finally:
            if barrier.exists():
                barrier.unlink()
            cleanup_errors = []
            for process in reversed(processes):
                try:
                    stop(process)
                except Exception as error:
                    cleanup_errors.append(error)
            if 'rospy' in locals():
                rospy.signal_shutdown('fixture complete')
            log.close()
            assert not cleanup_errors, f'process cleanup failed: {cleanup_errors}'


if __name__ == '__main__':
    main()
