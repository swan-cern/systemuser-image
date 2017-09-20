
# Analogous to jupyter/systemuser, but based on CC7 and inheriting directly from cernphsft/notebook.
# Run with the DockerSpawner in JupyterHub.

FROM cernphsft/notebook:v2.3

MAINTAINER Enric Tejedor Saavedra <enric.tejedor.saavedra@cern.ch>

# Disable requiretty and secure path - required by systemuser.sh
RUN yum -y install sudo
RUN sed -i'' '/Defaults \+requiretty/d'  /etc/sudoers
RUN sed -i'' '/Defaults \+secure_path/d' /etc/sudoers

# Install ROOT prerequisites
RUN yum -y install \
    libXpm \
    libXft

# Install requests - required by jupyterhub-singleuser
RUN pip3 install requests

# Install tk - required by matplotlib
RUN yum -y install tk

# Install Cloudera dependencies - required by IT Spark clusters
RUN yum -y install \
    alsa-lib \
    at \
    bc \
    cronie \
    cronie-anacron \
    crontabs \
    cvs \
    db4-cxx \
    db4-devel \
    ed \
    file \
    gdbm-devel \
    gettext \
    jpackage-utils \
    libXi \
    libXtst \
    man \
    passwd \
    pax \
    perl-CGI \
    perl-ExtUtils-MakeMaker \
    perl-ExtUtils-ParseXS \
    perl-Test-Harness \
    perl-Test-Simple \
    perl-devel \
    redhat-lsb-core \
    rsyslog \
    time \
    xz \
    xz-lzma-compat

# Install openmotif - required by Geant4 (libXm)
RUN yum -y install openmotif

# Install libaio - required by Oracle
RUN yum -y install libaio

# Install cern-get-sso-cookie and update CERN CA certs - ATLAS TDAQ, UCA-63
RUN yum -y install cern-get-sso-cookie
RUN yum -y update CERN-CA-certs

# Install HEP_OSlibs - includes atlas blas
RUN yum -y install HEP_OSlibs_SL6

# WORKAROUND
# Hide from Jupyter the Python3 kernel by hand
RUN mv /usr/local/lib/python3.6/site-packages/ipykernel /usr/local/lib/python3.6/site-packages/ipykernelBACKUP
RUN mv /usr/local/share/jupyter/kernels /usr/local/share/jupyter/kernelsBACKUP

EXPOSE 8888

ENV SHELL /bin/bash

ADD systemuser.sh /srv/singleuser/systemuser.sh
WORKDIR /root
CMD ["sh", "/srv/singleuser/systemuser.sh"]
