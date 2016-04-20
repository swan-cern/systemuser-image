
# Analogous to jupyter/systemuser, but based on CC7 and inheriting directly from cernphsft/notebook.
# Run with the DockerSpawner in JupyterHub.

FROM cernphsft/notebook:v2.1

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
RUN pip2 install requests
RUN pip3 install requests

# Install metakernel - required by ROOT C++ kernel
RUN pip2 install metakernel

# Install tk - required by matplotlib
RUN yum -y install tk

# Get jupyterhub-singleuser entrypoint
# from https://github.com/jupyter/dockerspawner/commit/7dfda9473c1f2aebaf6e95b61e1304a2eb88de0b
RUN wget -q https://raw.githubusercontent.com/jupyter/jupyterhub/master/scripts/jupyterhub-singleuser -O /usr/local/bin/jupyterhub-singleuser
RUN chmod 755 /usr/local/bin/jupyterhub-singleuser

# WORKAROUND
# Hide from Jupyter the Python3 kernel by hand
RUN mv /usr/local/lib/python3.5/site-packages/ipykernel /usr/local/lib/python3.5/site-packages/ipykernelBACKUP
RUN rm -rf /usr/local/share/jupyter/kernels/python3

EXPOSE 8888

ENV SHELL /bin/bash

ADD systemuser.sh /srv/singleuser/systemuser.sh
WORKDIR /root
CMD ["sh", "/srv/singleuser/systemuser.sh"]
