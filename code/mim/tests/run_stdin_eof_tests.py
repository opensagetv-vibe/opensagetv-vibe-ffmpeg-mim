#!/usr/bin/env python3
"""Exact raw-stdin EOF regression; synthetic bytes, no media/server/device.

Run inside the existing unified dev container. One writer closes after a final
buffered chunk; POLLIN|POLLHUP must not discard unread media. Child stdout is
only a byte count/digest, never payload. Control/process isolation tests remain
in run_mim_tests.sh; this is their focused data-plane complement.
"""
import hashlib,json,os,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]

def main():
    with tempfile.TemporaryDirectory(prefix='mim-stdin-eof-') as tmp:
        root=Path(tmp);wrapper=root/'ffmpeg'
        subprocess.run([os.environ.get('CXX','g++'),'-std=c++17','-O2','-pipe','-pthread','-static','-s',
            str(ROOT/'code/mim/sagetv_ffmpeg_mim.cpp'),'-o',str(wrapper)],check=True,timeout=120)
        child=root/'ffmpeg.real'
        child.write_text("#!/usr/bin/env python3\nimport hashlib,json,sys\ndata=sys.stdin.buffer.read()\nprint(json.dumps(dict(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())))\n",encoding='utf-8')
        child.chmod(0o755)
        (root/'ffmpeg.real.ini').write_text('[general]\nenabled=true\nmode=passthrough\n',encoding='utf-8')
        for size in (0,1,1024,1025,18432,131072):
            data=bytes((i*17+3)%256 for i in range(size))
            result=subprocess.run([str(wrapper),'-f','mpeg','-i','pipe:0','-f','null','-'],input=data,
                stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20)
            if result.returncode:raise AssertionError('Wrapper/child exit '+str(result.returncode))
            value=json.loads(result.stdout)
            assert value==dict(bytes=size,sha256=hashlib.sha256(data).hexdigest()),dict(expected=size,received=value['bytes'])
            print('PASS exact raw stdin EOF bytes='+str(size),flush=True)
    print('PASS6 raw-stdin count/hash cases; generated data, no server/physical claim')
if __name__=='__main__':main()
