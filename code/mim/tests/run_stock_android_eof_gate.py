#!/usr/bin/env python3
"""Focused existing classic Fixed client gate after MIM raw-EOF correction.

Runs only in the commissioned reusable container. Existing Android MCP owns
all device/public-server controls; no APK rebuild, Core edits or new controls.
"""
import hashlib,importlib.util,json,os,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ANDROID=Path('/workspace/android-client');WEB=Path('/workspace/web-client-plugin')
sys.path.insert(0,str(ANDROID/'scripts'));sys.path.insert(0,str(ANDROID/'mcp/src'))
from mcp_seek_suite import MCPProcess,call_dict,initialize
from sagetv_dev_mcp.config import load_test_environment
from sagetv_dev_mcp.cli import client as adb_client
import android_test_keep_awake as awake
spec=importlib.util.spec_from_file_location('commission',WEB/'scripts/commission-mobile.py')
C=importlib.util.module_from_spec(spec);spec.loader.exec_module(C)

def main():
    out=ROOT/'artifacts/active/MIM-STDIN-001';out.mkdir(parents=True,exist_ok=True)
    if Path(os.environ.get('SAGETV_ARTIFACT_DIR','')).resolve()!=out.resolve():raise RuntimeError('Exact owning artifact directory required')
    env=load_test_environment();serial=env.device_serial()
    if serial!='192.168.10.25:5555' or env.server_address()!='192.168.10.232':raise RuntimeError('Exact commissioned Non-Pro/stock232 required')
    cfg=C.configuration()
    if not C.activity(cfg).get('safeToRestart'):raise RuntimeError('Independent idle stock232 required')
    adb,_=adb_client()
    try:
        adb.connect()
        if adb.shell('getprop ro.product.model').strip()!='AFTMM':raise RuntimeError('Wrong model')
        path=adb.shell('pm path opensagetv.vibe.miniclient.debug').strip()
        if not re.fullmatch(r'package:/data/app/[A-Za-z0-9._~+/=-]+/base\.apk',path):raise RuntimeError('Unambiguous installed development APK required')
        apk=ANDROID/'artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk'
        blob=subprocess.run(adb._base(True)+['exec-out','cat',path[8:]],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,check=True).stdout
        installed_sha=hashlib.sha256(blob).hexdigest()
        if len(blob)!=apk.stat().st_size or installed_sha!=hashlib.sha256(apk.read_bytes()).hexdigest():raise RuntimeError('Installed APK differs from built candidate')
        del blob
    finally:adb.close()
    stamp=time.strftime('%Y%m%dT%H%M%SZ',time.gmtime())
    report=dict(passed=False,physicalDevice=True,hdmiPictureVerified=False,apkSha256=installed_sha,server='192.168.10.232',serial=serial,selectedTransport='Fixed',mimDirect='off',cleanup={})
    client=MCPProcess();checkpoint=False;lease=False
    try:
        initialize(client);call_dict(client,'adb_connect',timeout=30)
        # Only an existing test checkpoint is restored; no app data is cleared.
        call_dict(client,'dev_restore_settings',timeout=30)
        captured=call_dict(client,'dev_checkpoint_settings',timeout=30)
        if not captured.get('captured'):raise RuntimeError('Settings checkpoint unavailable')
        checkpoint=True
        lease=bool(awake.begin(serial,awake.state_path(serial),'automated').get('active'))
        command=[sys.executable,str(ANDROID/'scripts/mcp_session_test.py'),
            '--server-address','192.168.10.232','--server-path','/var/media/videos/USER_TEST/TheChase-26742651-0.ts',
            '--player','media3','--streaming','fixed','--decoding','hardware','--mim-direct-mode','off',
            '--fixed-encoding-preference','always','--fixed-remuxing-preference','off',
            '--fixed-video-resolution','720','--fixed-video-bitrate-kbps','3000',
            '--restart-from-beginning','--run-seek-health','--run-pause-health','--verify-ms','1200','--exit','stop']
        log=out/(stamp+'-classic-fixed.log')
        # A new explicit process owns its intents. Never replay on timeout.
        with log.open('x',encoding='utf-8') as f:
            result=subprocess.run(command,cwd=ANDROID,stdout=f,stderr=subprocess.STDOUT,timeout=420,check=False)
        report.update(passed=result.returncode==0,returnCode=result.returncode,privateLog=log.name)
    except Exception as error:
        report.update(passed=False,errorType=type(error).__name__)
    finally:
        try:
            result=call_dict(client,'dev_exit_session',{'stop_app':True},timeout=30)
            report['cleanup']['exit']={key:result.get(key) for key in ('stopped','wasConnected')}
        except Exception:report['cleanup']['exitError']=True
        if checkpoint:
            try:report['cleanup']['settings']=call_dict(client,'dev_restore_settings',timeout=30)
            except Exception:report['cleanup']['settingsError']=True
        if lease:
            try:report['cleanup']['power']=awake.end(serial,awake.state_path(serial),'automated')
            except Exception:report['cleanup']['powerError']=True
        client.close()
        report['passed']=report['passed'] and not any(k.endswith('Error') for k in report['cleanup'])
        path=out/(stamp+'-classic-fixed.json')
        with path.open('x',encoding='utf-8') as f:json.dump(report,f,indent=2)
        print(json.dumps(dict(passed=report['passed'],errorType=report.get('errorType'),report=str(path))))
    raise SystemExit(0 if report['passed'] else 1)
if __name__=='__main__':main()
