
FROM ghcr.io/sdr-enthusiasts/docker-baseimage:base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Now install all the packages and perform basic config:
RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # logging
    KEPT_PACKAGES+=(gawk) && \
    KEPT_PACKAGES+=(pv) && \
    # a few KEPT_PACKAGES for debugging - they can be removed in the future
    KEPT_PACKAGES+=(procps nano) && \
#
# define packages needed for noisecapt
    KEPT_PACKAGES+=(jq) && \
    KEPT_PACKAGES+=(bc) && \
    KEPT_PACKAGES+=(lighttpd) && \
    KEPT_PACKAGES+=(iputils-ping) && \
    KEPT_PACKAGES+=(alsa-utils) && \
    KEPT_PACKAGES+=(sox) && \
#
# Install all these packages:
    apt-get update && \
    apt-get install -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends  --no-install-suggests\
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
#
# Do some other stuff
    echo "alias dir=\"ls -alsvh\"" >> /root/.bashrc && \
# Clean up
    if (( ${#TEMP_PACKAGES[*]} > 0 )); then apt-get remove -y ${TEMP_PACKAGES[@]}; fi && \
    apt-get autoremove -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y && \
    rm -rf /tmp/* /var/lib/apt/lists/*
    # following lines commented out for development purposes
    # rm -rf /git/*

# Last, copy ROOTFS into place and install the lighttpd Mod:
COPY rootfs/ /

ENTRYPOINT [ "/init" ]

EXPOSE 80
