#!/usr/bin/env python3
"""SETTINGS-005 deterministic argv/scope guards, not GPU execution proof."""
import configparser, hashlib, os, shlex, shutil, subprocess, tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix='vibe-backend-') as scratch:
    work = Path(scratch)
    shutil.copy2(Path(os.environ.get('MIM_PROBE_TEST_BINARY', root/'output/linux-x64/ffmpeg_MIM')), work/'ffmpeg_MIM')
    real = work/'ffmpeg.real'
    real.write_text('#!/bin/sh\nprintf " V..... libx264\\n V..... h264_qsv\\n V..... h264_vaapi\\n V..... h264_nvenc\\n"\n')
    real.chmod(0o755)
    ini = configparser.ConfigParser(interpolation=None)
    ini.read(root/'ffmpeg.real.ini')
    for section, values in {'general':{'enabled':'true'},
        'hardware':{'backend':'software','preflight_hardware_encode':'false'},
        'logging':{'file':str(work/'mim.log')},'status':{'directory':str(work/'status')}}.items():
        for key,value in values.items(): ini.set(section,key,value)
    path = work/'test.ini'
    with path.open('w') as stream: ini.write(stream)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    base = [str(work/'ffmpeg_MIM'),'--mim-dry-run','-sagetvdirect','-ss','153.090',
            '-i','fixture.ts','-c:v','mpeg4','-f','segment','seg_%06d.ts']
    def run(args):
        return subprocess.run(args,env=dict(os.environ,SAGETV_FFMPEG_MIM_INI=str(path)),
                              capture_output=True,text=True,timeout=15)
    rows = 0
    for backend in ('qsv','vaapi','nvenc'):
        for policy in ('server','hardware_only','prefer_hardware'):
            result = run(base+['-sagetvhardwarebackend',backend,'-sagetvencoderpolicy',policy])
            assert result.returncode==0,(backend,policy,result.stderr)
            argv = shlex.split(result.stdout.splitlines()[-1])
            assert argv[argv.index('-c:v')+1]=='h264_'+backend,result.stdout
            assert argv[argv.index('-ss')+1]=='153.090'
            assert '-sagetvhardwarebackend' not in argv
            rows += 1
    result = run(base+['-sagetvhardwarebackend','auto'])
    assert result.returncode==0 and 'libx264' in result.stdout
    for command in (
        base+['-sagetvhardwarebackend','amf'],
        base+['-sagetvhardwarebackend','videotoolbox'],
        base+['-sagetvhardwarebackend','d3d12va'],
        base+['-sagetvhardwarebackend','invalid'],
        base+['-sagetvhardwarebackend','qsv','-sagetvencoderpolicy','software'],
        [a for a in base if a!='-sagetvdirect']+['-sagetvhardwarebackend','qsv'],
        ['copy' if a=='mpeg4' else a for a in base]+['-sagetvhardwarebackend','qsv'],
    ):
        result=run(command)
        assert result.returncode==78,(result.returncode,result.stdout,result.stderr)
        assert not result.stdout,'failed pin leaked a fallback command'
        rows += 1
    # Compiled-but-missing encoder is a refusal, even though software exists.
    real.write_text('#!/bin/sh\nprintf " V..... libx264\\n"\n')
    result=run(base+['-sagetvhardwarebackend','qsv'])
    assert result.returncode==78 and not result.stdout
    assert hashlib.sha256(path.read_bytes()).hexdigest()==digest
print('PASS hardware backend pin/Auto/platform/policy/copy/legacy/seek/INI guards:',rows+2)
