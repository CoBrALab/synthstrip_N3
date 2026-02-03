FROM docker.io/freesurfer/synthstrip:latest

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
    wget \
    unzip \
    ca-certificates \
    bc \
    libjpeg62 \
    imagemagick \
    perl \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Install minc-toolkit 1.9.18
# URL: https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-1.9.18-20200813-Ubuntu_20.04-x86_64.deb
# Note: This package was built for Ubuntu 20.04, so we might need to handle dependencies carefully.
RUN wget -q https://packages.bic.mni.mcgill.ca/minc-toolkit/min/minc-toolkit-1.9.18-20200813-Ubuntu_20.04-x86_64.deb -O /tmp/minc-toolkit.deb \
    && apt-get update \
    && apt-get install -y /tmp/minc-toolkit.deb \
    && rm /tmp/minc-toolkit.deb \
    && rm -f /opt/minc/1.9.18/lib/libl_* \
    && rm -f /opt/minc/1.9.18/lib/*ants* \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install ANTs 2.6.5
# URL: https://github.com/ANTsX/ANTs/releases/download/v2.6.5/ants-2.6.5-ubuntu-24.04-X64-gcc.zip
RUN wget -q https://github.com/ANTsX/ANTs/releases/download/v2.6.5/ants-2.6.5-ubuntu-24.04-X64-gcc.zip -O /tmp/ants.zip \
    && unzip /tmp/ants.zip -d /opt \
    && mv /opt/ants-2.6.5/bin/* /opt/minc/1.9.18/bin/ \
    && rm -rf /opt/ants-2.6.5 \
    && rm /tmp/ants.zip

# MINC compression level
ENV MINC_COMPRESS=4

# Copy pipeline scripts
COPY synthstrip_N3.sh /usr/local/bin/synthstrip_N3.sh
RUN chmod +x /usr/local/bin/synthstrip_N3.sh

# Copy configuration files
COPY configs/ /usr/local/share/synthstrip_N3/configs/

# Create entrypoint wrapper that sources MINC environment before running the script
# This ensures proper environment setup in both Docker and Apptainer/Singularity
# Use bash for compatibility with 'source' command
RUN echo '#!/bin/bash' > /entrypoint.sh \
    && echo 'source /opt/minc/1.9.18/minc-toolkit-config.sh' >> /entrypoint.sh \
    && echo 'exec /usr/local/bin/synthstrip_N3.sh "$@"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Set the entrypoint wrapper as the ENTRYPOINT
ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]
