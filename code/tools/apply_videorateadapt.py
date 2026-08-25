#!/usr/bin/env python3
"""Apply the minimal SageTV videorateadapt patch to pristine FFmpeg n9.0.1."""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def write(p: Path, s: str) -> None:
    p.write_text(s, encoding="utf-8", newline="\n")


def replace_once(p: Path, old: str, new: str, label: str) -> None:
    s = read(p)
    if new in s:
        print(f"[already] {label}")
        return
    n = s.count(old)
    if n != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor in {p}, found {n}")
    write(p, s.replace(old, new, 1))
    print(f"[patched] {label}")


def insert_after(p: Path, anchor: str, addition: str, label: str) -> None:
    s = read(p)
    if addition in s:
        print(f"[already] {label}")
        return
    n = s.count(anchor)
    if n != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor in {p}, found {n}")
    write(p, s.replace(anchor, anchor + addition, 1))
    print(f"[patched] {label}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("ffmpeg_root", type=Path)
    ap.add_argument("--compat-dir", type=Path, required=True)
    a = ap.parse_args()
    root = a.ffmpeg_root.resolve()
    compat = a.compat_dir.resolve()

    for rel in ("fftools/Makefile", "fftools/ffmpeg.c", "fftools/ffmpeg_opt.c", "fftools/ffmpeg_enc.c"):
        if not (root / rel).is_file():
            raise RuntimeError(f"Not an expected FFmpeg tree: missing {rel}")

    for name in ("sagetv_rateadapt.c", "sagetv_rateadapt.h"):
        shutil.copy2(compat / name, root / "fftools" / name)
        print(f"[copied] fftools/{name}")

    makefile = root / "fftools/Makefile"
    insert_after(makefile,
                 "    fftools/ffmpeg_sched.o      \\\n",
                 "    fftools/sagetv_rateadapt.o  \\\n",
                 "build SageTV videorateadapt object")

    opt = root / "fftools/ffmpeg_opt.c"
    insert_after(opt, '#include "ffmpeg.h"\n', '#include "sagetv_rateadapt.h"\n', "ffmpeg_opt include")
    stdin_anchor = '''    { "stdin",                  OPT_TYPE_BOOL, OPT_EXPERT,\n        { &stdin_interaction },\n      "enable or disable interaction on standard input" },\n'''
    rate_opt = '''    { "sagetvratectrl",           OPT_TYPE_BOOL, OPT_EXPERT,\n        { &sagetv_rate_ctrl },\n        "accept SageTV videorateadapt commands through stdin" },\n'''
    insert_after(opt, stdin_anchor, rate_opt, "SageTV rate-control option")

    ffmpeg = root / "fftools/ffmpeg.c"
    insert_after(ffmpeg, '#include "ffmpeg.h"\n', '#include "sagetv_rateadapt.h"\n', "ffmpeg include")
    keyboard_anchor = '''static int check_keyboard_interaction(int64_t cur_time)\n{\n    int i, key;\n    static int64_t last_time;\n'''
    keyboard_new = '''static int check_keyboard_interaction(int64_t cur_time)\n{\n    int i, key;\n    static int64_t last_time;\n\n    if (sagetv_rate_ctrl) {\n        while ((key = read_key()) > 0)\n            sagetv_rateadapt_feed(key);\n        return 0;\n    }\n'''
    replace_once(ffmpeg, keyboard_anchor, keyboard_new, "SageTV stdin rate-control parser")

    loop_anchor = '''    while (!sch_wait(sch, stats_period, &transcode_ts)) {\n'''
    loop_new = '''    const int64_t wait_period = sagetv_rate_ctrl ? FFMIN(stats_period, INT64_C(100000)) : stats_period;\n    while (!sch_wait(sch, wait_period, &transcode_ts)) {\n'''
    replace_once(ffmpeg, loop_anchor, loop_new, "SageTV rate-control responsiveness")

    check_anchor = '''        /* if 'q' pressed, exits */\n        if (stdin_interaction)\n            if (check_keyboard_interaction(cur_time) < 0)\n                break;\n'''
    check_new = '''        /* SageTV rate control must remain active even when ordinary FFmpeg\n         * keyboard interaction has been disabled by command-line/input rules. */\n        if (stdin_interaction || sagetv_rate_ctrl)\n            if (check_keyboard_interaction(cur_time) < 0)\n                break;\n'''
    replace_once(ffmpeg, check_anchor, check_new, "SageTV rate-control stdin activation")

    enc = root / "fftools/ffmpeg_enc.c"
    insert_after(enc, '#include "ffmpeg.h"\n', '#include "sagetv_rateadapt.h"\n', "ffmpeg_enc include")
    enc_priv_anchor = '''    Scheduler      *sch;\n    unsigned        sch_idx;\n} EncoderPriv;\n'''
    enc_priv_new = '''    Scheduler      *sch;\n    unsigned        sch_idx;\n\n    int64_t         sagetv_rate_adjust_applied;\n} EncoderPriv;\n'''
    replace_once(enc, enc_priv_anchor, enc_priv_new, "encoder rate state")

    send_anchor = '''    update_benchmark(NULL);\n\n    ret = avcodec_send_frame(enc, frame);\n'''
    send_new = '''    if (frame && enc->codec_type == AVMEDIA_TYPE_VIDEO)\n        sagetv_rateadapt_apply(enc, &ep->sagetv_rate_adjust_applied);\n\n    update_benchmark(NULL);\n\n    ret = avcodec_send_frame(enc, frame);\n'''
    replace_once(enc, send_anchor, send_new, "runtime videorateadapt")

    (root / ".sagetv_videorateadapt_only").write_text(
        "Minimal SageTV videorateadapt patch for FFmpeg n9.0.1\n", encoding="utf-8")
    print(f"[ok] minimal videorateadapt patch applied to {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
