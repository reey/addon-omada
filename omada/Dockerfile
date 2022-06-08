ARG BUILD_FROM=ghcr.io/hassio-addons/ubuntu-base/amd64:7.2.0
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Set shell
# SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base system
ARG BUILD_ARCH=amd64
ARG OMADA_VER=5.3.1
ARG OMADA_TAR="Omada_SDN_Controller_v${OMADA_VER}_Linux_x64.tar.gz"
ARG OMADA_URL="https://static.tp-link.com/upload/software/2022/202205/20220507/${OMADA_TAR}"

COPY rootfs/install.sh rootfs/healthcheck.sh /

RUN /install.sh && rm /install.sh

# Copy root filesystem
COPY rootfs/etc /etc

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# WORKDIR /opt/tplink/EAPController/lib
