
import _docker_paths
import json
from pathlib import Path
import tempfile
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from http_worker import HTTPWorker, Workspace


class WorkspaceTests(unittest.TestCase):
    def test_paths_and_listing_cannot_escape_via_traversal_or_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory).resolve(); root=base/'alice'; root.mkdir()
            outside=base/'bob'; outside.mkdir(); (outside/'private.ks').write_text('private')
            (root/'中文.cif').write_text('structure'); (root/'models').mkdir()
            (root/'foreign').symlink_to(outside, target_is_directory=True)
            with self.assertRaises(ValueError): Workspace(root/'foreign')
            (root/'broken').symlink_to(root/'missing')
            workspace=Workspace(root)
            self.assertEqual([entry['name'] for entry in workspace.request({'action':'list'})['entries']],
                             ['models','中文.cif'])
            for path in ('../bob/private.ks',str(outside/'private.ks'),'foreign/private.ks','models/../../bob','a\\b'):
                with self.subTest(path=path),self.assertRaises((OSError,ValueError)):
                    workspace.resolve(path,True)
            target=workspace.request({'action':'resolve','path':'models/new.ks','writable':True})
            self.assertEqual(target['path'],str(root/'models/new.ks'))
            self.assertFalse((root/'models/new.ks').exists(),'resolution never truncates a file')
            with self.assertRaises(IsADirectoryError):
                workspace.request({'action':'resolve','path':'models','writable':True})
            with self.assertRaises(FileNotFoundError): workspace.resolve('missing.ks')
            workspace.request({'action':'mkdir','path':'new folder','writable':True})
            self.assertTrue((root/'new folder').is_dir())

    def test_workspace_http_requires_the_runtime_bearer_and_rejects_other_roots(self):
        with tempfile.TemporaryDirectory() as directory:
            worker=HTTPWorker(workspace=directory).start()
            def request(token,path=''):
                body=json.dumps({'action':'resolve','path':path,'writable':True}).encode()
                query=Request(f'http://127.0.0.1:{worker.server_port}/workspace',body,
                              {'Authorization':'Bearer '+token,'Content-Type':'application/json'})
                with urlopen(query,timeout=3) as response: return json.load(response)
            try:
                with self.assertRaises(HTTPError) as denied: request('wrong')
                self.assertEqual(denied.exception.code,403); denied.exception.close()
                with self.assertRaises(HTTPError) as denied: request(worker.token,'../other-user.ks')
                self.assertEqual(denied.exception.code,400); denied.exception.close()
                self.assertEqual(request(worker.token,'project.ks')['path'],str(Path(directory).resolve()/'project.ks'))
            finally: worker.close()


if __name__=='__main__': unittest.main()
