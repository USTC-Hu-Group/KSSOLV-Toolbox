"""Native HTTP job lifecycle, cancellation, isolation and failure regression."""

import _docker_paths
import json
import threading
import time
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from fixtures.model_api import Handler
from http_worker import HTTPWorker


class WorkerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.provider = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        threading.Thread(target=cls.provider.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.provider.shutdown()
        cls.provider.server_close()

    def setUp(self):
        self.worker = HTTPWorker().start()

    def tearDown(self):
        self.worker.close()

    def request(self, path, method='GET', data=None, token=None):
        headers = {'Authorization': 'Bearer ' + (token or self.worker.token),
                   'Content-Type': 'application/json'}
        body = None if data is None else json.dumps(data).encode()
        request = Request('http://127.0.0.1:%d%s' % (self.worker.server_port, path),
                          body, headers, method=method)
        with urlopen(request, timeout=3) as response:
            return json.load(response)

    def start(self, mode):
        return self.request('/requests', 'POST', {
            'url': 'http://127.0.0.1:%d/%s/models' % (self.provider.server_port, mode),
            'headers': {'Authorization': 'Bearer fixture-provider-key'}})['id']

    def result(self, identity):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            result = self.request('/requests/' + identity)
            if result['state'] == 'finished':
                return result
            time.sleep(0.01)
        self.fail('HTTP job did not finish')

    def test_success_and_authenticated_access(self):
        with self.assertRaises(HTTPError) as denied:
            self.request('/requests/unknown', token='another-instance-token')
        self.assertEqual(denied.exception.code, 403)
        denied.exception.close()
        identity = self.start('success')
        self.assertEqual(len(self.result(identity)['response']['data']), 2)
        self.request('/requests/' + identity, 'DELETE')
        self.assertFalse(self.worker.jobs)

    def test_failures_are_structured_and_do_not_return_credentials(self):
        for mode, kind in [('unauthorized', 'http'), ('limited', 'http'), ('invalid', 'json')]:
            identity = self.start(mode)
            result = self.result(identity)
            self.assertEqual(result['error']['kind'], kind)
            self.assertNotIn('fixture-provider-key', json.dumps(result))
            self.request('/requests/' + identity, 'DELETE')

    def test_cancel_closes_pending_job_and_allows_retry(self):
        identity = self.start('slow')
        time.sleep(0.1)
        started = time.monotonic()
        self.request('/requests/' + identity, 'DELETE')
        self.assertLess(time.monotonic() - started, 1)
        self.assertNotIn(identity, self.worker.jobs)
        next_job = self.start('success')
        self.assertEqual(self.result(next_job)['state'], 'finished')


if __name__ == '__main__':
    unittest.main()
