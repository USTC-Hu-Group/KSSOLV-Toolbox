#!/usr/bin/env python3
"""Root-only recovery/migration of the single Portal superadministrator."""
import argparse
import json
import os
from pathlib import Path
import re
import sys
source = Path(__file__).resolve().parents[3] / 'server' / 'admin'
if not source.is_dir():
    source = Path(__file__).resolve().parent
sys.path.insert(0, str(source))
from cloud import Cloud

SQL_SCRIPT = '''
import json,sqlite3,sys
username,replace=sys.argv[1:]
with sqlite3.connect('/data/portal/accounts.sqlite3',timeout=15) as db:
    db.execute('BEGIN IMMEDIATE')
    user=db.execute('SELECT uid,username,frozen FROM users WHERE username=?',(username,)).fetchone()
    if not user:raise SystemExit('Registered user does not exist.')
    if user[2]:raise SystemExit('Restore the frozen account before assigning superadministrator.')
    old=db.execute("SELECT uid,username FROM users WHERE role='superadmin'").fetchone()
    if old and old[0]!=user[0] and replace!='yes':raise SystemExit('A superadministrator already exists. Use --replace-existing for an intentional transfer.')
    if old and old[0]!=user[0]:
        db.execute("UPDATE users SET role='admin' WHERE uid=?",(old[0],))
        db.execute("DELETE FROM sessions WHERE uid=? AND kind='admin'",(old[0],))
    db.execute("UPDATE users SET role='superadmin' WHERE uid=?",(user[0],))
    db.execute("DELETE FROM sessions WHERE uid=? AND kind='admin'",(user[0],))
    db.execute("INSERT OR REPLACE INTO portal_settings VALUES ('superadmin_bootstrapped','1')")
print(json.dumps({'uid':user[0],'username':user[1],'role':'superadmin'}))
'''

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('username')
    parser.add_argument('--config',default='/etc/kssolv/admin.json')
    parser.add_argument('--replace-existing',action='store_true')
    args=parser.parse_args()
    if os.geteuid()!=0:raise SystemExit('Run on the virtualization host as root.')
    if not re.fullmatch(r'[a-z][a-z0-9-]{2,31}',args.username):raise SystemExit('Use a registered Portal username.')
    cloud=Cloud(json.loads(Path(args.config).read_text()))
    with cloud.mutation:
        result=json.loads(cloud.kub('-n','kssolv-system','exec','deploy/portal','--','python3','-c',SQL_SCRIPT,args.username,'yes' if args.replace_existing else 'no'))
        cloud.audit('host-root','superadmin-bind',result['username'],'succeeded')
    print(json.dumps(result))

if __name__=='__main__':main()
