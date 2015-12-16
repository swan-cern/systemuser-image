#!/bin/sh

echo "Creating user $USER ($USER_ID)"
#useraddcern $USER
useradd -u $USER_ID -s $SHELL $USER

echo "Linking to the CERNBox"
FIRSTLETTER="$(echo $USER | head -c 1)"
LONGNAME=/home/"$USER"/MyCERNBox
ln -nfs /eos/user/"$FIRSTLETTER"/"$USER" $LONGNAME
chown -h $USER $LONGNAME

echo "Setting up environment from CVMFS"
SETUP_FILE=$ROOT_LCG_VIEW_PATH/$ROOT_LCG_VIEW_NAME/$ROOT_LCG_VIEW_PLATFORM/setup.sh
source $SETUP_FILE
echo "Using setup file: $SETUP_FILE"
env

# Force inheritance of PYTHONPATH and LD_LIBRARY_PATH
alias sudoenv="sudo LD_LIBRARY_PATH=$LD_LIBRARY_PATH PYTHONPATH=$PYTHONPATH"

sudoenv -E -u $USER jupyterhub-singleuser \
  --port=8888 \
  --ip=0.0.0.0 \
  --user=$JPY_USER \
  --cookie-name=$JPY_COOKIE_NAME \
  --base-url=$JPY_BASE_URL \
  --hub-prefix=$JPY_HUB_PREFIX \
  --hub-api-url=$JPY_HUB_API_URL
