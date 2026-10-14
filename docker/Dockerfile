# riscos-crossdev as a container image: the toolchain and devkit this
# release names, installed, with every package make check needs.
#
#   docker build -f docker/Dockerfile -t riscos-crossdev .     (from the repo root)
#   docker run --rm -v "$PWD":/src riscos-crossdev make         (in your project)
#
# The release workflow (.github/workflows/docker.yml) builds it for each
# tag, runs make check inside it, and publishes it as
# ghcr.io/adyoull/riscos-crossdev:<version>. Inside, RCD_DIR,
# RISCOS_TOOLCHAIN and RISCOS_DEVKIT are set and the toolchain is on PATH,
# so a Makefile with `include $(RCD_DIR)/riscos.mk` or CMake with
# -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/riscos.cmake works as it is.
ARG BASE=ubuntu:24.04
FROM ${BASE}

ARG DEBIAN_FRONTEND=noninteractive
# gcc-13-multilib, not gcc-multilib: on Ubuntu 24.04 gcc-multilib conflicts
# with gcc-arm-linux-gnueabihf (docs/SETUP.md).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential gcc-13-multilib gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
      python3 python3-pip ca-certificates curl xz-utils zip unzip git gawk \
      cmake pkg-config libglib2.0-0t64 libcairo2-dev \
 && pip3 install --no-cache-dir --break-system-packages unicorn \
 && rm -rf /var/lib/apt/lists/*

COPY . /opt/riscos-crossdev
WORKDIR /opt/riscos-crossdev
# The toolchain and devkit named in toolchain/PREBUILT and devkit/DEVKIT,
# checked by sha256 (tarballs already in toolchain/dl or devkit/dl are used
# as they are). The tarballs aren't kept.
RUN make prebuilt devkit && rm -rf toolchain/dl devkit/dl

ARG VERSION=dev
RUN echo "riscos-crossdev $VERSION" > /opt/riscos-crossdev/VERSION
ENV RCD_DIR=/opt/riscos-crossdev \
    RISCOS_TOOLCHAIN=/opt/riscos-crossdev/toolchain/env \
    RISCOS_DEVKIT=/opt/riscos-crossdev/devkit/env \
    PATH=/opt/riscos-crossdev/toolchain/env/bin:$PATH
LABEL org.opencontainers.image.source="https://github.com/adyoull/riscos-crossdev" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.description="Build and test RISC OS software on Linux: GCCSDK GCC 10, UnixLib, the riscos-mesa devkit, checks, the Fake RISC OS, QEMU with RISC OS alignment traps" \
      org.opencontainers.image.licenses="MIT AND GPL-2.0-or-later AND GPL-3.0-or-later"
WORKDIR /src
