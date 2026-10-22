"""Actual HTTP streaming, bounded failure and cancellation for Online chat."""

import _docker_paths
import json
import threading
import time
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from fixtures.chat_api import Handler
from http_worker import HTTPWorker


class ChatWorkerTests(unittest.TestCase):
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
        Handler.calls.clear()

    def tearDown(self):
        self.worker.close()

    def request(self, path, method='GET', data=None, token=None):
        request = Request('http://127.0.0.1:%d%s' % (self.worker.server_port, path),
                          None if data is None else json.dumps(data).encode(),
                          {'Authorization': 'Bearer ' + (token or self.worker.token),
                           'Content-Type': 'application/json'}, method=method)
        with urlopen(request, timeout=3) as response:
            return json.load(response)

    def start(self, prompt):
        return self.request('/chat', 'POST', {
            'url': 'http://127.0.0.1:%d/chat/completions' % self.provider.server_port,
            'headers': {'Authorization': 'Bearer fixture-provider-key'},
            'parameters': {'model': 'fixture-deepseek', 'stream': True,
                           'messages': [{'role': 'user', 'content': prompt}],
                           'tools': [{'type': 'function'}]}})['id']

    def result(self, identity):
        deadline = time.monotonic() + 5
        tokens = []
        while time.monotonic() < deadline:
            result = self.request('/requests/' + identity)
            tokens.extend(result['tokens'])
            if result['state'] == 'finished':
                return result, ''.join(tokens)
            time.sleep(0.02)
        self.fail('Chat job did not finish')

    def test_stream_preserves_model_content_and_drains_each_token_once(self):
        identity = self.start('hello')
        result, text = self.result(identity)
        self.assertEqual(text, 'reply from fixture-deepseek')
        self.assertEqual(result['response']['model'], 'fixture-deepseek')
        self.assertEqual(len(Handler.calls), 1)
        self.assertEqual(self.request('/requests/' + identity)['tokens'], [])
        self.request('/requests/' + identity, 'DELETE')
        self.assertFalse(self.worker.jobs)

    def test_tool_rejection_retries_same_prompt_without_tools_only(self):
        identity = self.start('reject tools')
        result, _ = self.result(identity)
        self.assertIn('response', result)
        self.assertEqual([call['tools'] for call in Handler.calls], [True, False])
        self.assertEqual(Handler.calls[0]['model'], Handler.calls[1]['model'])
        self.assertEqual(Handler.calls[0]['messages'], Handler.calls[1]['messages'])

    def test_auth_errors_and_partial_replies_are_not_retried(self):
        for prompt, kind in [('unauthorized', 'http'), ('truncated', 'incomplete')]:
            before = len(Handler.calls)
            identity = self.start(prompt)
            result, _ = self.result(identity)
            self.assertEqual(result['error']['kind'], kind)
            self.assertEqual(len(Handler.calls), before + 1)
            self.assertNotIn('fixture-provider-key', json.dumps(result))
            self.assertNotIn('response', result)

    def test_cancel_during_first_token_wait_is_prompt(self):
        identity = self.start('slow first token')
        time.sleep(0.1)
        started = time.monotonic()
        self.request('/requests/' + identity, 'DELETE')
        self.assertLess(time.monotonic() - started, 1)
        self.assertNotIn(identity, self.worker.jobs)

    def test_structured_tool_call_and_json_reply_remain_distinct(self):
        result, text = self.result(self.start('use fixture tool'))
        call = result['response']['choices'][0]['message']['tool_calls'][0]
        self.assertEqual(call['function']['name'], 'getCurrentGraph')
        self.assertEqual(call['function']['arguments'], '{}')
        self.assertEqual(text, '')
        result, text = self.result(self.start('JSON reply'))
        self.assertEqual(text, '{"answer":42}')
        self.assertNotIn('tool_calls', result['response']['choices'][0]['message'])

    def test_chat_requires_the_instance_token(self):
        with self.assertRaises(HTTPError) as denied:
            self.request('/chat', 'POST', {}, token='other-instance')
        self.assertEqual(denied.exception.code, 403)
        denied.exception.close()
        self.assertFalse(self.worker.jobs)


if __name__ == '__main__':
    unittest.main()
