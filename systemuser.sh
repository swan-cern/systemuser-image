#!/bin/sh

# Setup CERNBox
#echo "Entering EOS home (CERNBox)"
#FIRSTLETTER="$(echo $USER | head -c 1)"
#MYHOME=/eos/user/"$FIRSTLETTER"/"$USER"

# Create notebook user
echo "Creating user $USER ($USER_ID)"
useradd -u $USER_ID -s $SHELL -d $HOME $USER

# Setup CVMFS
echo "Setting up environment from CVMFS"
LCG_VIEW=$ROOT_LCG_VIEW_PATH/$ROOT_LCG_VIEW_NAME/$ROOT_LCG_VIEW_PLATFORM
source $LCG_VIEW/setup.sh

# Add ROOT kernel
echo "Adding ROOT kernel"
ETC_NB=$LCG_VIEW/etc/notebook
JPY_LOCAL_DIR="$HOME"/.local
KERNEL_DIR=$JPY_LOCAL_DIR/share/jupyter/kernels
sudo -E -u $USER mkdir -p $KERNEL_DIR
sudo -E -u $USER cp -rL $ETC_NB/kernels/root $KERNEL_DIR
chown -R $USER:$USER $JPY_LOCAL_DIR

# Customise look and feel
echo "Customising the look and feel"
JPY_DIR="$HOME"/.jupyter
sudo -E -u $USER mkdir $JPY_DIR
sudo -E -u $USER cp -rL $ETC_NB/custom $JPY_DIR

# Set environment for the notebook process
# The kernels and the terminal will inherit
echo "Setting environment"
JPY_CONFIG=$JPY_DIR/jupyter_notebook_config.py
sudo -E -u $USER sh -c 'echo "import os"                                               > $JPY_CONFIG'
sudo -E -u $USER sh -c 'echo "os.environ[\"PATH\"]            = \"$PATH\""            >> $JPY_CONFIG'
sudo -E -u $USER sh -c 'echo "os.environ[\"LD_LIBRARY_PATH\"] = \"$LD_LIBRARY_PATH\"" >> $JPY_CONFIG'
sudo -E -u $USER sh -c 'echo "os.environ[\"PYTHONPATH\"]      = \"$PYTHONPATH\""      >> $JPY_CONFIG'
chown -R $USER:$USER $JPY_DIR

# Overwrite link for python2 in the image
ln -sf $LCG_VIEW/bin/python /usr/local/bin/python2

# Run notebook server
echo "Running the notebook server"
sudo -E -u $USER sh -c 'cd $MYHOME && jupyterhub-singleuser \
  --port=8888 \
  --ip=0.0.0.0 \
  --user=$JPY_USER \
  --cookie-name=$JPY_COOKIE_NAME \
  --base-url=$JPY_BASE_URL \
  --hub-prefix=$JPY_HUB_PREFIX \
  --hub-api-url=$JPY_HUB_API_URL '
