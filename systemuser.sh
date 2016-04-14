#!/bin/sh

# Author: Danilo Piparo, Enric Tejedor 2015
# Copyright CERN
# Here the environment for the notebook server is prepared. Many of the commands are launched as regular 
# user as it's this entity which is able to access eos and not the super user.

# Create notebook user
# The $HOME directory is specified upstream in the Spawner
echo "Creating user $USER ($USER_ID)"
useradd -u $USER_ID -s $SHELL -d $HOME $USER
SCRATCH_HOME=/scratch/$USER
mkdir -p $SCRATCH_HOME
chown $USER:$USER $SCRATCH_HOME

# Setup the LCG View on CVMFS
echo "Setting up environment from CVMFS"
export LCG_VIEW=$ROOT_LCG_VIEW_PATH/$ROOT_LCG_VIEW_NAME/$ROOT_LCG_VIEW_PLATFORM
source $LCG_VIEW/setup.sh
echo "Using the following environment:"
echo "PYTHONPATH: $PYTHONPATH"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "PATH: $PATH"

# Set up the user environment, if any
export TMP_SCRIPT=`sudo -u $USER mktemp`
sudo -E -u $USER sh -c 'if [ -f "$USER_ENV_SCRIPT" ]; \
                        then \
                          echo "Found user script: $USER_ENV_SCRIPT"; \
                          cat $USER_ENV_SCRIPT > $TMP_SCRIPT; \
                        fi'
source $TMP_SCRIPT

# Add ROOT kernel
echo "Adding ROOT kernel"
ETC_NB=$LCG_VIEW/etc/notebook
JPY_LOCAL_DIR=$SCRATCH_HOME/.local
KERNEL_DIR=$JPY_LOCAL_DIR/share/jupyter/kernels
mkdir -p $KERNEL_DIR
cp -rL $ETC_NB/kernels/root $KERNEL_DIR
chown -R $USER:$USER $JPY_LOCAL_DIR

# Set environment for the notebook process
# The kernels and the terminal will inherit
echo "Setting environment"
JPY_DIR=$SCRATCH_HOME/.jupyter
mkdir -p $JPY_DIR
JPY_CONFIG=$JPY_DIR/jupyter_notebook_config.py
export JUPYTER_CONFIG_DIR=$JPY_DIR
export JUPYTER_PATH=$JPY_LOCAL_DIR/share/jupyter
export JUPYTER_DATA_DIR=$JUPYTER_PATH
export JUPYTER_RUNTIME_DIR=$JPY_LOCAL_DIR/share/jupyter/runtime
export IPYTHONDIR=$SCRATCH_HOME/.ipython
echo "import os"                                                              > $JPY_CONFIG
echo "os.environ['PATH']               = '$PATH'"                            >> $JPY_CONFIG
echo "os.environ['LD_LIBRARY_PATH']    = '$LD_LIBRARY_PATH'"                 >> $JPY_CONFIG
echo "os.environ['PYTHONPATH']         = '$PYTHONPATH'"                      >> $JPY_CONFIG
echo "c.FileCheckpoints.checkpoint_dir = '$SCRATCH_HOME/.ipynb_checkpoints'" >> $JPY_CONFIG
chown -R $USER:$USER $JPY_DIR

# Overwrite link for python2 in the image
echo "Link Python"
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
  --hub-api-url=$JPY_HUB_API_URL'
