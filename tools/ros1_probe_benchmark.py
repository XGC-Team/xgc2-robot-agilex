#!/usr/bin/env python
"""Benchmark ROS1 readiness probes.

This script is intended to run on the robot after sourcing the ROS environment.
It compares CLI probes such as rosnode/rostopic with direct XML-RPC probes.
"""

from __future__ import print_function

import argparse
import os
import resource
import socket
import subprocess
import sys
import time

try:
    from xmlrpc.client import ServerProxy
except ImportError:
    from xmlrpclib import ServerProxy


DEVNULL = open(os.devnull, "wb")


def read_cpu_stat():
    with open("/proc/stat", "r") as f:
        fields = f.readline().split()[1:]
    values = [int(x) for x in fields]
    idle = values[3] + (values[4] if len(values) > 4 else 0)
    total = sum(values)
    return total, idle


def cpu_percent(before, after):
    total_delta = after[0] - before[0]
    idle_delta = after[1] - before[1]
    if total_delta <= 0:
        return 0.0
    return 100.0 * float(total_delta - idle_delta) / float(total_delta)


def usage_seconds(who):
    usage = resource.getrusage(who)
    return float(usage.ru_utime + usage.ru_stime)


def wait_process(proc, timeout):
    deadline = time.time() + timeout
    while True:
        rc = proc.poll()
        if rc is not None:
            return rc
        if time.time() >= deadline:
            try:
                proc.kill()
            except OSError:
                pass
            try:
                proc.wait()
            except OSError:
                pass
            return 124
        time.sleep(0.01)


def run_command(argv, timeout):
    proc = subprocess.Popen(argv, stdout=DEVNULL, stderr=DEVNULL)
    rc = wait_process(proc, timeout)
    if rc != 0:
        raise RuntimeError("command failed: %s rc=%s" % (" ".join(argv), rc))


class RosApi(object):
    def __init__(self, node, topic, timeout, topic_timeout):
        socket.setdefaulttimeout(timeout)
        self.node = node
        self.topic = topic
        self.timeout = timeout
        self.topic_timeout = topic_timeout
        self._master = None
        self._rospy_started = False

    @property
    def master(self):
        if self._master is None:
            import rosgraph
            self._master = rosgraph.Master("/xgc2_probe_benchmark")
        return self._master

    def master_getpid(self):
        self.master.getPid()

    def lookup_node(self):
        self.master.lookupNode(self.node)

    def node_getpid(self):
        uri = self.master.lookupNode(self.node)
        ServerProxy(uri).getPid("/xgc2_probe_benchmark")

    def wait_topic_once(self):
        if not self._rospy_started:
            import rospy
            rospy.init_node("xgc2_probe_benchmark", anonymous=True, disable_signals=True)
            self._rospy_started = True
        import rospy
        from rospy.msg import AnyMsg
        rospy.wait_for_message(self.topic, AnyMsg, timeout=self.topic_timeout)


def percentile(values, pct):
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = int(round((pct / 100.0) * (len(ordered) - 1)))
    return ordered[idx]


def benchmark_probe(name, func, iterations, period, cpu_scope):
    wall_times = []
    ok = 0
    fail = 0
    first_error = None

    sys_before = read_cpu_stat()
    client_before = usage_seconds(cpu_scope)
    started = time.time()

    for _ in range(iterations):
        t0 = time.time()
        try:
            func()
            ok += 1
        except Exception as exc:
            fail += 1
            if first_error is None:
                first_error = str(exc)
        wall_times.append(time.time() - t0)
        if period > 0:
            time.sleep(period)

    elapsed = time.time() - started
    client_after = usage_seconds(cpu_scope)
    sys_after = read_cpu_stat()

    return {
        "name": name,
        "ok": ok,
        "fail": fail,
        "elapsed": elapsed,
        "mean_ms": 1000.0 * sum(wall_times) / float(len(wall_times) or 1),
        "p95_ms": 1000.0 * percentile(wall_times, 95),
        "max_ms": 1000.0 * max(wall_times or [0.0]),
        "client_cpu_s": client_after - client_before,
        "system_cpu_pct": cpu_percent(sys_before, sys_after),
        "first_error": first_error or "",
    }


def print_results(results):
    header = (
        "probe",
        "ok",
        "fail",
        "elapsed_s",
        "mean_ms",
        "p95_ms",
        "max_ms",
        "client_cpu_s",
        "system_cpu_pct",
    )
    print("\t".join(header))
    for r in results:
        print(
            "%s\t%d\t%d\t%.3f\t%.2f\t%.2f\t%.2f\t%.3f\t%.1f"
            % (
                r["name"],
                r["ok"],
                r["fail"],
                r["elapsed"],
                r["mean_ms"],
                r["p95_ms"],
                r["max_ms"],
                r["client_cpu_s"],
                r["system_cpu_pct"],
            )
        )
        if r["first_error"]:
            print("# %s first_error: %s" % (r["name"], r["first_error"]))


def build_probes(args):
    api = RosApi(args.node, args.topic, args.timeout, args.topic_timeout)

    probes = [
        ("api_master_getpid", api.master_getpid, resource.RUSAGE_SELF),
        ("api_lookup_node", api.lookup_node, resource.RUSAGE_SELF),
        ("api_node_getpid", api.node_getpid, resource.RUSAGE_SELF),
        (
            "cli_rosnode_ping",
            lambda: run_command(["rosnode", "ping", "-c", "1", args.node], args.timeout),
            resource.RUSAGE_CHILDREN,
        ),
    ]

    if args.suite in ("topic", "full"):
        probes.extend(
            [
                ("api_wait_topic_once", api.wait_topic_once, resource.RUSAGE_SELF),
                (
                    "cli_rostopic_echo_once",
                    lambda: run_command(["rostopic", "echo", "-n", "1", args.topic], args.timeout),
                    resource.RUSAGE_CHILDREN,
                ),
                (
                    "cli_rostopic_info",
                    lambda: run_command(["rostopic", "info", args.topic], args.timeout),
                    resource.RUSAGE_CHILDREN,
                ),
            ]
        )

    if args.suite == "full":
        probes.extend(
            [
                (
                    "cli_rosnode_list",
                    lambda: run_command(["rosnode", "list"], args.timeout),
                    resource.RUSAGE_CHILDREN,
                ),
                (
                    "cli_rostopic_list",
                    lambda: run_command(["rostopic", "list"], args.timeout),
                    resource.RUSAGE_CHILDREN,
                ),
            ]
        )

    return probes


def main():
    parser = argparse.ArgumentParser(description="Benchmark ROS1 readiness probe overhead.")
    parser.add_argument("--suite", choices=("safe", "topic", "full"), default="safe")
    parser.add_argument("--iterations", type=int, default=30)
    parser.add_argument("--period", type=float, default=0.2)
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument("--topic-timeout", type=float, default=2.0)
    parser.add_argument("--node", default="/rosout")
    parser.add_argument("--topic", default="/imu/data_raw")
    args = parser.parse_args()

    print("# suite=%s iterations=%d period=%.3f node=%s topic=%s" % (
        args.suite,
        args.iterations,
        args.period,
        args.node,
        args.topic,
    ))
    print("# source the target ROS setup before running this script")

    results = []
    for name, func, cpu_scope in build_probes(args):
        results.append(benchmark_probe(name, func, args.iterations, args.period, cpu_scope))

    print_results(results)
    return 0 if all(r["fail"] == 0 for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
