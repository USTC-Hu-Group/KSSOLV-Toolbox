"""Read Linux resource counters without subprocesses or Kubernetes credentials.

Pod CPU percentages are relative to the assigned cores. Memory is the cgroup
working set (usage minus inactive file cache), matching the usual Pod metric.
Standalone Docker reports the Linux host visible through /proc, including the
Docker VM when Docker Desktop is used. No privileged host mounts are needed.
"""
import os
from pathlib import Path
import threading
import time


class ResourceUsage:
    def __init__(self, proc='/proc', cgroup='/sys/fs/cgroup', environ=None, clock=time.monotonic):
        self.proc, self.cgroup = Path(proc), Path(cgroup)
        self.environ = os.environ if environ is None else environ
        self.clock = clock
        self.pod = self.environ.get('KSSOLV_RESOURCE_SCOPE') == 'pod' or bool(self.environ.get('KUBERNETES_SERVICE_HOST'))
        self.previous = None
        self.value = {'available': False, 'scope': 'pod' if self.pod else 'host'}
        self.stop = threading.Event()

    def sample(self):
        now = self.clock()
        meminfo = dict((key.rstrip(':'), int(value.split()[0]) * 1024)
                       for key, value in (line.split(None, 1) for line in (self.proc/'meminfo').read_text().splitlines()))
        if self.pod:
            if (self.cgroup/'cpu.stat').exists():
                stats = dict(line.split() for line in (self.cgroup/'cpu.stat').read_text().splitlines())
                used_cpu = int(stats['usage_usec']) / 1e6
                quota, period = (self.cgroup/'cpu.max').read_text().split()
                cores = float(quota) / float(period) if quota != 'max' else None
                used_mem = int((self.cgroup/'memory.current').read_text())
                limit = (self.cgroup/'memory.max').read_text().strip()
                total_mem = int(limit) if limit != 'max' else None
                stats = dict(line.split() for line in (self.cgroup/'memory.stat').read_text().splitlines())
                cache = int(stats.get('inactive_file', 0))
            else:
                used_cpu = int((self.cgroup/'cpuacct/cpuacct.usage').read_text()) / 1e9
                quota = int((self.cgroup/'cpu/cpu.cfs_quota_us').read_text())
                cores = quota / int((self.cgroup/'cpu/cpu.cfs_period_us').read_text()) if quota > 0 else None
                used_mem = int((self.cgroup/'memory/memory.usage_in_bytes').read_text())
                total_mem = int((self.cgroup/'memory/memory.limit_in_bytes').read_text())
                stats = dict(line.split() for line in (self.cgroup/'memory/memory.stat').read_text().splitlines())
                cache = int(stats.get('total_inactive_file', stats.get('inactive_file', 0)))
            # Downward API environment values are fixed at container startup.
            # Prefer the current cgroup limits so in-place resizing is visible.
            if cores is None and self.environ.get('KSSOLV_ALLOCATED_CPU_MILLICORES'):
                cores = float(self.environ['KSSOLV_ALLOCATED_CPU_MILLICORES']) / 1000
            if (total_mem is None or total_mem >= 1 << 60) and self.environ.get('KSSOLV_ALLOCATED_MEMORY_BYTES'):
                total_mem = int(self.environ['KSSOLV_ALLOCATED_MEMORY_BYTES'])
            if not cores or cores <= 0 or not total_mem:
                raise ValueError('Pod allocation is unavailable')
            used_mem = max(0, used_mem - cache)
            counter = used_cpu
        else:
            lines = (self.proc/'stat').read_text().splitlines()
            times = [int(value) for value in lines[0].split()[1:9]]
            total = sum(times)
            idle = sum(times[3:5])
            counter = (total, idle)
            cores = sum(line.startswith('cpu') and line[3:4].isdigit() for line in lines)
            total_mem = meminfo['MemTotal']
            available = meminfo.get('MemAvailable', meminfo.get('MemFree', 0) + meminfo.get('Buffers', 0) + meminfo.get('Cached', 0))
            used_mem = max(0, total_mem - available)
        percent = None
        if self.previous is not None:
            old_time, old_counter = self.previous
            if self.pod and now > old_time and counter >= old_counter:
                percent = 100 * (counter - old_counter) / (now - old_time) / cores
            elif not self.pod and counter[0] > old_counter[0]:
                percent = 100 * (1 - (counter[1] - old_counter[1]) / (counter[0] - old_counter[0]))
        self.previous = now, counter
        self.value = {'available': True, 'scope': 'pod' if self.pod else 'host',
                      'cpuPercent': max(0, min(100, percent)) if percent is not None else None,
                      'cpuCores': cores, 'memoryUsedBytes': used_mem, 'memoryTotalBytes': total_mem,
                      'sampledAt': time.time()}
        return self.value

    def start(self):
        def run():
            while not self.stop.is_set():
                try:
                    self.sample()
                except (OSError, ValueError, KeyError, IndexError, ZeroDivisionError):
                    self.value = {'available': False, 'scope': 'pod' if self.pod else 'host'}
                self.stop.wait(2)
        threading.Thread(target=run, daemon=True, name='kssolv-resources').start()
        return self

    def close(self):
        self.stop.set()
