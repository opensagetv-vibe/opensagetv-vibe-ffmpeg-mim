#!/usr/bin/env python3
"""Actual local CPU HLS profile comparison; not GPU/device/WAN certification.

Generated fixtures and children are test-owned. No server, installed INI,
recording, device or network setting is touched. Persist only a compact report.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]


def run(argv, **kwargs):
    return subprocess.run([str(x) for x in argv], check=True, timeout=45,
                          capture_output=True, text=True, **kwargs).stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    report = {'physicalDevice': False, 'hardwareGpu': False, 'serverMutation': False,
              'rows': [], 'passed': False}
    try:
        with tempfile.TemporaryDirectory(prefix='vibe-responsive-hls-') as staging:
            temp = Path(staging)
            shutil.copy2(ROOT/'output/linux-x64/ffmpeg_MIM', temp/'ffmpeg_MIM')
            for name in ('ffmpeg.real', 'ffprobe'):
                (temp/name).symlink_to(ROOT/'output/linux-x64'/name)
            # Explicit temporary software-only configuration. Source INI and
            # installed settings remain byte-for-byte unchanged.
            ini = temp/'test.ini'
            ini.write_text('[general]\nenabled=true\nmode=passthrough\n'
                           '[hardware]\nbackend=software\npreflight_hardware_encode=false\n'
                           '[logging]\nffmpeg_transcode_loglevel=error\n', encoding='utf-8')
            fixture = temp/'fixture.ts'
            run([temp/'ffmpeg.real','-hide_banner','-loglevel','error',
                 '-f','lavfi','-i','testsrc2=size=320x240:rate=30000/1001',
                 '-f','lavfi','-i','sine=frequency=880:sample_rate=48000',
                 '-t','20','-c:v','mpeg2video','-g','15','-c:a','ac3',
                 '-f','mpegts','-y',fixture])
            env = dict(os.environ, SAGETV_FFMPEG_MIM_INI=str(ini))
            for responsive in (False, True):
                directory = temp/('responsive' if responsive else 'legacy')
                directory.mkdir()
                playlist = directory/'stream.m3u8'
                command = [temp/'ffmpeg_MIM','-hide_banner','-loglevel','error',
                           '-sagetvdirect','-re']
                if responsive:
                    command += ['-sagetvresponsivehls','-readrate_initial_burst','6']
                command += ['-i',fixture,'-map','0:v:0?','-map','0:a?','-map','0:s?',
                            '-c:v','libx264','-preset','veryfast','-b:v','400k',
                            '-g','30','-a53cc','1','-c:a','ac3','-b:a','192k','-c:s','copy']
                if responsive:
                    command += ['-force_key_frames','expr:gte(t,n_forced*1)']
                command += ['-f','segment','-segment_time','1' if responsive else '2',
                            '-segment_format','mpegts','-segment_list_type','m3u8',
                            '-segment_list_flags','+live','-segment_list_size','180' if responsive else '90',
                            '-segment_list',playlist,'-y',directory/'seg_%06d.ts']
                began = time.monotonic()
                process = subprocess.Popen([str(x) for x in command], env=env,
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    while True:
                        text = playlist.read_text() if playlist.exists() else ''
                        segments = [line for line in text.splitlines()
                                    if line.startswith('seg_') and line.endswith('.ts')]
                        if segments and (directory/segments[0]).stat().st_size > 0:
                            first_ms = round((time.monotonic()-began)*1000)
                            break
                        if process.poll() is not None or time.monotonic()-began > 15:
                            raise AssertionError('Producer failed before a completed segment')
                        time.sleep(.01)
                    first = directory/segments[0]
                    streams = json.loads(run([temp/'ffprobe','-v','error','-show_entries',
                                              'stream=codec_name,codec_type','-of','json',first]))['streams']
                    assert any(s.get('codec_name') == 'h264' for s in streams)
                    assert any(s.get('codec_name') == 'ac3' for s in streams)
                    duration = float(next(line.split(':',1)[1].rstrip(',') for line in text.splitlines()
                                          if line.startswith('#EXTINF:')))
                    row = {'profile':'responsive' if responsive else 'legacy',
                           'firstCompletedSegmentMs': first_ms, 'firstSegmentSeconds': duration,
                           'h264VideoAndAc3Audio':True}
                    if responsive:
                        process.wait(timeout=30)
                        elapsed = time.monotonic()-began
                        assert process.returncode == 0
                        assert .7 <= duration <= 1.3, duration
                        assert 8 <= elapsed <= 30, 'Read burst lost bounded steady pacing'
                        row.update(elapsedMs=round(elapsed*1000), naturalExit=0)
                    report['rows'].append(row)
                finally:
                    if process.poll() is None:
                        process.terminate()
                        try: process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill(); process.wait(timeout=5)
            assert report['rows'][1]['firstCompletedSegmentMs'] < report['rows'][0]['firstCompletedSegmentMs']
            report['passed'] = True
    except BaseException as error:
        report['failure'] = type(error).__name__+': '+str(error)[:1000]
        raise
    finally:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
        print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
