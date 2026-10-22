"""A container restart must recover stale X11 files without displacing a server."""

import _docker_paths
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import unittest

from serve import cleanup_virtual_display


class DisplayRecoveryTest(unittest.TestCase):
    def test_dead_lock_and_socket_are_removed_but_other_files_survive(self):
        with tempfile.TemporaryDirectory(prefix='/tmp/ks-x-') as directory:
            root = Path(directory)
            endpoint = root / '.X11-unix' / 'X99'
            endpoint.parent.mkdir()
            with socket.socket(socket.AF_UNIX) as stale:
                stale.bind(str(endpoint))
            lock = root / '.X99-lock'
            lock.write_text('2147483647\n')
            saved = root / 'saved-project'
            saved.write_text('preserved')
            cleanup_virtual_display(root)
            self.assertFalse(lock.exists())
            self.assertFalse(endpoint.exists())
            self.assertEqual(saved.read_text(), 'preserved')
            cleanup_virtual_display(root)  # A clean first start is also valid.

    def test_live_lock_owner_is_preserved(self):
        with tempfile.TemporaryDirectory(prefix='/tmp/ks-x-') as directory:
            root = Path(directory)
            lock = root / '.X99-lock'
            lock.write_text(str(os.getpid()))
            with self.assertRaisesRegex(RuntimeError, 'live lock owner'):
                cleanup_virtual_display(root)
            self.assertTrue(lock.exists())

    def test_listening_display_is_preserved_without_a_valid_lock(self):
        with tempfile.TemporaryDirectory(prefix='/tmp/ks-x-') as directory:
            root = Path(directory)
            endpoint = root / '.X11-unix' / 'X99'
            endpoint.parent.mkdir()
            lock = root / '.X99-lock'
            lock.write_text('broken')
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(str(endpoint))
                server.listen(1)
                with self.assertRaisesRegex(RuntimeError, 'already listening'):
                    cleanup_virtual_display(root)
                self.assertTrue(endpoint.exists())
                self.assertEqual(lock.read_text(), 'broken')

    @unittest.skipUnless(sys.platform.startswith('linux') and shutil.which('Xvfb'),
                         'requires Linux Xvfb (run in Docker)')
    def test_xvfb_restarts_after_sigkill_with_the_same_temporary_volume(self):
        # Docker's private /tmp and PID namespace isolate this display from users.
        display = 197
        endpoint = Path(f'/tmp/.X11-unix/X{display}')
        lock = Path(f'/tmp/.X{display}-lock')
        cleanup_virtual_display(display=display)
        process = None
        try:
            for attempt in range(2):
                process = subprocess.Popen(['Xvfb', f':{display}', '-screen', '0',
                                            '1280x900x24', '-nolisten', 'tcp'])
                deadline = time.monotonic() + 10
                while not endpoint.exists():
                    self.assertIsNone(process.poll())
                    self.assertLess(time.monotonic(), deadline)
                    time.sleep(0.05)
                with self.assertRaises(RuntimeError):
                    cleanup_virtual_display(display=display)
                process.send_signal(signal.SIGKILL)
                process.wait(timeout=5)
                self.assertTrue(lock.exists())
                self.assertTrue(endpoint.exists())
                cleanup_virtual_display(display=display)
                self.assertFalse(lock.exists())
                self.assertFalse(endpoint.exists())
        finally:
            if process is not None and process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            cleanup_virtual_display(display=display)


if __name__ == '__main__':
    unittest.main()
