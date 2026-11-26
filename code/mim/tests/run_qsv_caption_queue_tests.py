#!/usr/bin/env python3
"""MIM-QSV-001 argv regression; GPU/output qualification is separate."""
import argparse,configparser,json,os,shlex,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--wrapper',type=Path,default=ROOT/'output/linux-x64/ffmpeg_MIM');args=parser.parse_args()
    rows=[]
    with tempfile.TemporaryDirectory(prefix='mim-qsv-queue-') as temporary:
        directory=Path(temporary);shutil.copy2(args.wrapper,directory/'ffmpeg_MIM')
        child=directory/'ffmpeg.real'
        child.write_text('#!/bin/sh\nprintf " V..... h264_qsv\\n V..... hevc_qsv\\n V..... h264_nvenc\\n V..... h264_vaapi\\n V..... libx264\\n"\n');child.chmod(0o755)
        fixture=directory/'input.ts';fixture.write_bytes(bytes(188))
        cases=[('classic-qsv','qsv','mpeg4',True,False,False,True),
               ('caption-off','qsv','mpeg4',False,False,False,False),
               ('hardware-frames','qsv','mpeg4',True,True,False,False),
               ('hevc-unaffected','qsv','hevc',True,False,False,False),
               ('nvenc-unaffected','nvenc','mpeg4',True,False,False,False),
               ('vaapi-unaffected','vaapi','mpeg4',True,False,False,False),
               ('copy-unaffected','qsv','copy',True,False,False,False),
               ('native-unaffected','qsv','h264_qsv',True,False,False,False),
               ('adaptive-preserved','qsv','mpeg4',True,False,True,True)]
        for name,backend,codec,cc,hardware,adaptive,expected in cases:
            ini=configparser.ConfigParser(interpolation=None);ini.read(ROOT/'ffmpeg.real.ini')
            values={'general':{'enabled':'true'},'hardware':{'backend':backend,'preflight_hardware_encode':'false','hardware_decode':str(hardware).lower()},
                    'closed_captions':{'preserve_a53cc':str(cc).lower(),'caption_software_decode':str(not hardware).lower()},
                    'logging':{'file':str(directory/'mim.log')},'status':{'directory':str(directory/'status')},
                    'stdinctrl':{'runtime_bitrate_control':str(adaptive).lower()}}
            for section,pairs in values.items():
                for key,value in pairs.items():ini.set(section,key,value)
            if name=='native-unaffected':ini.set('general','default_sagetv_action','passthrough')
            path=directory/'test.ini'
            with path.open('w') as out:ini.write(out)
            command=[str(directory/'ffmpeg_MIM'),'--mim-dry-run','-stdinctrl','-ss','42','-i',str(fixture),
                     '-vcodec',codec,'-b','4000000','-s','1920x1080','-f','mpegts','-acodec','aac','-']
            if adaptive:command.insert(2,'-sagetvruntimebitrate')
            reply=subprocess.run(command,env=dict(os.environ,SAGETV_FFMPEG_MIM_INI=str(path)),capture_output=True,text=True,timeout=15,check=True)
            child_args=shlex.split(reply.stdout.strip())
            depth=child_args[child_args.index('-async_depth')+1] if '-async_depth' in child_args else None
            assert depth==('1' if expected else None),(name,depth,child_args)
            assert child_args[child_args.index('-ss')+1]=='42'
            if codec!='copy':
                audio=next(flag for flag in ('-acodec','-c:a','-codec:a') if flag in child_args)
                assert child_args[child_args.index(audio)+1]=='aac',(name,child_args)
            if expected:
                assert child_args[child_args.index('-c:v')+1]=='h264_qsv'
                assert child_args[child_args.index('-a53cc')+1]=='1'
                if not adaptive:
                    assert child_args[child_args.index('-maxrate')+1]=='6M'
                    assert child_args[child_args.index('-bufsize')+1]=='12M'
            rows.append({'case':name,'asyncDepth':depth,'passed':True})
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps({'passed':True,'hardwareClaim':False,'rows':rows},indent=2)+'\n')
    print('PASS9 QSV caption-queue mapping and unaffected/adaptive guards')
if __name__=='__main__':main()
