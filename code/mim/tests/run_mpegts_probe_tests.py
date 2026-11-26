#!/usr/bin/env python3
"""MIM-PROBE-001: file TS discovery must not confuse a 90kHz clock with FPS."""
import hashlib, os, shutil, subprocess, tempfile
from pathlib import Path

root=Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix='vibe-mpegts-probe-') as scratch:
    work=Path(scratch)
    shutil.copy2(Path(os.environ.get('MIM_PROBE_TEST_BINARY',root/'output/linux-x64/ffmpeg_MIM')),work/'ffmpeg_MIM')
    real=work/'ffmpeg.real'
    real.write_text('#!/bin/sh\ncase "$*" in *-encoders*) echo " V..... libx264";; *-hwaccels*) echo "Hardware acceleration methods:";; *-version*) echo "ffmpeg test";; esac\n')
    real.chmod(0o755)
    ini=work/'test.ini'
    source=work/'delayed-header.ts';source.write_bytes(b'\x47'+b'\0'*187)
    def mapped(input_value,copy=False,analysis=500000):
        ini.write_text('[general]\nenabled=true\n[hardware]\nbackend=software\n[probe_cache]\nenabled=false\n[input]\nanalyzeduration='+str(analysis)+'\n')
        before=hashlib.sha256(ini.read_bytes()).hexdigest()
        cmd=[str(work/'ffmpeg_MIM'),'--mim-dry-run','-sagetvdirect','-i',str(input_value),'-c:v','copy' if copy else 'libx264','-f','mpegts','pipe:1']
        result=subprocess.run(cmd,env=dict(os.environ,SAGETV_FFMPEG_MIM_INI=str(ini)),capture_output=True,text=True,timeout=15)
        assert result.returncode==0,(result.stdout,result.stderr)
        assert hashlib.sha256(ini.read_bytes()).hexdigest()==before,'user INI changed'
        return result.stdout
    out=mapped(source)
    assert '-analyzeduration 5000000' in out,out
    assert '-r ' not in out,'must discover cadence, not invent or force a frame rate'
    assert '-analyzeduration 7000000' in mapped(source,analysis=7000000)
    assert '-analyzeduration 5000000' not in mapped(source,analysis=0),'automatic analysis budget changed'
    assert '-analyzeduration 5000000' not in mapped(source,copy=True),'copy route changed'
    assert '-analyzeduration 5000000' not in mapped('pipe:0'),'unknown stdin route changed'
    assert '-analyzeduration 5000000' not in mapped(work/'fixture.mkv'),'non-TS route changed'
print('PASS TS probe floor / longer caller budget / no guessed FPS / Copy / stdin / non-TS / INI')
