# Analogous to jupyter/systemuser, but based on CC7 and inheriting directly from cernphsft/notebook.
# Run with the DockerSpawner in JupyterHub.

FROM gitlab-registry.cern.ch/swan/docker-images/notebook:v7.1.0

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

# Install bs4 - required by sparkconnector.serverextension
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
        ca_CNRS2 \
        ca_CNRS2-Projets \
        ca_QuoVadis-Root-CA2G3 \
        ca_COMODO-RSA-CA \
        ca_CESNET-CA-Root \
        ca_UKeScienceRoot-2007 \
        ca_QuoVadis-Root-CA3G3 \
        ca_DarkMatterPrivateRootCAG4 \
        ca_KENETROOTCA \
        ca_KENETCA-ICA-2015 \
        ca_DarkMatterIGTFCA \
        ca_DarkMatterAssuredCA \
        ca_UKeScienceCA-2B \
        ca_CESNET-CA-4 \
        ca_InCommon-IGTF-Server-CA \
        ca_DarkMatterSecureCA \
        ca_CNRS2-Grid-FR \
        ca_CERN-GridCA \
        ca_DigiCertGridCA-1G2-Classic-2015 \
        ca_DigiCertGridCA-1-Classic \
        ca_GEANTeScienceSSLCA4 \
        ca_GEANTeSciencePersonalCA4 \
        ca_DigiCertGridTrustCA-Classic \
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
        ca_NCSA-slcs-2013 \
        ca_INFN-CA-2015 \
        ca_KEK \
        ca_DCAROOT-G1 \
        ca_IGCA2 \
        ca_HPCI \
        ca_KISTIv3 \
        ca_seegrid-ca-2013 \
        ca_MaGrid \
        ca_BYGCA \
        ca_NorduGrid-2015 \
        ca_PolishGrid \
        ca_PolishGrid-2019 \
        ca_AC-GRID-FR-Services \
        ca_QuoVadis-Root-CA1 \
        ca_BG-ACAD-CA \
        ca_AC-GRID-FR \
        ca_MYIFAM \
        ca_TRGrid \
        ca_REUNA-ca \
        ca_RDIG \
        ca_UGRID-G2 \
        ca_cilogon-silver \
        ca_MD-Grid-CA-T \
        ca_QuoVadis-Root-CA2 \
        ca_SlovakGrid \
        ca_QuoVadis-Grid-ICA-G2 \
        ca_SiGNET-CA \
        ca_MREN-CA \
        ca_SDG-G2 \
        ca_PSC-Myproxy-CA \
        ca_UNAMgrid-ca \
        ca_ArmeSFo \
        ca_GermanGrid \
        ca_LIPCA \
        ca_HellasGrid-CA-2016 \
        ca_PK-Grid-2007 \
        ca_DFN-GridGermany-Root \
        ca_AC-GRID-FR-Robots \
        ca_AC-GRID-FR-Personnels \
        ca_NIIF-Root-CA-2 \
        ca_RomanianGRID \
        ca_IRAN-GRID-GCG-G2 \
        ca_SRCE \
        ca_ASGCCA-2007 \
        ca_NERSC-SLCS \
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
    keytool -import -alias cerngridCA -file /etc/pki/tls/certs/CERN_Grid_Certification_Authority.crt \
        -keystore /etc/pki/tls/certs/truststore.jks -storepass 'password' -noprompt && \
    keytool -import -alias cernRootCA2 -file /etc/pki/tls/certs/CERN_Root_Certification_Authority_2.crt \
        -keystore /etc/pki/tls/certs/truststore.jks -storepass 'password' -noprompt && \
    yum -y erase java-1.8.0-openjdk && \
    rm -rf /usr/lib/jvm/

# Install HEP_OSlibs - includes atlas blas
RUN yum -y install HEP_OSlibs-7.2.7-1.el7.cern

# Install package required for key4hep
RUN yum -y install environment-modules 

# WORKAROUND
# Hide from Jupyter the Python3 kernel by hand
RUN mv /usr/local/lib/python3.7/site-packages/ipykernel /usr/local/lib/python3.7/site-packages/ipykernelBACKUP && \
    mv /usr/local/share/jupyter/kernels /usr/local/share/jupyter/kernelsBACKUP

# Install all of our extensions
# Ignore (almost all) dependencies because they have already been installed or come from CVMFS
RUN pip install --no-deps \
            hdfsbrowser==1.0.0 \
            sparkconnector==1.0.0 \
            sparkmonitor==1.1.1 \
            swancontents==1.2.0 \
            swanhelp==1.0.0 \
            swanintro==1.0.0 \
            swankernelenv==1.0.0 \
            swannotebookviewer==1.1.0 \
            swannotifications==1.0.0 \
            swanoauthrenew==1.0.1 PyJWT \
            swanshare==1.1.1 && \
    # Enable all the nbextensions and server extensions
    jupyter nbextension install --py --system hdfsbrowser && \
    jupyter nbextension install --py --system sparkconnector && \
    jupyter nbextension install --py --system sparkmonitor && \
    jupyter nbextension enable --py --system sparkmonitor && \
    jupyter serverextension enable --py --system sparkmonitor && \
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
    # Build Jupyterlab to enable the installed lab extensions
    jupyter lab build && \
    # Force nbextension_configurator systemwide to prevent users disabling it
    jupyter nbextensions_configurator enable --system && \
    # Spark Monitor/Connector also need to be available to the user environment since they have kernel extensions
    mkdir -p /usr/local/lib/swan/extensions && \
    ln -s /usr/local/lib/python3.7/site-packages/sparkmonitor /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.7/site-packages/sparkconnector /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.7/site-packages/swankernelenv /usr/local/lib/swan/extensions/ && \
    # FIXME workaround for templates. For some reason, and only in our image, Jupyter is looking for templates inside templates
    cp -r /usr/local/lib/python3.7/site-packages/swancontents/templates{,2} && \
    mv /usr/local/lib/python3.7/site-packages/swancontents/templates{2,/templates}

RUN yum clean all && \
    rm -rf /var/cache/yum

EXPOSE 8888

ENV SHELL /bin/bash


ADD systemuser.sh /srv/singleuser/systemuser.sh
ADD userconfig.sh /srv/singleuser/userconfig.sh
ADD executables/start_ipykernel.py /usr/local/bin/start_ipykernel.py
ADD executables/jupyterhub-singleuser /usr/local/bin/jupyterhub-singleuser
RUN chmod 705 /usr/local/bin/start_ipykernel.py && \
    chmod 705 /usr/local/bin/jupyterhub-singleuser

WORKDIR /root
CMD ["sh", "/srv/singleuser/systemuser.sh"]
