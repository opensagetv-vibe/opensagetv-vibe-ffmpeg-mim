#!/usr/bin/env python3
"""Bounded executable policy guards; no server, user INI or GPU mutation."""
import hashlib,os,shutil,subprocess,tempfile
from pathlib import Path

root=Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix='vibe-encoder-policy-') as scratch:
    work=Path(scratch)
    shutil.copy2(root/'output/linux-x64/ffmpeg_MIM',work/'ffmpeg_MIM')
    # Force a deterministic CPU-only capability set on any physical builder.
    real=work/'ffmpeg.real'
    real.write_text('#!/bin/sh\ncase "$*" in *-encoders*) echo " V..... libx264";; *-hwaccels*) echo "Hardware acceleration methods:";; *-version*) echo "ffmpeg test";; esac\n')
    real.chmod(0o755)
    ini=work/'ffmpeg.real.ini';ini.write_text('[general]\nenabled=true\n[hardware]\nbackend=software\npreflight_hardware_encode=true\n')
    before=hashlib.sha256(ini.read_bytes()).hexdigest()
    base=[str(work/'ffmpeg_MIM'),'--mim-dry-run','-sagetvdirect','-i','fixture.ts','-c:v','libx264','-f','segment','seg_%06d.ts']
    for selection in ('server','software','prefer_hardware'):
        run=subprocess.run(base+['-sagetvencoderpolicy',selection],text=True,capture_output=True,timeout=15)
        assert run.returncode==0,(selection,run.stderr)
        assert 'backend=software' in run.stdout,(selection,run.stdout)
        assert '-sagetvencoderpolicy' not in run.stdout,run.stdout
    for command in (base+['-sagetvencoderpolicy','hardware_only'],base+['-sagetvencoderpolicy','invalid'],
                    [part for part in base if part!='-sagetvdirect']+['-sagetvencoderpolicy','software'],
                    [part if part!='libx264' else 'copy' for part in base]+['-sagetvencoderpolicy','software']):
        run=subprocess.run(command,text=True,capture_output=True,timeout=15)
        assert run.returncode==78,(run.returncode,run.stdout,run.stderr)
        assert not run.stdout,run.stdout
    assert before==hashlib.sha256(ini.read_bytes()).hexdigest(),'shared INI modified'
print('PASS native server/software/prefer/Hardware-Only-unavailable/invalid/scope/copy/INI guards')
