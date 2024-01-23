# Analogous to jupyter/systemuser, but based on CC7 and inheriting directly from cernphsft/notebook.
# Run with the DockerSpawner in JupyterHub.

FROM gitlab-registry.cern.ch/swan/docker-images/notebook:v8.0.1

LABEL maintainer="swan-admins@cern.ch"

ARG BUILD_TAG=daily
ENV VERSION_DOCKER_IMAGE=$BUILD_TAG

RUN echo "Building systemuser image with tag ${VERSION_DOCKER_IMAGE}"

# Disable requiretty and secure path - required by systemuser.sh
RUN yum -y install sudo && \
    sed -i'' '/Defaults \+requiretty/d'  /etc/sudoers && \
    sed -i'' '/Defaults \+secure_path/d' /etc/sudoers

# Install ROOT prerequisites
RUN yum -y install \
    libXpm \
    libXft

# Install bs4 - required by hdfsbrowser
RUN pip3 install bs4

# Install tk - required by matplotlib
RUN yum -y install tk

# Install htop
RUN yum -y install htop

# Install Cloudera dependencies - required by IT Spark clusters
RUN yum -y  install \
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
RUN yum -y install cern-get-sso-cookie && \
    yum -y update CERN-CA-certs

# Install grid certificates
RUN echo $'[carepo]\n\
name=IGTF CA Repository\n\
baseurl=http://linuxsoft.cern.ch/mirror/repository.egi.eu/sw/production/cas/1/current/\n\
enabled=1\n\
gpgcheck=0' > /etc/yum.repos.d/carepo.repo && \
    yum install -y \
        ca_DigiCertAssuredIDRootCA-Root \
        ca_USERTrustRSACertificationAuthority \
        ca_DigiCertGridRootCA-Root \
        ca_CERN-Root-2 \
        ca_QuoVadis-Root-CA2G3 \
        ca_COMODO-RSA-CA \
        ca_CESNET-CA-Root \
        ca_UKeScienceRoot-2007 \
        ca_QuoVadis-Root-CA3G3 \
        ca_KENETROOTCA \
        ca_KENETCA-ICA-2015 \
        ca_UKeScienceCA-2B \
        ca_CESNET-CA-4 \
        ca_InCommon-IGTF-Server-CA \
        ca_CERN-GridCA \
        ca_DigiCertGridCA-1G2-Classic-2015 \
        ca_GEANTeScienceSSLCA4 \
        ca_GEANTeSciencePersonalCA4 \
        ca_DigiCertGridTrustCAG2-Classic \
        ca_TERENAeSciencePersonalCA3 \
        ca_TERENA-eScience-SSL-CA-3 \
        ca_IHEP-2013 \
        ca_PKIUNAMgrid \
        ca_HKU-CA-2 \
        ca_GridCanada \
        ca_ANSPGrid \
        ca_CNIC \
        ca_UNLPGrid \
        ca_NIKHEF \
        ca_MARGI \
        ca_KEK \
        ca_DCAROOT-G1 \
        ca_IGCA2 \
        ca_HPCI \
        ca_KISTIv3 \
        ca_seegrid-ca-2013 \
        ca_MaGrid \
        ca_BYGCA \
        ca_NorduGrid-2015 \
        ca_PolishGrid-2019 \
        ca_AC-GRID-FR-Services \
        ca_BG-ACAD-CA \
        ca_AC-GRID-FR \
        ca_TRGrid \
        ca_REUNA-ca \
        ca_RDIG \
        ca_UGRID-G2 \
        ca_cilogon-silver \
        ca_QuoVadis-Root-CA2 \
        ca_SlovakGrid \
        ca_QuoVadis-Grid-ICA-G2 \
        ca_SiGNET-CA \
        ca_MREN-CA \
        ca_SDG-G2 \
        ca_UNAMgrid-ca \
        ca_ArmeSFo \
        ca_LIPCA \
        ca_HellasGrid-CA-2016 \
        ca_PK-Grid-2007 \
        ca_DFN-GridGermany-Root \
        ca_AC-GRID-FR-Robots \
        ca_AC-GRID-FR-Personnels \
        ca_RomanianGRID \
        ca_IRAN-GRID-GCG-G2 \
        ca_SRCE \
        ca_ASGCCA-2007 \
        ca_AEGIS \
        ca_TSU-GE \
        ca_DZeScience \
        ca-policy-egi-core

