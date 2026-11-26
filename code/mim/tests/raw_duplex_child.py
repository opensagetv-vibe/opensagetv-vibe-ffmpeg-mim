#!/usr/bin/env python3
"""Synthetic adversarial child: diagnostic burst before every input read."""
import hashlib,json,os,sys,time
from pathlib import Path
if '--stall-raw-test' in sys.argv:
    Path(__file__).with_name('child-started').touch()
    time.sleep(60)
    raise SystemExit(0)
count=0;digest=hashlib.sha256()
while True:
    burst=b'raw-duplex diagnostic\n'*4096
    while burst:
        n=os.write(2,burst);burst=burst[n:]
    data=sys.stdin.buffer.read(65536)
    if not data:break
    digest.update(data);count+=len(data)
print(json.dumps(dict(bytes=count,sha256=digest.hexdigest())))
