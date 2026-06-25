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
    parallel \
    webp \
    perl \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Install minc-toolkit 1.9.18
# URL: https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-1.9.18-20200813-Ubuntu_20.04-x86_64.deb
# Note: This package was built for Ubuntu 20.04, so we might need to handle dependencies carefully.
RUN wget -q https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-1.9.18-20200813-Ubuntu_20.04-x86_64.deb -O /tmp/minc-toolkit.deb \
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

# The pipeline calls the skullstrip tool as 'synthstrip', but the base image ships it as
# /freesurfer/mri_synthstrip; expose it under the expected name (flags are identical).
RUN ln -s /freesurfer/mri_synthstrip /usr/local/bin/synthstrip

# Install CoBrALab antsRegistration_affine_SyN (the affine/SyN registration to model space).
# Vendored as a git submodule of this repo and copied in; the build context already has the
# checked-out content, so no network clone is needed here.
COPY antsRegistration_affine_SyN/ /opt/antsRegistration_affine_SyN/
ENV PATH="/opt/antsRegistration_affine_SyN:${PATH}"

# MINC compression level
ENV MINC_COMPRESS=4

# Bake in the default registration model and tissue priors (mni_icbm152_nlin_sym_09c).
# The script/configs expect them under ${QUARANTINE_PATH}/resources/... (mirror BIC layout
# so neither synthstrip_N3.sh nor configs/*.cfg need editing).
ENV QUARANTINE_PATH=/opt/quarantine
ENV MODELDIR=${QUARANTINE_PATH}/resources/mni_icbm152_nlin_sym_09c_minc2

# The zip stores files at its root, so extract the needed volumes by bare name (flatten
# with -j). Covers the registration model, brain mask, QC outline, and wm/gm/csf priors.
COPY sha256checksum.txt /tmp/
RUN mkdir -p ${MODELDIR} \
    && wget -q https://www.bic.mni.mcgill.ca/~vfonov/icbm/2009/mni_icbm152_nlin_sym_09c_minc2.zip -O /tmp/m.zip \
    && cd /tmp/ \
    && sha256sum -c sha256checksum.txt \
    && unzip -j /tmp/m.zip -d ${MODELDIR} \
         mni_icbm152_t1_tal_nlin_sym_09c.mnc \
         mni_icbm152_t1_tal_nlin_sym_09c_mask.mnc \
         mni_icbm152_t1_tal_nlin_sym_09c_outline.mnc \
         mni_icbm152_wm_tal_nlin_sym_09c.mnc \
         mni_icbm152_gm_tal_nlin_sym_09c.mnc \
         mni_icbm152_csf_tal_nlin_sym_09c.mnc \
    && rm -f /tmp/m.zip

# Copy pipeline scripts
COPY synthstrip_N3.sh /usr/local/bin/synthstrip_N3.sh
RUN chmod +x /usr/local/bin/synthstrip_N3.sh

# Copy configuration files. The script resolves configs relative to its own location
# (${__dir}/configs), so they must sit next to synthstrip_N3.sh in /usr/local/bin.
COPY configs/ /usr/local/bin/configs/

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