# Install VOMS
RUN yum install -y voms-clients-java voms-clients-cpp  fetch-crl globus-gsi-sysconfig

ADD etc/vomses /etc/vomses
ADD etc/grid-security/vomsdir /etc/grid-security/vomsdir

# Create truststore for NXCALS Spark connection
RUN yum -y install java-1.8.0-openjdk && \
    keytool -import -alias cernbundle -file /etc/pki/tls/certs/CERN-bundle.crt \
        -keystore /etc/pki/tls/certs/truststore.jks -storepass 'password' -noprompt && \
    yum -y erase java-1.8.0-openjdk && \
    rm -rf /usr/lib/jvm/

# Install HEP_OSlibs - includes atlas blas
RUN yum -y install https://linuxsoft.cern.ch/wlcg/centos7/x86_64/wlcg-repo-1.0.0-1.el7.noarch.rpm
RUN yum -y install HEP_OSlibs-7.3.1-2.el7.cern

# Install package required for key4hep
RUN yum -y install environment-modules 

# HTCondor Requirement
RUN yum install -y perl-Archive-Tar
ADD etc/krb5.conf.no_rdns  /etc/krb5.conf.no_rdns

# WORKAROUND
# Hide from Jupyter the Python3 kernel by hand
RUN mv /usr/local/lib/python3.9/site-packages/ipykernel /usr/local/lib/python3.9/site-packages/ipykernelBACKUP && \
    mv /usr/local/share/jupyter/kernels /usr/local/share/jupyter/kernelsBACKUP

# Required by jupyter-resource-usage
RUN pip install psutil==5.8.0

# Required by dask-labextension
# Jupyter server proxy: we need a commit that is not in 1.6.0 to allow empty PUT body in request
RUN git clone -b v1.6.0 https://github.com/jupyterhub/jupyter-server-proxy.git /tmp/jupyter-server-proxy && \
    cd /tmp/jupyter-server-proxy && \
    git cherry-pick -n e2481b52bdd31865a8fc1cce762a9a12e8846fd9 && \
    pip install --no-cache-dir /tmp/jupyter-server-proxy && \
    rm -rf /tmp/jupyter-server-proxy
RUN pip install simpervisor==0.4

# Install all of our extensions
# Ignore (almost all) dependencies because they have already been installed or come from CVMFS
RUN pip install --no-deps --no-cache-dir \
            dask-labextension==6.1.0 \
            jupyter-resource-usage==0.6.0 \
            hdfsbrowser==1.1.1 \
            sparkconnector==2.4.7 \
            sparkmonitor==2.1.1 \
            swancontents==2.1.4 \
            swanhelp==2.0.2 \
            swanintro==1.0.0 \
            swankernelenv==1.0.0 \
            swannotebookviewer==1.2.0 \
            swannotifications==1.0.0 \
            swanoauthrenew==1.0.1 PyJWT \
            swanshare==1.1.1 \
            swanheader==1.0.0 \
            swanportallocator==1.0.1
# swandask must be installed after its dependency dask-labextension to disable the server extension automatically
RUN pip install --no-deps --no-cache-dir swandask==0.0.3

