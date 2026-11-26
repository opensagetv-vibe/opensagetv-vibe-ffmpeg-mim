#!/usr/bin/env python3
"""Bounded installed-engine isolation of MIM-QSV-001 on idle stock232.

No installed file/INI modification, client, restart or automatic fallback.
Use the exact failed post-seek codec/filter/audio/RC profile; change one
option at a time. Exit status plus actual packets, not preflight, is evidence.
"""
import argparse,datetime,hashlib,json,re,shlex,time,runpy
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
ENGINE='/opt/sagetv/server/plugins/SageTVFFmpegPlugin/runtime/ffmpeg.real'
PROBE='/opt/sagetv/server/plugins/SageTVFFmpegPlugin/runtime/ffprobe'
FIXTURE='/var/media/OpenSageTV_Vibe_Tests/VibeCaptionTest-1080i-CEA608-90s-2s.ts'
CASES={'baseline':[], 'async1':['-async_depth','1'],
       'cbr':['-maxrate','4000000'],'lookahead0':['-look_ahead','0'],
       'cbr-async1':['-maxrate','4000000','-async_depth','1'],
       'cbr-no-cc':['-maxrate','4000000','-a53cc','0'],
       'no-cc':['-a53cc','0'],
       'upload':['-vf','yadif=deint=interlaced,scale=w=1920:h=1080,format=nv12,hwupload=extra_hw_frames=32','-filter_hw_device','hw'],
       'runtime-profile':['-maxrate','4000000','-bufsize','4000000','-look_ahead','0','-async_depth','1']}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cases',default='baseline,async1,cbr,lookahead0,no-cc,runtime-profile')
    parser.add_argument('--repeat',type=int,default=1)
    parser.add_argument('--seconds',type=int,default=20)
    parser.add_argument('--debugger',action='store_true',help='Run only owned child under batch GDB; no attach or core dump')
    args=parser.parse_args();names=args.cases.split(',')
    if not 1<=args.repeat<=6:raise RuntimeError('Repeat must be1..6')
    if not 1<=args.seconds<=48:raise RuntimeError('Duration must be1..48')
    if not names or any(n not in CASES for n in names):raise RuntimeError('Closed case list required')
    helper=ROOT.parent/'opensagetv-vibe-WebClient-Plugin/scripts/commission-mobile.py'
    if not helper.is_file():helper=Path('/workspace/web-client-plugin/scripts/commission-mobile.py')
    c=runpy.run_path(str(helper))
    cfg=c['configuration']()
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    output=ROOT/'artifacts/active/MIM-QSV-001';output.mkdir(parents=True,exist_ok=True)
    report={'task':'MIM-QSV-001','installedEngine':ENGINE,'fixture':FIXTURE,'clientUsed':False,'rows':[]}
    remote_dir=None
    with c['ssh'](cfg) as ssh:
        prefix='docker exec -w /opt/sagetv/server '+shlex.quote(cfg['unraid_container_name'])+' '
        def remote(command):return c['remote'](ssh,prefix+command)
        def guard():
            activity=c['activity'](cfg)
            if activity.get('safeToRestart') is not True:raise RuntimeError('Preserve server activity')
            if any(s.strip() in ('ffmpeg','ffmpeg.real','ffmpeg_MIM','SageTVTranscoder') for s in remote('ps -eo comm').splitlines()):raise RuntimeError('Preserve active encoder')
            return activity
        report['activityBefore']=guard()
        hashes=remote('sha256sum '+shlex.quote(ENGINE)+' '+shlex.quote(ENGINE+'.ini'))
        report['inputHashes']=hashes.strip().splitlines()
        if not hashes.startswith('ceaf236a6a1770a6222be2deb9c59ec28c23faed00897ca6ba370e8f0ae1f505 '):raise RuntimeError('Unexpected installed engine')
        report['protectedBefore']=remote('sha256sum -c /usr/local/share/sagetv-stock/protected.sha256').count(': OK')
        if report['protectedBefore']!=20:raise RuntimeError('Protected stock mismatch')
        report['debugger']=remote("sh -c 'command -v gdb || true; cat /proc/sys/kernel/core_pattern'").strip()
        remote_dir=remote('mktemp -d /tmp/mim-qsv001-XXXXXXXX').strip()
        if not re.fullmatch('/tmp/mim-qsv001-[A-Za-z0-9]{8}',remote_dir):raise RuntimeError('Invalid owned scratch')
        report['ownedRemoteScratch']=remote_dir
        try:
            for attempt,name in ((i,n) for i in range(1,args.repeat+1) for n in names):
                label=name+'-'+str(attempt)
                guard();dest=remote_dir+'/'+label+'.ts'
                cmd=[ENGINE,'-sagetvratectrl','-hide_banner','-loglevel','verbose','-ss','42','-y',
                    '-threads','2','-probesize','524288','-analyzeduration','500000','-max_probe_packets','1024',
                    '-skip_estimate_duration_from_pts','1','-fflags','+genpts+discardcorrupt','-thread_queue_size','8192','-max_delay','500000',
                    '-init_hw_device','qsv:hw,child_device=/dev/dri/renderD128','-i',FIXTURE,
                    '-a53cc','1','-mpegts_flags','+initial_discontinuity+resend_headers','-muxdelay','0','-muxpreload','0',
                    '-c:s','copy','-map','0:s?','-max_interleave_delta','500000','-flush_packets','1',
                    '-bufsize','12M','-maxrate','6M','-b:v','4000000','-preset','fast','-bf','0','-g','60','-c:v','h264_qsv',
                    '-vf','yadif=deint=interlaced,scale=w=1920:h=1080,format=nv12','-threads','5','-f','mpegts','-r','29.97',
                    '-acodec','aac','-ab','128000','-ar','48000','-ac','2','-packetsize','1024','-aspect','16:9','-map','0:0','-map','0:1']
                # Preserve original semantics. Overrides append at the output
                # boundary, never before input or after its output filename.
                cmd+=CASES[name]+['-t',str(args.seconds),'-progress','pipe:1',dest]
                row={'case':name,'attempt':attempt,'changedOptions':CASES[name],'command':cmd,'gpuDescriptors':[]}
                channel=ssh.get_transport().open_session(timeout=15)
                launch=(['env','DEBUGINFOD_URLS=https://debuginfod.ubuntu.com','DEBUGINFOD_TIMEOUT=10',
                         'gdb','--batch','-ex','set pagination off','-ex','set debuginfod enabled on',
                         '-ex','run','-ex','thread apply all bt 14','-ex','info sharedlibrary','--args']+cmd) if args.debugger else cmd
                shell='ulimit -c 0; printf "OWNED_PID=%s\\n" "$$"; exec '+shlex.join(launch)
                channel.exec_command(prefix.replace('docker exec ','docker exec -i ',1)+'sh -c '+shlex.quote(shell))
                started=time.monotonic();pid=None;pending='';stdout=bytearray();stderr=bytearray()
                try:
                    while True:
                        if channel.recv_ready():
                            chunk=channel.recv(65536);stdout.extend(chunk);pending+=chunk.decode(errors='replace')
                            while '\n' in pending:
                                line,pending=pending.split('\n',1)
                                if line.startswith('OWNED_PID='):pid=int(line.split('=')[1]);row['pid']=pid
                                if line.startswith('out_time_us=') and not row['gpuDescriptors'] and pid:
                                    try:
                                        target=pid
                                        if args.debugger:
                                            children=remote('pgrep -P '+str(pid)).split()
                                            if len(children)==1:target=int(children[0]);row['inferiorPid']=target
                                        witness=remote('sh -c '+shlex.quote('readlink /proc/'+str(target)+'/exe; find /proc/'+str(target)+'/fd -maxdepth 1 -type l -lname "/dev/dri/*" -printf "%l\\n"'))
                                        row['gpuDescriptors']=[s for s in witness.splitlines() if s.startswith('/dev/dri/')]
                                    except RuntimeError:pass
                        if channel.recv_stderr_ready():stderr.extend(channel.recv_stderr(65536))
                        if channel.exit_status_ready() and not channel.recv_ready() and not channel.recv_stderr_ready():break
                        if len(stderr)>4*1024*1024:raise RuntimeError('Bounded diagnostic exceeded')
                        if time.monotonic()-started>100:raise TimeoutError('Owned experiment exceeded100s')
                        time.sleep(.025)
                    row['exitCode']=channel.recv_exit_status()
                    if args.debugger:
                        row['debuggerExitCode']=row['exitCode']
                        row['exitCode']=139 if b'SIGSEGV' in stdout else (0 if b'exited normally' in stdout else -1)
                except BaseException:
                    pid=row.get('inferiorPid',pid)
                    if pid:
                        try:
                            witness=remote('readlink /proc/'+str(pid)+'/exe').strip()
                            if witness==ENGINE:remote('kill -TERM '+str(pid))
                        except RuntimeError:pass
                    raise
                finally:channel.close()
                row['elapsedSeconds']=round(time.monotonic()-started,3)
                (output/(stamp+'-'+label+'-stderr.log')).write_bytes(stderr)
                (output/(stamp+'-'+label+'-progress.log')).write_bytes(stdout)
                try:
                    row['output']=json.loads(remote(shlex.join([PROBE,'-v','error','-count_packets','-select_streams','v:0','-show_entries',
                        'stream=codec_name,width,height,duration,nb_read_packets','-of','json',dest])))
                except RuntimeError as error:row['probeError']=str(error)
                if row['exitCode']==0:
                    frames=json.loads(remote(shlex.join([PROBE,'-v','error','-select_streams','v:0','-show_frames',
                        '-show_entries','frame=best_effort_timestamp_time:frame_side_data=side_data_type','-of','json',dest])))['frames']
                    clocks=[float(f['best_effort_timestamp_time']) for f in frames if 'best_effort_timestamp_time' in f]
                    row['decodedVideoFrames']=len(frames)
                    row['sideDataTypes']=sorted({s.get('side_data_type','') for f in frames for s in f.get('side_data_list',[])})
                    row['captionFrames']=sum(any('A53' in s.get('side_data_type','').replace('/','') for s in f.get('side_data_list',[])) for f in frames)
                    row['monotonicClock']=len(clocks)==len(frames) and all(b>a for a,b in zip(clocks,clocks[1:]))
                report['rows'].append(row)
                print(json.dumps({k:row[k] for k in ('case','exitCode','elapsedSeconds','gpuDescriptors','output') if k in row}),flush=True)
                (output/(stamp+'-probe.json')).write_text(json.dumps(report,indent=2)+'\n')
            report['activityAfter']=guard()
            report['inputsUnchanged']=hashes==remote('sha256sum '+shlex.quote(ENGINE)+' '+shlex.quote(ENGINE+'.ini'))
            report['protectedAfter']=remote('sha256sum -c /usr/local/share/sagetv-stock/protected.sha256').count(': OK')
        finally:
            # Retain the small bounded encoded comparisons until cause is
            # established. This tool never broad-deletes scratch or user data.
            (output/(stamp+'-probe.json')).write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
