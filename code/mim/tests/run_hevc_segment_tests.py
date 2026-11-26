#!/usr/bin/env python3
"""Real software HEVC segment independence; owned CPU scratch, no server/INI edits."""
import shutil,subprocess,tempfile
from pathlib import Path

root=Path(__file__).resolve().parents[3];binaries=root/'output/linux-x64'
with tempfile.TemporaryDirectory(prefix='vibe-hevc-segments-') as scratch:
    work=Path(scratch)
    for name in ('ffmpeg_MIM','ffmpeg.real','ffprobe'):
        (work/name).symlink_to(binaries/name)
    # Resolve executable directory to scratch by copying only the small wrapper.
    (work/'ffmpeg_MIM').unlink();shutil.copy2(binaries/'ffmpeg_MIM',work/'ffmpeg_MIM')
    (work/'ffmpeg.real.ini').write_text('[general]\nenabled=true\n[hardware]\nbackend=software\n[video]\nbframes=0\n[logging]\nffmpeg_transcode_loglevel=error\n')
    source=work/'source.ts'
    subprocess.run([str(work/'ffmpeg.real'),'-v','error','-f','lavfi','-i','testsrc2=size=640x360:rate=30','-f','lavfi','-i','sine=frequency=1000:sample_rate=48000','-t','12','-c:v','mpeg2video','-c:a','ac3','-y',str(source)],check=True,timeout=30)
    command=[str(work/'ffmpeg_MIM'),'-sagetvdirect','-sagetvencoderpolicy','software','-sagetvdeinterlace','off','-i',str(source),'-c:v','libx265','-preset','veryfast','-g','30','-r','24','-s','352x198','-b:v','1000k','-c:a','aac','-b:a','96k','-f','segment','-segment_time','2','-segment_format','mpegts','-segment_list_type','m3u8','-segment_list',str(work/'stream.m3u8'),str(work/'seg_%06d.ts')]
    encoded=subprocess.run(command,capture_output=True,text=True,timeout=45)
    assert encoded.returncode==0,encoded.stderr[-2000:]
    segments=sorted(work.glob('seg_*.ts'));assert len(segments)>=3
    for segment in segments:
        frame=work/(segment.stem+'.png')
        decoded=subprocess.run([str(work/'ffmpeg.real'),'-v','error','-xerror','-i',str(segment),'-map','0:v:0','-frames:v','1','-y',str(frame)],capture_output=True,text=True,timeout=8)
        assert decoded.returncode==0 and frame.is_file() and frame.stat().st_size>100,(segment.name,decoded.returncode,decoded.stderr[-1200:])
print('PASS software HEVC MPEG-TS/M3U8 segments independently decode real frames, no predecessor references required')