# Enable all the nbextensions and server extensions
RUN jupyter nbextension install --py --system hdfsbrowser && \
    jupyter nbextension install --py --system sparkconnector && \
    jupyter nbextension install --py --system sparkmonitor && \
    jupyter nbextension enable --py --system sparkmonitor && \
    jupyter nbextension install --py --system swancontents && \
    jupyter serverextension enable --py --system swancontents && \
    jupyter nbextension install --py --system swanhelp && \
    jupyter nbextension enable --py --system swanhelp && \
    jupyter nbextension install --py --system swanintro && \
    jupyter nbextension enable --py --system swanintro && \
    jupyter serverextension enable --py --system swannotebookviewer && \
    jupyter nbextension install --py --system swannotifications && \
    jupyter nbextension enable --py --system swannotifications && \
    jupyter serverextension enable --py --system swanoauthrenew && \
    jupyter nbextension install --py --system swanshare && \
    jupyter nbextension enable --py --system swanshare && \
    jupyter serverextension enable --py --system swanshare && \
    jupyter serverextension enable --py --system swanportallocator && \
    # Force nbextension_configurator systemwide to prevent users disabling it
    jupyter nbextensions_configurator enable --system && \
    # Spark Monitor/Connector also need to be available to the user environment since they have kernel extensions
    # PortAllocator is used by SparkConnector, so it needs to be available too
    mkdir -p /usr/local/lib/swan/extensions && \
    ln -s /usr/local/lib/python3.9/site-packages/sparkmonitor /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.9/site-packages/sparkconnector /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.9/site-packages/swankernelenv /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.9/site-packages/swanportallocator /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.9/site-packages/dask_labextension /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.9/site-packages/jupyter_server_proxy /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.9/site-packages/simpervisor /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.9/site-packages/swandask /usr/local/lib/swan/extensions/ && \
    # FIXME workaround for templates. For some reason, and only in our image, Jupyter is looking for templates inside templates
    cp -r /usr/local/lib/python3.9/site-packages/swancontents/templates{,2} && \
    mv /usr/local/lib/python3.9/site-packages/swancontents/templates{2,/templates}

# Configure Dask
ENV DASK_DIR /srv/dask
RUN mkdir -p ${DASK_DIR}
ENV DASK_LIB_DIR ${DASK_DIR}/lib
# Install swandaskcluster in its own lib dir so that we can add it individually
# to the PYTHONPATH of notebooks and terminals, which need it to do automatic
# TLS configuration for Dask clients
RUN pip install --no-deps --no-cache-dir --target ${DASK_LIB_DIR} \
        swandaskcluster==2.0.1
# Dependency of swandaskcluster
RUN ln -s /usr/local/lib/python3.9/site-packages/swanportallocator ${DASK_LIB_DIR}

# Toughen the krb ciphers to prevent failures when combining with Alma 9 environments (i.e the eosxd pod)
RUN sed -i "s/default_tkt_enctypes.*/default_tkt_enctypes = aes256-cts aes128-cts des3-cbc-sha1 des-cbc-md5 des-cbc-crc arcfour-hmac-md5/g" /etc/krb5.conf

RUN yum clean all && \
    rm -rf /var/cache/yum

EXPOSE 8888

ENV SHELL /bin/bash


ADD systemuser.sh /srv/singleuser/systemuser.sh
ADD userconfig.sh /srv/singleuser/userconfig.sh
ADD create_dask_certs.sh /srv/singleuser/create_dask_certs.sh
ADD configure_kernels_and_terminal.py /srv/singleuser/configure_kernels_and_terminal.py
ADD executables/start_ipykernel.py /usr/local/bin/start_ipykernel.py
RUN chmod 705 /usr/local/bin/start_ipykernel.py

# TEMPORARY: apply a patch to the auth file while we wait for the release of a new version with it
ADD log_patch.diff /tmp/log_patch.diff
RUN patch /usr/local/lib/python3.9/site-packages/jupyterhub/services/auth.py /tmp/log_patch.diff && \
    rm -f /tmp/log_patch.diff

WORKDIR /root
CMD ["sh", "/srv/singleuser/systemuser.sh"]
