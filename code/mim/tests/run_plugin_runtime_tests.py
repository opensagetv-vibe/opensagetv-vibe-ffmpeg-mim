#!/usr/bin/env python3
"""Regression tests for deterministic SageTV plugin runtime archives."""

from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PACKAGER = ROOT / "code" / "tools" / "package_sagetv_plugin_runtime.py"
PREFIX = "plugins/SageTVFFmpegPlugin/runtime/"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8")


def package(repo: Path, target: str) -> Path:
    result = subprocess.run(
        [sys.executable, str(PACKAGER), "--repo", str(repo), "--target", target, "--version", "9.8.7"],
        check=True,
        text=True,
        capture_output=True,
    )
    return Path(result.stdout.splitlines()[0])


def assert_archive(path: Path, target: str) -> None:
    binaries = (
        {"ffmpeg_MIM", "ffmpeg.real", "ffprobe"}
        if target == "linux-x64"
        else {"ffmpeg_MIM.exe", "ffmpeg.real.exe", "ffprobe.exe"}
    )
    expected = {PREFIX + name for name in binaries | {"ffmpeg.real.ini.default", "THIRD_PARTY_NOTICES.md"}}
    with zipfile.ZipFile(path) as archive:
        assert set(archive.namelist()) == expected
        assert PREFIX + "ffmpeg.real.ini" not in archive.namelist()
        for info in archive.infolist():
            assert info.date_time == (1980, 1, 1, 0, 0, 0)
            mode = (info.external_attr >> 16) & 0o777
            assert mode == (0o755 if Path(info.filename).name in binaries else 0o644)


def main() -> int:
    with tempfile.TemporaryDirectory() as temporary:
        repo = Path(temporary)
        write(repo / "ffmpeg.real.ini", "[general]\nenabled=true\n")
        write(repo / "THIRD_PARTY_NOTICES.md", "notices\n")
        for name in ("ffmpeg_MIM", "ffmpeg.real", "ffprobe"):
            write(repo / "output" / "linux-x64" / name, name)
        for name in ("SageTVTranscoder.exe", "ffmpeg.real.exe", "ffprobe.exe"):
            write(repo / "output" / "windows-x64" / name, name)

        for target in ("linux-x64", "windows-x64"):
            first = package(repo, target)
            first_hash = sha256(first)
            first.unlink()
            second = package(repo, target)
            assert sha256(second) == first_hash
            assert_archive(second, target)

        (repo / "output" / "linux-x64" / "ffprobe").unlink()
        failed = subprocess.run(
            [sys.executable, str(PACKAGER), "--repo", str(repo), "--target", "linux-x64", "--version", "9.8.7"],
            text=True,
            capture_output=True,
        )
        assert failed.returncode != 0
        assert "required file missing" in failed.stderr

    print("[PASS] deterministic SageTV plugin runtime package tests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
