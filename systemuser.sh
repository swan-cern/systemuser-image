#!/bin/sh

# Create notebook user
echo "Creating user $USER ($USER_ID)"
useradd -u $USER_ID -s $SHELL $USER

# Setup CERNBox
echo "Setting up CERNBox"
FIRSTLETTER="$(echo $USER | head -c 1)"
cd ..
mv $USER "$USER"_BACKUP
# at this point the permissions should be ok
# We copy the temporary directories into the CERNBox which we make our HOME
ln -nfs /eos/user/"$FIRSTLETTER"/"$USER" $USER
chown -h $USER:$USER $USER
cd $USER
MYHOME=/home/"$USER"

#FIRSTLETTER="$(echo $USER | head -c 1)"
#LONGNAME=/home/"$USER"/MyCERNBox
#ln -nfs /eos/user/"$FIRSTLETTER"/"$USER" $LONGNAME
#chown -h $USER:$USER $LONGNAME

# Setup CVMFS
echo "Setting up environment from CVMFS"
LCG_VIEW=$ROOT_LCG_VIEW_PATH/$ROOT_LCG_VIEW_NAME/$ROOT_LCG_VIEW_PLATFORM
source $LCG_VIEW/setup.sh

# Add ROOT kernel
echo "Adding ROOT kernel"
ETC_NB=$LCG_VIEW/etc/notebook
JPY_LOCAL_DIR="$MYHOME"/.local
KERNEL_DIR=$JPY_LOCAL_DIR/share/jupyter/kernels
mkdir -p $KERNEL_DIR
cp -r $ETC_NB/kernels/root $KERNEL_DIR
chown -R $USER:$USER $JPY_LOCAL_DIR

# Customise look and feel
echo "Customising the look and feel"
JPY_DIR="$MYHOME"/.jupyter
mkdir $JPY_DIR
cp -r $ETC_NB/custom $JPY_DIR

# Set environment for the notebook process
# The kernels and the terminal will inherit
echo "Setting environment"
JPY_CONFIG=$JPY_DIR/jupyter_notebook_config.py
echo "import os"                                           > $JPY_CONFIG
echo "os.environ['PATH']            = '$PATH'"            >> $JPY_CONFIG
echo "os.environ['LD_LIBRARY_PATH'] = '$LD_LIBRARY_PATH'" >> $JPY_CONFIG
echo "os.environ['PYTHONPATH']      = '$PYTHONPATH'"      >> $JPY_CONFIG
chown -R $USER:$USER $JPY_DIR

# Overwrite link for python2 in the image
ln -sf $LCG_VIEW/bin/python /usr/local/bin/python2

# Run notebook server
echo "Running the notebook server"
sudo -E -u $USER jupyterhub-singleuser \
  --port=8888 \
  --ip=0.0.0.0 \
  --user=$JPY_USER \
  --cookie-name=$JPY_COOKIE_NAME \
  --base-url=$JPY_BASE_URL \
  --hub-prefix=$JPY_HUB_PREFIX \
  --hub-api-url=$JPY_HUB_API_URL
