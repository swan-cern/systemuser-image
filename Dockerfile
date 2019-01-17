# Analogous to jupyter/systemuser, but based on CC7 and inheriting directly from cernphsft/notebook.
# Run with the DockerSpawner in JupyterHub.

FROM gitlab-registry.cern.ch/swan/docker-images/notebook:v4.0.0

MAINTAINER SWAN Admins <swan-admins@cern.ch>

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
gpgcheck=0' > /etc/yum.repos.d/ca.repo && \
    yum install -y voms-clients-cpp  fetch-crl ca_CERN-GridCA-1.90-1.noarch

# Create truststore for NXCALS Spark connection
RUN yum -y install java-1.8.0-openjdk && \
    keytool -import -alias cerngridCA -file /etc/pki/tls/certs/CERN_Grid_Certification_Authority.crt \
        -keystore /etc/pki/tls/certs/truststore.jks -storepass 'password' -noprompt && \
    keytool -import -alias cernRootCA2 -file /etc/pki/tls/certs/CERN_Root_Certification_Authority_2.crt \
        -keystore /etc/pki/tls/certs/truststore.jks -storepass 'password' -noprompt && \
    yum -y erase java-1.8.0-openjdk && \
    rm -rf /usr/lib/jvm/

# Install HEP_OSlibs - includes atlas blas
RUN yum -y install HEP_OSlibs

# WORKAROUND
# Hide from Jupyter the Python3 kernel by hand
RUN mv /usr/local/lib/python3.6/site-packages/ipykernel /usr/local/lib/python3.6/site-packages/ipykernelBACKUP && \
    mv /usr/local/share/jupyter/kernels /usr/local/share/jupyter/kernelsBACKUP

# Add ipykernel and its dependencies to an isolated place referenced by PYTHONPATH in user env (Py3)
# Needed to prevent updated Jupyter code to break with older LCG versions (this way it picks always the correct pkgs)
RUN mkdir /usr/local/lib/swan && \
    pip3 install 'ipykernel==4.8.2' -t /usr/local/lib/swan

# !!!!! Replace with the zip file from gitlab repo
ADD v7 /tmp/jupyter_extensions/
RUN cd /tmp/jupyter_extensions && \
    #unzip latest.zip && \
    rm -rf /usr/local/lib/python3.6/site-packages/notebook/templates && \
    mv -f templates /usr/local/lib/python3.6/site-packages/notebook/ && \
    # Install all SWAN extensions which are packaged as python modules
    # Ignore dependencies because they have already been installed or come from CVMFS
    ls -d ./*/ | xargs -n1 sh -c 'cd $0 ; pip install --no-deps .' && \
    # Automatically install all nbextensions from their python module (all extensions need to implement the api even if they return 0 nbextensions)
    ls -d ./*/ | xargs -n1 sh -c 'extension=$(basename $0) ; jupyter nbextension install --py --system ${extension,,} || exit 1' && \
    # Enable the server extensions
    server_extensions=('swancontents' 'sparkmonitor' 'swannotebookviewer' 'swangallery') && \
    for extension in ${server_extensions[@]}; do jupyter serverextension enable --py --system $extension || exit 1 ; done && \
    # Enable the nb extensions
    # Not all nbextensions are activated as some of them are activated on session startup or by the import in the templates
    nb_extensions=('swanhelp' 'swannotifications' 'swanshare' 'swanintro' 'sparkmonitor') && \
    for extension in ${nb_extensions[@]}; do jupyter nbextension enable --py --system $extension || exit 1; done && \
    # Force nbextension_configurator systemwide to prevent users disabling it
    jupyter nbextensions_configurator enable --system && \
    # Spark Monitor/Connector also need to be available to the user environment since they have kernel extensions
    mkdir /usr/local/lib/swan/extensions && \
    ln -s /usr/local/lib/python3.6/site-packages/sparkmonitor /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.6/site-packages/sparkconnector /usr/local/lib/swan/extensions/ && \
    ln -s /usr/local/lib/python3.6/site-packages/swankernelenv /usr/local/lib/swan/extensions/ && \
    # Clean
    rm -rf /tmp/jupyter_extensions

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
