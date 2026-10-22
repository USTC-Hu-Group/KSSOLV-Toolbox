
import _docker_paths
import http.client
import json
from pathlib import Path
import tempfile
import unittest

from http_worker import HTTPWorker
from resource_usage import ResourceUsage
from serve import nginx_config


class ResourceUsageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.proc = self.root/'proc'
        self.cg = self.root/'cgroup'
        self.proc.mkdir()
        self.cg.mkdir()
        (self.proc/'meminfo').write_text('MemTotal: 16384 kB\nMemAvailable: 12288 kB\n')
        (self.proc/'stat').write_text('cpu 100 0 100 800 0 0 0 0 0 0\ncpu0 1\ncpu1 1\n')
        self.time = 10

    def sampler(self, env):
        return ResourceUsage(self.proc, self.cg, env, lambda: self.time)

    def pod_files(self):
        for name, value in {'cpu.stat':'usage_usec 2000000\n', 'cpu.max':'400000 100000',
                            'memory.current':'3145728', 'memory.max':'8388608',
                            'memory.stat':'inactive_file 1048576\n'}.items():
            (self.cg/name).write_text(value)

    def test_pod_uses_allocated_cpu_and_working_set(self):
        self.pod_files()
        sampler = self.sampler({'KSSOLV_RESOURCE_SCOPE':'pod'})
        self.assertIsNone(sampler.sample()['cpuPercent'])
        self.time += 2
        (self.cg/'cpu.stat').write_text('usage_usec 6000000\n')
        value = sampler.sample()
        self.assertEqual(value['scope'], 'pod')
        self.assertEqual(value['cpuPercent'], 50)
        self.assertEqual(value['cpuCores'], 4)
        self.assertEqual(value['memoryUsedBytes'], 2097152)
        self.assertEqual(value['memoryTotalBytes'], 8388608)

    def test_downward_api_falls_back_when_cgroup_is_unlimited(self):
        self.pod_files()
        (self.cg/'cpu.max').write_text('max 100000')
        (self.cg/'memory.max').write_text('max')
        value = self.sampler({'KSSOLV_RESOURCE_SCOPE':'pod', 'KSSOLV_ALLOCATED_CPU_MILLICORES':'500',
                              'KSSOLV_ALLOCATED_MEMORY_BYTES':'4194304'}).sample()
        self.assertEqual(value['cpuCores'], .5)
        self.assertEqual(value['memoryTotalBytes'], 4194304)

    def test_in_place_resize_overrides_stale_startup_environment(self):
        self.pod_files()
        sampler = self.sampler({'KSSOLV_RESOURCE_SCOPE': 'pod',
                                'KSSOLV_ALLOCATED_CPU_MILLICORES': '4000',
                                'KSSOLV_ALLOCATED_MEMORY_BYTES': str(8 << 30)})
        (self.cg/'memory.max').write_text(str(8 << 30))
        self.assertEqual(sampler.sample()['memoryTotalBytes'], 8 << 30)
        self.time += 2
        (self.cg/'cpu.max').write_text('800000 100000')
        (self.cg/'memory.max').write_text(str(16 << 30))
        (self.cg/'cpu.stat').write_text('usage_usec 6000000\n')
        value = sampler.sample()
        self.assertEqual(value['cpuCores'], 8)
        self.assertEqual(value['memoryTotalBytes'], 16 << 30)
        self.assertEqual(value['cpuPercent'], 25)

    def test_cgroup_v1_resize_and_unlimited_fallback(self):
        for name, value in {'cpuacct/cpuacct.usage': '2000000000',
                            'cpu/cpu.cfs_quota_us': '-1', 'cpu/cpu.cfs_period_us': '100000',
                            'memory/memory.usage_in_bytes': '3145728',
                            'memory/memory.limit_in_bytes': str((1 << 63) - 4096),
                            'memory/memory.stat': 'total_inactive_file 1048576\n'}.items():
            path = self.cg/name
            path.parent.mkdir(exist_ok=True)
            path.write_text(value)
        sampler = self.sampler({'KSSOLV_RESOURCE_SCOPE': 'pod',
                                'KSSOLV_ALLOCATED_CPU_MILLICORES': '4000',
                                'KSSOLV_ALLOCATED_MEMORY_BYTES': str(8 << 30)})
        initial = sampler.sample()
        self.assertEqual(initial['cpuCores'], 4)
        self.assertEqual(initial['memoryTotalBytes'], 8 << 30)
        (self.cg/'cpu/cpu.cfs_quota_us').write_text('800000')
        (self.cg/'memory/memory.limit_in_bytes').write_text(str(16 << 30))
        value = sampler.sample()
        self.assertEqual(value['cpuCores'], 8)
        self.assertEqual(value['memoryTotalBytes'], 16 << 30)
        self.assertEqual(value['memoryUsedBytes'], 2097152)

    def test_docker_uses_host_counters_even_when_container_is_limited(self):
        self.pod_files()
        sampler = self.sampler({})
        sampler.sample()
        self.time += 2
        (self.proc/'stat').write_text('cpu 200 0 100 900 0 0 0 0 0 0\ncpu0 1\ncpu1 1\n')
        value = sampler.sample()
        self.assertEqual(value['scope'], 'host')
        self.assertEqual(value['cpuPercent'], 50)
        self.assertEqual(value['cpuCores'], 2)
        self.assertEqual(value['memoryUsedBytes'], 4194304)
        self.assertEqual(value['memoryTotalBytes'], 16777216)

    def test_missing_pod_counters_never_report_the_host_as_pod(self):
        sampler = self.sampler({'KSSOLV_RESOURCE_SCOPE':'pod'})
        with self.assertRaises(OSError):
            sampler.sample()
        self.assertEqual(sampler.value, {'available':False, 'scope':'pod'})

    def test_metrics_require_auth_and_never_cache(self):
        sampler = self.sampler({})
        sampler.sample()
        worker = HTTPWorker(resources=sampler).start()
        self.addCleanup(worker.close)
        connection = http.client.HTTPConnection('127.0.0.1', worker.server_port)
        self.addCleanup(connection.close)
        connection.request('GET', '/resources')
        response = connection.getresponse()
        self.assertEqual(response.status, 403)
        response.read()
        connection.request('GET', '/resources', headers={'Authorization':'Bearer '+worker.token})
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        self.assertEqual(response.getheader('Cache-Control'), 'no-store')
        self.assertEqual(json.loads(response.read())['scope'], 'host')
        config = nginx_config({'protocol':1, 'url':'https://127.0.0.1:12345/a'}, worker=worker,
                              auth_file='/run/secrets/htpasswd')
        self.assertIn('location = /_kssolv/resources', config)
        self.assertIn('auth_basic "KSSOLV Toolbox Online"', config)


if __name__ == '__main__':
    unittest.main()
