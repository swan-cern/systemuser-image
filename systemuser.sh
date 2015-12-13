#!/bin/sh

echo "Creating user $USER ($USER_ID)"
#useraddcern $USER
useradd -u $USER_ID -s $SHELL $USER

echo "Linking to the CERNBox"
FIRSTLETTER="$(echo $USER | head -c 1)"
LONGNAME=/home/"$USER"/MyCERNBox
ln -nfs /eos/user/"$FIRSTLETTER"/"$USER" $LONGNAME
chown -h $USER $LONGNAME

sudo -E -u $USER jupyterhub-singleuser \
  --port=8888 \
  --ip=0.0.0.0 \
  --user=$JPY_USER \
  --cookie-name=$JPY_COOKIE_NAME \
  --base-url=$JPY_BASE_URL \
  --hub-prefix=$JPY_HUB_PREFIX \
  --hub-api-url=$JPY_HUB_API_URL
