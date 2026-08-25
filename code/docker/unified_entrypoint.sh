#!/usr/bin/env bash
set -euo pipefail

PROJECT=/project

usage() {
  cat <<'TXT'
SageTV unified FFmpeg/MIM builder

Commands:
  linux       build Linux x64 only
  windows     build Windows x64 only
  all         build Linux x64 + Windows x64
  target ID   build one target: linux-x64 | windows-x64
  info        show bundled target environments
TXT
}

select_target() {
  local target="$1" key
  case "$target" in
    linux-x64)   key=linux64 ;;
    windows-x64) key=win64 ;;
    *) echo "ERROR: unknown target '$target'" >&2; return 2 ;;
  esac

  local root="/opt/sagetv/targets/$key"
  [[ -d "$root/ct-ng" ]] || { echo "ERROR: missing bundled toolchain $root/ct-ng" >&2; return 1; }
  [[ -d "$root/ffbuild" ]] || { echo "ERROR: missing bundled dependency prefix $root/ffbuild" >&2; return 1; }
  [[ -f "$root/env.sh" ]] || { echo "ERROR: missing bundled BtbN environment $root/env.sh" >&2; return 1; }

  rm -rf /opt/ct-ng /opt/ffbuild
  ln -s "$root/ct-ng" /opt/ct-ng
  ln -s "$root/ffbuild" /opt/ffbuild

  unset FFBUILD_TOOLCHAIN FFBUILD_RUST_TARGET FFBUILD_TARGET_FLAGS FFBUILD_CROSS_PREFIX \
        FFBUILD_PREFIX FFBUILD_DESTDIR FFBUILD_DESTPREFIX FFBUILD_CMAKE_TOOLCHAIN \
        PKG_CONFIG PKG_CONFIG_LIBDIR CC CXX LD AR RANLIB NM DLLTOOL GENDEF \
        CFLAGS CXXFLAGS LDFLAGS STAGE_CFLAGS STAGE_CXXFLAGS FF_CONFIGURE \
        FF_CFLAGS FF_CXXFLAGS FF_LIBS FF_LDFLAGS FF_LDEXEFLAGS || true
  # shellcheck disable=SC1090
  source "$root/env.sh"
  export PATH="/opt/ct-ng/bin:${PATH}"
  export PKG_CONFIG_LIBDIR="/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig"

  echo "[builder] selected $target"
  echo "[builder] CC=${CC:-unset}"
  echo "[builder] CXX=${CXX:-unset}"
}

build_one() {
  local target="$1"
  select_target "$target"
  bash "$PROJECT/code/docker/build_target_unified.sh" "$target"
}

finish_ownership() {
  if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]] && [[ -d "$PROJECT/output" ]]; then
    chown -R "$HOST_UID:$HOST_GID" "$PROJECT/output" 2>/dev/null || true
  fi
}
trap finish_ownership EXIT

case "${1:-help}" in
  linux)
    build_one linux-x64
    ;;
  windows)
    build_one windows-x64
    ;;
  all)
    failed=()
    for t in linux-x64 windows-x64; do
      echo
      echo "================================================================"
      echo "BUILDING $t"
      echo "================================================================"
      if build_one "$t"; then
        echo "[SUCCESS] $t"
      else
        echo "[FAILED] $t" >&2
        failed+=("$t")
      fi
    done
    if ((${#failed[@]})); then
      echo "ERROR: failed targets: ${failed[*]}" >&2
      exit 1
    fi
    ;;
  target)
    build_one "${2:?target ID required}"
    ;;
  info)
    echo "builder=${SAGETV_BUILDER_VERSION:-unknown} ffmpeg=${SAGETV_FFMPEG_TAG:-unknown}"
    for t in linux64 win64; do
      printf '%-8s toolchain=' "$t"
      [[ -d "/opt/sagetv/targets/$t/ct-ng" ]] && echo yes || echo no
    done
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "ERROR: unknown command '$1'" >&2
    usage >&2
    exit 2
    ;;
esac
