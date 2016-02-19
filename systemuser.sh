#!/bin/sh

# Author: Danilo Piparo, Enric Tejedor 2015
# Copyright CERN
# Here the environment for the notebook server is prepared. Many of the commands are launched as regular 
# user as it's this entity which is able to access eos and not the super user.

# Create notebook user
# The $HOME directory is specified upstream in the Spawner
echo "Creating user $USER ($USER_ID)"
useradd -u $USER_ID -s $SHELL -d $HOME $USER

# Setup the LCG View on CVMFS
echo "Setting up environment from CVMFS"
export LCG_VIEW=$ROOT_LCG_VIEW_PATH/$ROOT_LCG_VIEW_NAME/$ROOT_LCG_VIEW_PLATFORM

# Add ROOT kernel
echo "Adding ROOT kernel"
export ETC_NB=$LCG_VIEW/etc/notebook
JPY_LOCAL_DIR="$HOME"/.local
export KERNEL_DIR=$JPY_LOCAL_DIR/share/jupyter/kernels
sudo -E -u $USER mkdir -p $KERNEL_DIR
sudo -E -u $USER cp -rL $ETC_NB/kernels/root $KERNEL_DIR

# Customise look and feel
echo "Customising the look and feel"
export JPY_DIR="$HOME"/.jupyter
sudo -E -u $USER mkdir -p $JPY_DIR
sudo -E -u $USER cp -rL $ETC_NB/custom $JPY_DIR

# Set environment for the notebook process
# The kernels and the terminal will inherit
echo "Setting environment"
export JPY_CONFIG=$JPY_DIR/jupyter_notebook_config.py
sudo -E -u $USER sh -c 'source $LCG_VIEW/setup.sh && echo "import os"                 >  $JPY_CONFIG ; \
                        echo "os.environ[\"PATH\"]            = \"$PATH\""            >> $JPY_CONFIG ; \
                        echo "os.environ[\"LD_LIBRARY_PATH\"] = \"$LD_LIBRARY_PATH\"" >> $JPY_CONFIG ; \
                        echo "os.environ[\"PYTHONPATH\"]      = \"$PYTHONPATH\""      >> $JPY_CONFIG ;'

# Overwrite link for python2 in the image
ln -sf $LCG_VIEW/bin/python /usr/local/bin/python2

# Run notebook server
echo "Running the notebook server"
sudo -E -u $USER sh -c 'cd $HOME && jupyterhub-singleuser \
  --port=8888 \
  --ip=0.0.0.0 \
  --user=$JPY_USER \
  --cookie-name=$JPY_COOKIE_NAME \
  --base-url=$JPY_BASE_URL \
  --hub-prefix=$JPY_HUB_PREFIX \
  --hub-api-url=$JPY_HUB_API_URL '
