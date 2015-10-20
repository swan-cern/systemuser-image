
# Analogous to jupyter/systemuser, but based on CC7 and inheriting directly from cernphsft/notebook.
# Run with the DockerSpawner in JupyterHub.

FROM cernphsft/notebook

MAINTAINER Enric Tejedor Saavedra <enric.tejedor.saavedra@cern.ch>

# Install sudo, disable requiretty and secure path - required by systemuser.sh
RUN yum -y install sudo
RUN sed -i'' '/Defaults \+requiretty/d'  /etc/sudoers
RUN sed -i'' '/Defaults \+secure_path/d' /etc/sudoers

# Get jupyterhub-singleuser entrypoint
ADD https://raw.githubusercontent.com/jupyter/jupyterhub/master/jupyterhub/singleuser.py /usr/local/bin/jupyterhub-singleuser
RUN chmod 755 /usr/local/bin/jupyterhub-singleuser

EXPOSE 8888

ENV SHELL /bin/bash

ADD systemuser.sh /srv/singleuser/systemuser.sh
CMD ["sh", "/srv/singleuser/systemuser.sh"]
