# syntax=docker/dockerfile:1.7
# ONE final SageTV build image for the two supported 64-bit targets.
# BtbN images are remote BuildKit stages only and are not intentionally loaded
# or tagged in Docker Desktop by the bootstrap script.
ARG BTBN_BASE_IMAGE=ghcr.io/btbn/ffmpeg-builds/base:latest
ARG BTBN_LINUX_IMAGE=ghcr.io/btbn/ffmpeg-builds/linux64-gpl-9.0:latest
ARG BTBN_WIN64_IMAGE=ghcr.io/btbn/ffmpeg-builds/win64-gpl-9.0:latest

# Capture the exact BtbN Linux x64 GPL/FFmpeg-9 environment.
FROM ${BTBN_LINUX_IMAGE} AS btbn_linux
USER root
RUN bash -lc '\
  vars="FFBUILD_TOOLCHAIN FFBUILD_RUST_TARGET FFBUILD_TARGET_FLAGS FFBUILD_CROSS_PREFIX FFBUILD_PREFIX FFBUILD_DESTDIR FFBUILD_DESTPREFIX FFBUILD_CMAKE_TOOLCHAIN PKG_CONFIG PKG_CONFIG_LIBDIR CC CXX LD AR RANLIB NM DLLTOOL GENDEF CFLAGS CXXFLAGS LDFLAGS STAGE_CFLAGS STAGE_CXXFLAGS FF_CONFIGURE FF_CFLAGS FF_CXXFLAGS FF_LIBS FF_LDFLAGS FF_LDEXEFLAGS"; \
  : > /sagetv-env.sh; \
  for v in $vars; do if [[ -v "$v" ]]; then printf "export %s=%q\\n" "$v" "${!v}" >> /sagetv-env.sh; fi; done'

# Capture the exact BtbN Windows x64 GPL/FFmpeg-9 environment.
FROM ${BTBN_WIN64_IMAGE} AS btbn_win64
USER root
RUN bash -lc '\
  vars="FFBUILD_TOOLCHAIN FFBUILD_RUST_TARGET FFBUILD_TARGET_FLAGS FFBUILD_CROSS_PREFIX FFBUILD_PREFIX FFBUILD_DESTDIR FFBUILD_DESTPREFIX FFBUILD_CMAKE_TOOLCHAIN PKG_CONFIG PKG_CONFIG_LIBDIR CC CXX LD AR RANLIB NM DLLTOOL GENDEF CFLAGS CXXFLAGS LDFLAGS STAGE_CFLAGS STAGE_CXXFLAGS FF_CONFIGURE FF_CFLAGS FF_CXXFLAGS FF_LIBS FF_LDFLAGS FF_LDEXEFLAGS"; \
  : > /sagetv-env.sh; \
  for v in $vars; do if [[ -v "$v" ]]; then printf "export %s=%q\\n" "$v" "${!v}" >> /sagetv-env.sh; fi; done'

# ONE final image. The common BtbN base is present once and the two target-
# specific compiler/dependency trees are stored under /opt/sagetv/targets.
FROM ${BTBN_BASE_IMAGE} AS final
USER root
ARG BUILDER_VERSION=9.0.1-v5
ARG FFMPEG_TAG=n9.0.1

RUN mkdir -p \
    /opt/sagetv/targets/linux64 \
    /opt/sagetv/targets/win64 \
    /opt/sagetv/bin \
    /opt/sagetv/src/ffmpeg

COPY --from=btbn_linux /opt/ct-ng /opt/sagetv/targets/linux64/ct-ng
COPY --from=btbn_linux /opt/ffbuild /opt/sagetv/targets/linux64/ffbuild
COPY --from=btbn_linux /sagetv-env.sh /opt/sagetv/targets/linux64/env.sh

COPY --from=btbn_win64 /opt/ct-ng /opt/sagetv/targets/win64/ct-ng
COPY --from=btbn_win64 /opt/ffbuild /opt/sagetv/targets/win64/ffbuild
COPY --from=btbn_win64 /sagetv-env.sh /opt/sagetv/targets/win64/env.sh

# ffmpeg_src is a named LOCAL build context prepared on the WSL/Linux host.
# This avoids downloading FFmpeg source from inside a BtbN container.
COPY --from=ffmpeg_src / /opt/sagetv/src/ffmpeg/

COPY code/docker/unified_entrypoint.sh /opt/sagetv/bin/unified_entrypoint.sh
RUN chmod +x /opt/sagetv/bin/unified_entrypoint.sh; \
    test -x /opt/sagetv/targets/linux64/ct-ng/bin/x86_64-linux-gnu-gcc || true; \
    test -x /opt/sagetv/targets/win64/ct-ng/bin/x86_64-w64-mingw32-gcc || true

LABEL org.opencontainers.image.title="SageTV FFmpeg MIM Builder" \
      org.opencontainers.image.description="One BtbN-based builder image for SageTV Linux x64 and Windows x64" \
      org.opencontainers.image.version="${BUILDER_VERSION}"

ENV SAGETV_BUILDER_VERSION=${BUILDER_VERSION} \
    SAGETV_FFMPEG_TAG=${FFMPEG_TAG}

WORKDIR /project
ENTRYPOINT ["/opt/sagetv/bin/unified_entrypoint.sh"]
CMD ["help"]
