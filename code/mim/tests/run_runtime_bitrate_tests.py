#!/usr/bin/env python3
"""Owned fake-child argv tests, NOT GPU/application/output-rate proof."""
import argparse,json,os,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path,required=True);args=parser.parse_args()
    rows=[]
    with tempfile.TemporaryDirectory(prefix='vibe-rate-argv-') as temporary:
        directory=Path(temporary);shutil.copy2(ROOT/'output/linux-x64/ffmpeg_MIM',directory/'ffmpeg_MIM')
        fake='#!/usr/bin/env python3\nimport sys,json\nprint(json.dumps(sys.argv[1:]),flush=True)\n'
        for name in ('ffmpeg.real','ffmpeg.real.exe'):
            path=directory/name;path.write_text(fake);path.chmod(0o755)
        fixture=directory/'input.ts';fixture.write_bytes(bytes(188))
        cases=[('native-qsv',True,'linux-x64','h264_qsv',str(fixture),'6000k',True),
               ('site-off',False,'linux-x64','h264_qsv',str(fixture),'6000k',False),
               ('pipe-refused',True,'linux-x64','h264_qsv','pipe:0','6000k',False),
               ('nvenc-not-qualified',True,'linux-x64','h264_nvenc',str(fixture),'6000k',False),
               ('copy-refused',True,'linux-x64','copy',str(fixture),'6000k',False),
               ('invalid-rate-refused',True,'linux-x64','h264_qsv',str(fixture),'0',False),
               ('windows-not-qualified',True,'windows-x64','h264_qsv',str(fixture),'6000k',False)]
        for label,enabled,platform,codec,source,rate,qualified in cases:
            ini=directory/'test.ini'
            ini.write_text('[general]\nenabled=true\nmode=passthrough\n[platform]\nforce_platform='+platform+
                '\n[stdinctrl]\nenabled=true\nvideorateadapt_mode=forward\nruntime_bitrate_control='+str(enabled).lower()+
                '\n[logging]\nfile='+str(directory/'test.log')+'\n[status]\ndirectory='+str(directory/'status')+'\n')
            env=dict(os.environ,SAGETV_FFMPEG_MIM_INI=str(ini))
            command=[str(directory/'ffmpeg_MIM'),'-sagetvruntimebitrate','-nostdin','-i',source,
                '-c:v',codec,'-b:v',rate,'-maxrate','9000k','-bufsize','18000k','-bf','2',
                '-vf','scale=640:360','-c:a','ac3','-f','segment','-segment_list_type','m3u8',str(directory/'out.ts')]
            process=subprocess.Popen(command,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            try:
                # Keep the control pipe open until the finite fake child exits.
                # communicate(input='') would simulate controller loss and
                # correctly terminate the child before its first argv output.
                assert process.wait(timeout=10)==0
                stdout=process.stdout.read();stderr=process.stderr.read()
            finally:
                if process.poll() is None:process.terminate();process.wait(timeout=5)
                process.stdin.close()
            assert stdout.strip(),(label,stderr[-2500:])
            child=json.loads(stdout.strip());assert '-sagetvruntimebitrate' not in child
            assert child[child.index('-vf')+1]=='scale=640:360' and child[child.index('-c:a')+1]=='ac3'
            assert ('VIBE_RATE_CONTROL revision=1 encoder=h264_qsv' in stderr)==qualified,(label,stderr)
            assert ('-sagetvratectrl' in child)==qualified,(label,child)
            if qualified:
                for flag,value in (('-maxrate','6000k'),('-bufsize','6000k'),('-bf','0'),('-look_ahead','0'),('-async_depth','1')):
                    assert child[child.index(flag)+1]==value,(label,flag,child)
                assert '-nostdin' not in child and child[child.index('-loglevel')+1]=='verbose'
            else:assert '-nostdin' in child and child[child.index('-bf')+1]=='2'
            rows.append({'case':label,'qualified':qualified,'privateFlagConsumed':True,'existingFilterAudioPreserved':True})
    report={'passed':True,'hardwareGpu':False,'syntheticChild':True,'rows':rows}
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS7 native-QSV/site/pipe/vendor/copy/bitrate/platform argument guards; no hardware claim')
if __name__=='__main__':main()
