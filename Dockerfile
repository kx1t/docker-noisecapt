
FROM debian:stable-slim

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy needs to be here to prevent github actions from failing.
# SSL Certs are pre-loaded into the root_certs via a job in github action:
# See: "Copy CA Certificates from GitHub Runner to Image rootfs" in deploy.yml
COPY root_certs/ /

# Now install all the packages and perform basic config:
RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Required for building multiple packages.
    TEMP_PACKAGES+=(git) && \
    TEMP_PACKAGES+=(wget) && \
    # logging
    KEPT_PACKAGES+=(gawk) && \
    KEPT_PACKAGES+=(pv) && \
    # required for S6 overlay
    # curl kept for healthcheck
    # ca-certificates kept for python
    TEMP_PACKAGES+=(gnupg2) && \
    TEMP_PACKAGES+=(file) && \
    TEMP_PACKAGES+=(curl) && \
    KEPT_PACKAGES+=(ca-certificates) && \
    # a few KEPT_PACKAGES for debugging - they can be removed in the future
    KEPT_PACKAGES+=(procps nano aptitude netcat) && \
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
    git config --global advice.detachedHead false && \
#
# Do some other stuff
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
#
# install S6 Overlay
    curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
#
# Clean up
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y && \
    rm -rf /tmp/* /var/lib/apt/lists/*
    # following lines commented out for development purposes
    # rm -rf /git/*

# Last, copy ROOTFS into place and install the lighttpd Mod:
COPY rootfs/ /

ENTRYPOINT [ "/init" ]

EXPOSE 80
