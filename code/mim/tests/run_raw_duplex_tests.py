#!/usr/bin/env python3
"""Deterministic raw-media/diagnostic pipe backpressure; no server or GPU.

Both streams must make progress even when the child emits more than a pipe
capacity before reading input. Owned temporary subprocess only, no PID scan.
"""
import hashlib,json,os,signal,shutil,subprocess,tempfile,threading,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
def main():
    with tempfile.TemporaryDirectory(prefix='mim-raw-duplex-') as tmp:
        root=Path(tmp);wrapper=root/'ffmpeg'
        subprocess.run([os.environ.get('CXX','g++'),'-std=c++17','-O2','-pipe','-pthread','-static','-s',
            str(ROOT/'code/mim/sagetv_ffmpeg_mim.cpp'),'-o',str(wrapper)],check=True,timeout=120)
        shutil.copyfile(ROOT/'code/mim/tests/raw_duplex_child.py',root/'ffmpeg.real');(root/'ffmpeg.real').chmod(0o755)
        (root/'ffmpeg.real.ini').write_text('[general]\nenabled=true\nmode=passthrough\n[logging]\nlog_ffmpeg_stderr=true\n',encoding='utf-8')
        data=bytes((i*17+3)%256 for i in range(1024*1024))
        child=subprocess.Popen([str(wrapper),'-f','mpeg','-i','pipe:0','-f','null','-'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
        try:out,err=child.communicate(data,timeout=10)
        except subprocess.TimeoutExpired:
            # Own exact process group created above; no broad matching/signals.
            os.killpg(child.pid,signal.SIGKILL);child.communicate(timeout=5)
            raise AssertionError('Raw media/stderr duplex deadlock exceeded10s') from None
        if child.returncode:raise AssertionError('Wrapper/child exit '+str(child.returncode))
        actual=json.loads(out);expected=dict(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
        assert actual==expected,(actual,expected)
        assert err.count(b'raw-duplex diagnostic')==4096*17
        print('PASS exact1MiB raw media and17 diagnostic bursts, no duplex deadlock',flush=True)
        unrelated=subprocess.Popen(['sleep','30'])
        stalled=subprocess.Popen([str(wrapper),'-i','pipe:0','--stall-raw-test'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
        completed=[]
        def communicate():
            completed.append(stalled.communicate(data))
        worker=threading.Thread(target=communicate,daemon=True);worker.start()
        try:
            deadline=time.monotonic()+5
            while not (root/'child-started').exists() and time.monotonic()<deadline:time.sleep(.02)
            assert (root/'child-started').exists(),'Owned child did not start'
            time.sleep(.15);started=time.monotonic();stalled.send_signal(signal.SIGTERM);worker.join(5)
            assert not worker.is_alive() and stalled.returncode is not None,'Raw backpressure blocked parent termination'
            assert unrelated.poll() is None,'Unrelated child was interrupted'
            print('PASS raw backpressure SIGTERM bounded %.3fs, unrelated process preserved'%(time.monotonic()-started),flush=True)
        finally:
            if stalled.poll() is None:os.killpg(stalled.pid,signal.SIGKILL);worker.join(5)
            unrelated.terminate();unrelated.wait(timeout=5)
if __name__=='__main__':main()
