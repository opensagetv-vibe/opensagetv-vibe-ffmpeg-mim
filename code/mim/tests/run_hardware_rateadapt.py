#!/usr/bin/env python3
"""External same-process encoder experiment on commissioned stock232.

Uses existing read-only MCP activity/SSH helpers; creates only an owned /tmp
capture inside the container. No client, plugin install, INI edit or restart.
The installed plugin-owned engine is tested directly to isolate its control
hook from MIM forwarding and client handoff. This is NOT end-to-end certification.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import shlex
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
ENGINE = '/opt/sagetv/server/plugins/SageTVFFmpegPlugin/runtime/ffmpeg.real'
PROBE = '/opt/sagetv/server/plugins/SageTVFFmpegPlugin/runtime/ffprobe'
WINDOWS = [(8, 18), (28, 38), (48, 58)]


def packet_metrics(packets):
    rows = [(float(p['pts_time']), float(p['dts_time']), int(p['size']))
            for p in packets]
    if not rows or any(not math.isfinite(t) for row in rows for t in row[:2]):
        raise AssertionError('Missing/non-finite packet clock')
    origin = rows[0][0]
    pts = [p[0] - origin for p in rows]
    dts = [p[1] for p in rows]
    if any(b <= a or b - a > .04 for clock in (dts, pts)
           for a, b in zip(clock, clock[1:])):
        raise AssertionError('Non-monotonic clock or missing 60fps pictures')
    rates = []
    for start, end in WINDOWS:
        chosen = [(t, p[2]) for t, p in zip(pts, rows) if start <= t < end]
        if not 598 <= len(chosen) <= 602:
            raise AssertionError('Incomplete measurement window')
        rates.append(round(sum(p[1] for p in chosen) * 8 / (end - start) / 1000, 3))
    return {'videoKbps': rates, 'packets': len(rows),
            'durationSeconds': round(pts[-1] + 1 / 60, 3),
            'maxDtsGapMs': round(max(b-a for a, b in zip(dts, dts[1:]))*1000, 3)}


def compare(baseline, adaptive):
    b, a = baseline['videoKbps'], adaptive['videoKbps']
    # Require an initially exercised high bitrate, a substantial real reduction,
    # and recovery. Quiet content or a log alone must never produce a PASS.
    checks = {
        'baselineExercisesTarget': all(4500 <= x <= 7500 for x in b),
        'initialMatchesBaseline': .8 <= a[0] / b[0] <= 1.2,
        'lowNear2Mbps': 1400 <= a[1] <= 2600,
        'lowBelowHalfBaseline': a[1] < .5 * b[1],
        'recoveryNear6Mbps': 4500 <= a[2] <= 7500,
        'recoveryAboveTwiceLow': a[2] > 2 * a[1],
        'recoveryMatchesBaseline': .8 <= a[2] / b[2] <= 1.2,
    }
    return {'pass': all(checks.values()), 'checks': checks}


def load_helper(path):
    spec = importlib.util.spec_from_file_location('rate_commission', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--commission-helper', type=Path, default=ROOT.parent /
                        'opensagetv-vibe-WebClient-Plugin/scripts/commission-mobile.py')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    expected = (ROOT/'artifacts/active/MIM-RATE-001').resolve()
    if not output.is_relative_to(expected):
        raise RuntimeError('Output must belong to artifacts/active/MIM-RATE-001')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    run = output / (stamp + '-' + uuid.uuid4().hex[:8])
    run.mkdir(parents=True, exist_ok=False)
    helper = load_helper(args.commission_helper)
    cfg = helper.configuration()
    report = {'task': 'MIM-RATE-001', 'scope': 'external installed-engine QSV only',
              'clientChanges': False, 'engine': ENGINE,
              'settings': {'codec': 'h264_qsv', 'size': '1280x720', 'fps': 60,
                           'targetsKbps': [6000, 2000, 6000], 'changeAtSeconds': [20, 40],
                           'measurementWindows': WINDOWS, 'vbvKbits': 6000,
                           'bFrames': 0, 'hlsSegmentSeconds': 2},
              'nvenc': 'NOT TESTED: requires an available NVIDIA GPU',
              'windows': 'DEFERRED', 'mimForwardingAndClients': 'NOT TESTED'}
    client = None
    remote_dir = None
    archived = False
    try:
        report['activityBefore'] = helper.activity(cfg)
        if not report['activityBefore'].get('safeToRestart'):
            raise RuntimeError('Server activity guard refuses competing experiment')
        client = helper.ssh(cfg)
        prefix = 'docker exec -w /opt/sagetv/server ' + shlex.quote(cfg['unraid_container_name']) + ' '

        def remote(command):
            return helper.remote(client, prefix + command)

        stock = remote('sha256sum -c /usr/local/share/sagetv-stock/protected.sha256')
        report['stockBefore'] = stock.count(': OK')
        if report['stockBefore'] != 20:
            raise RuntimeError('Expected all20 protected stock files')
        protected = [ENGINE, PROBE, ENGINE.rsplit('/', 1)[0] + '/ffmpeg.real.ini']
        before = remote('sha256sum ' + ' '.join(map(shlex.quote, protected)))
        report['runtimeHashesBefore'] = before.strip().splitlines()
        report['gpu'] = remote('sh -c ' + shlex.quote(
            'cat /sys/class/drm/renderD128/device/vendor '
            '/sys/class/drm/renderD128/device/device; '
            'readlink /sys/class/drm/renderD128/device/driver')).strip().splitlines()
        encoders = remote('ps -eo comm')
        if any(p.strip() in ['ffmpeg', 'ffmpeg.real', 'ffmpeg_MIM', 'SageTVTranscoder']
               for p in encoders.splitlines()):
            raise RuntimeError('Another encoder is active; leave it untouched')
        remote_dir = remote('mktemp -d /tmp/mim-rate001-XXXXXXXX').strip()
        if not re.fullmatch(r'/tmp/mim-rate001-[A-Za-z0-9]{8}', remote_dir):
            raise RuntimeError('Unexpected owned scratch path')
        report['remoteScratch'] = remote_dir
        report['engineBanner'] = remote(shlex.quote(ENGINE) + ' -version').splitlines()[0]

        def identity(pid):
            text = remote('sh -c ' + shlex.quote(
                'readlink /proc/%d/exe; cat /proc/%d/stat; '
                'readlink /proc/%d/fd/*' % (pid, pid, pid)))
            lines = text.splitlines()
            if lines[0] != ENGINE:
                raise AssertionError('Owned PID is not the plugin encoder')
            stat_tail = lines[1].rsplit(')', 1)[1].split()
            return {'pid': pid, 'startTicks': stat_tail[19],
                    'gpuDescriptors': [x for x in lines[2:] if x.startswith('/dev/dri/')]}

        def encode(name, adaptive):
            destination = remote_dir + '/' + name
            remote('mkdir ' + shlex.quote(destination))
            command = [ENGINE, '-hide_banner', '-loglevel', 'verbose', '-stats_period', '0.25',
                       '-sagetvratectrl', '-init_hw_device', 'qsv=hw:/dev/dri/renderD128',
                       '-filter_hw_device', 'hw', '-re', '-f', 'lavfi', '-i',
                       'testsrc2=size=1280x720:rate=60', '-t', '60', '-an',
                       '-vf', 'format=nv12,hwupload=extra_hw_frames=32',
                       '-c:v', 'h264_qsv', '-preset', 'veryfast', '-b:v', '6000k',
                       '-maxrate', '6000k', '-bufsize', '6000k', '-look_ahead', '0',
                       '-bf', '0', '-g', '120', '-forced_idr', '1',
                       '-progress', 'pipe:1', '-f', 'hls', '-hls_time', '2',
                       '-hls_list_size', '0', '-hls_flags', 'independent_segments',
                       '-hls_segment_filename', destination + '/part-%03d.ts',
                       destination + '/stream.m3u8']
            shell = 'printf "ENCODER_PID=%s\\n" "$$"; exec ' + shlex.join(command)
            channel = client.get_transport().open_session(timeout=15)
            channel.exec_command(prefix.replace('docker exec ', 'docker exec -i ', 1) +
                                 'sh -c ' + shlex.quote(shell))
            pid = None
            first_identity = None
            progress_buffer = ''
            commands = []
            clock = 0.0
            deadline = time.monotonic() + 110
            error = None
            try:
                with (run/(name+'-stderr.log')).open('wb') as errlog, \
                     (run/(name+'-progress.log')).open('wb') as progress:
                    while True:
                        if channel.recv_stderr_ready():
                            errlog.write(channel.recv_stderr(65536))
                        if channel.recv_ready():
                            data = channel.recv(65536)
                            progress.write(data)
                            progress_buffer += data.decode('utf-8', errors='replace')
                            while '\n' in progress_buffer:
                                line, progress_buffer = progress_buffer.split('\n', 1)
                                if line.startswith('ENCODER_PID='):
                                    pid = int(line.split('=')[1])
                                elif line.startswith('out_time_us=') and line.split('=')[1].isdigit():
                                    clock = int(line.split('=')[1])/1e6
                                    if first_identity is None:
                                        first_identity = identity(pid)
                                        if not first_identity['gpuDescriptors']:
                                            raise AssertionError('No GPU descriptor on actual encoder')
                                    if adaptive and len(commands) < 2 and clock >= (20, 40)[len(commands)]:
                                        current = identity(pid)
                                        if current != first_identity:
                                            raise AssertionError('Encoder process/GPU identity changed')
                                        delta = (-4000, 4000)[len(commands)]
                                        channel.sendall(('videorateadapt %+d\n' % delta).encode())
                                        commands.append({'outTimeSeconds': clock, 'deltaKbps': delta,
                                                         'identity': current})
                                        print(name + ' sent delta ' + str(delta) + ' at ' + str(clock), flush=True)
                        if channel.exit_status_ready() and not channel.recv_ready() and not channel.recv_stderr_ready():
                            break
                        if time.monotonic() > deadline:
                            raise TimeoutError('Owned encoding exceeded110s')
                        time.sleep(.025)
                    code = channel.recv_exit_status()
                    if code:
                        raise RuntimeError('Encoder exited ' + str(code))
                    if clock < 59 or adaptive and len(commands) != 2:
                        raise AssertionError('Incomplete encoding/control sequence')
            except Exception as failure:
                error = failure
                if pid is not None:
                    # Signal only the exact still-matching process created above.
                    try:
                        current = identity(pid)
                        if first_identity is None or current == first_identity:
                            remote('kill -TERM ' + str(pid))
                    except Exception:
                        pass
            finally:
                channel.close()
            if error:
                raise error
            packets = json.loads(remote(shlex.quote(PROBE) + ' -v error -select_streams v:0 '
                '-show_packets -show_entries packet=pts_time,dts_time,size -of json ' +
                shlex.quote(destination+'/stream.m3u8')))['packets']
            result = packet_metrics(packets)
            result.update({'commands': commands, 'identity': first_identity,
                           'finalProgressSeconds': clock, 'exitCode': code})
            decode_command = (shlex.quote(ENGINE) + ' -hide_banner -loglevel error -nostdin '
                              '-i ' + shlex.quote(destination+'/stream.m3u8') +
                              ' -map 0:v:0 -f null -')
            _, stdout, stderr = client.exec_command(prefix+decode_command, timeout=30)
            decode_out, decode_err = stdout.read(), stderr.read()
            decode_code = stdout.channel.recv_exit_status()
            (run/(name+'-decode.log')).write_bytes(decode_out+decode_err)
            result['decodePass'] = decode_code == 0 and not decode_err.strip()
            if not result['decodePass']:
                raise AssertionError('HLS full decode has errors')
            print(name + ' video kbps ' + str(result['videoKbps']), flush=True)
            return result

        report['baseline'] = encode('baseline', False)
        if not helper.activity(cfg).get('safeToRestart'):
            raise RuntimeError('New SageTV activity: refuse second encode')
        report['adaptive'] = encode('adaptive', True)
        report['comparison'] = compare(report['baseline'], report['adaptive'])
        report['status'] = 'PASS' if report['comparison']['pass'] else 'FAIL'
        after = remote('sha256sum ' + ' '.join(map(shlex.quote, protected)))
        report['runtimeHashesUnchanged'] = before == after
        report['stockAfter'] = remote('sha256sum -c /usr/local/share/sagetv-stock/protected.sha256').count(': OK')
        report['activityAfter'] = helper.activity(cfg)
        if not report['runtimeHashesUnchanged'] or report['stockAfter'] != 20:
            raise AssertionError('Protected/runtime inputs changed')
    except Exception as failure:
        report['status'] = 'FAIL'
        report['failure'] = type(failure).__name__ + ': ' + str(failure)
    finally:
        if client and remote_dir and re.fullmatch(r'/tmp/mim-rate001-[A-Za-z0-9]{8}', remote_dir):
            try:
                prefix = 'docker exec -w /opt/sagetv/server ' + shlex.quote(cfg['unraid_container_name']) + ' '
                _, stdout, stderr = client.exec_command(prefix + 'tar -C ' + shlex.quote(remote_dir) + ' -czf - .', timeout=30)
                with (run/'remote-capture.tar.gz').open('wb') as archive:
                    while True:
                        chunk = stdout.read(65536)
                        if not chunk:
                            break
                        archive.write(chunk)
                if stdout.channel.recv_exit_status():
                    raise RuntimeError('Capture archive failed: '+stderr.read().decode()[:300])
                archived = True
                report['captureSha256'] = hashlib.sha256((run/'remote-capture.tar.gz').read_bytes()).hexdigest()
                # Exact mktemp-created disposable scratch only, after capture.
                helper.remote(client, prefix + 'rm -r -- ' + shlex.quote(remote_dir))
                report['remoteScratchRemovedAfterArchive'] = True
            except Exception as failure:
                report['cleanupFailure'] = str(failure)
                report['remoteScratchRemovedAfterArchive'] = False
        if client:
            client.close()
        report['archiveComplete'] = archived
        (run/'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
        print(json.dumps({'status': report.get('status'), 'report': str(run/'report.json'),
                          'failure': report.get('failure'), 'comparison': report.get('comparison')}, indent=2))
    return 0 if report.get('status') == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
