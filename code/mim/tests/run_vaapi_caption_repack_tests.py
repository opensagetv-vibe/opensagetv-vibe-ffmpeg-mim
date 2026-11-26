#!/usr/bin/env python3
"""FIXED-002 executable argv guards; real caption/hardware proof is separate."""
import configparser, hashlib, os, shlex, shutil, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix='vibe-vaapi-cc-') as scratch:
    work = Path(scratch)
    shutil.copy2(Path(os.environ.get('MIM_PROBE_TEST_BINARY', ROOT/'output/linux-x64/ffmpeg_MIM')), work/'ffmpeg_MIM')
    real = work/'ffmpeg.real'
    real.write_text('#!/bin/sh\nprintf " V..... h264_vaapi\\n V..... hevc_vaapi\\n V..... h264_qsv\\n V..... h264_nvenc\\n V..... libx264\\n"\n')
    real.chmod(0o755)
    source = work/'input.ts'
    source.write_bytes(bytes(188))
    rows = 0
    for backend, codec, captions, direct, hardware, deint, expected in (
        ('vaapi','mpeg4',True,False,False,'auto',True),
        ('vaapi','mpeg4',True,True,True,'off',True),
        ('vaapi','mpeg4',True,True,True,'auto',True),
        ('vaapi','mpeg4',True,True,True,'on',True),
        ('vaapi','mpeg4',False,True,True,'off',False),
        ('vaapi','hevc',True,True,True,'off',False),
        ('vaapi','copy',True,True,True,'off',False),
        ('qsv','mpeg4',True,True,True,'off',False),
        ('nvenc','mpeg4',True,True,True,'off',False),
        ('software','mpeg4',True,True,False,'off',False),
    ):
        ini = configparser.ConfigParser(interpolation=None)
        ini.read(ROOT/'ffmpeg.real.ini')
        for section, values in {
            'general': {'enabled':'true'},
            'hardware': {'backend':backend,'preflight_hardware_encode':'false',
                         'hardware_decode':str(hardware).lower(),'direct_hardware_decode':str(hardware).lower()},
            'closed_captions': {'preserve_a53cc':str(captions).lower(),
                               'caption_software_decode':str(not hardware).lower()},
            'logging': {'file':str(work/'mim.log')},
            'status': {'directory':str(work/'status')},
        }.items():
            for key, value in values.items(): ini.set(section,key,value)
        path = work/'test.ini'
        with path.open('w') as stream: ini.write(stream)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        command = [str(work/'ffmpeg_MIM'),'--mim-dry-run','-stdinctrl',
                   '-ss','153.090','-i',str(source),'-c:v',codec,'-b:v','4000k',
                   '-c:a','aac','-f','mpegts','pipe:1']
        if direct: command[2:2] = ['-sagetvdirect','-sagetvdeinterlace',deint]
        run = subprocess.run(command,env=dict(os.environ,SAGETV_FFMPEG_MIM_INI=str(path)),
                             capture_output=True,text=True,timeout=15,check=True)
        argv = shlex.split(run.stdout.splitlines()[-1])
        vf = argv[argv.index('-vf')+1] if '-vf' in argv else ''
        assert (vf.split(',').count('ccrepack')==1)==expected, (backend,codec,vf)
        assert 'hwdownload' not in vf
        assert argv[argv.index('-ss')+1]=='153.090'
        assert '-r' not in argv
        assert hashlib.sha256(path.read_bytes()).hexdigest()==digest
        if expected and hardware and deint!='off': assert 'deinterlace_vaapi' in vf
        if expected and not hardware: assert 'hwupload' in vf
        if expected: assert argv[argv.index('-c:v')+1]=='h264_vaapi'
        rows += 1
print('PASS VAAPI caption repack scope/filters/seek/cadence/INI:', rows)
