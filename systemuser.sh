#!/bin/sh

# Author: Danilo Piparo, Enric Tejedor 2016
# Copyright CERN
# Here the environment for the notebook server is prepared. Many of the commands are launched as regular 
# user as it's this entity which is able to access eos and not the super user.

# Create notebook user
# The $HOME directory is specified upstream in the Spawner

log_info() {
    echo "[INFO $(date '+%Y-%m-%d %T.%3N') $(basename $0)] $1"
}
log_error() {
    echo "[ERROR $(date '+%Y-%m-%d %T.%3N') $(basename $0)] $1"
}

log_info "Creating user $USER ($USER_ID) with home $HOME"
export SWAN_HOME=$HOME
if [[ $SWAN_HOME == /eos/* ]]; then export CERNBOX_HOME=$SWAN_HOME; fi
useradd -u $USER_ID -s $SHELL -M -d $SWAN_HOME $USER
export SCRATCH_HOME=/scratch/$USER
mkdir -p $SCRATCH_HOME
echo "This directory is temporary and will be deleted when your SWAN session ends!" > $SCRATCH_HOME/IMPORTANT.txt
chown -R $USER:$USER $SCRATCH_HOME

# Store the oAuth token given by the spawner inside a file
# so that EOS can use it
if [[ ! -z "$ACCESS_TOKEN" ]];
then
    log_info "Storing oAuth token for EOS"
    export OAUTH2_FILE=/tmp/eos_oauth.token
    export OAUTH2_TOKEN="FILE:$OAUTH2_FILE"
    echo -n oauth2:$ACCESS_TOKEN:$OAUTH_INSPECTION_ENDPOINT >& $OAUTH2_FILE
    chown -R $USER:$USER $OAUTH2_FILE
    chmod 600 $OAUTH2_FILE
fi

sudo -E -u $USER sh -c 'if [[ ! -d "$SWAN_HOME" || ! -x "$SWAN_HOME" ]]; then exit 1; fi'
if [ $? -ne 0 ]
then
    log_error "Error setting notebook working directory, $SWAN_HOME not accessible by user $USER."
    exit 1
fi

log_info "Setting directory for Notebook backup"
export USERDATA_PATH=/srv/singleuser/userdata
mkdir -p $USERDATA_PATH
chown -R $USER:$USER $USERDATA_PATH

# Setup the LCG View on CVMFS
log_info "Setting up environment from CVMFS"
export LCG_VIEW=$ROOT_LCG_VIEW_PATH/$ROOT_LCG_VIEW_NAME/$ROOT_LCG_VIEW_PLATFORM

# Set environment for the Jupyter process
log_info "Setting Jupyter environment"
export JPY_DIR=$SCRATCH_HOME/.jupyter
mkdir -p $JPY_DIR
JPY_LOCAL_DIR=$SCRATCH_HOME/.local
mkdir -p $JPY_LOCAL_DIR
export JUPYTER_CONFIG_DIR=$JPY_DIR
JUPYTER_LOCAL_PATH=$JPY_LOCAL_DIR/share/jupyter
mkdir -p $JUPYTER_LOCAL_PATH
# Our kernels will be in $JUPYTER_LOCAL_PATH
export JUPYTER_PATH=$JUPYTER_LOCAL_PATH
# symlink $LCG_VIEW/share/jupyter/nbextensions for the notebook extensions
ln -s $LCG_VIEW/share/jupyter/nbextensions $JUPYTER_LOCAL_PATH
export KERNEL_DIR=$JUPYTER_LOCAL_PATH/kernels
mkdir -p $KERNEL_DIR
export JUPYTER_RUNTIME_DIR=$JUPYTER_LOCAL_PATH/runtime
export IPYTHONDIR=$SCRATCH_HOME/.ipython
mkdir -p $IPYTHONDIR
export PROFILEPATH=$IPYTHONDIR/profile_default
mkdir -p $PROFILEPATH
# This avoids to create hardlinks on eos when using pip
export XDG_CACHE_HOME=/tmp/$USER/.cache/
#Creating a ROOT_DATA_DIR variable
ROOT_DATA_DIR=$(readlink $LCG_VIEW/bin/root | sed -e 's/\/bin\/root//g')

JPY_CONFIG=$JUPYTER_CONFIG_DIR/jupyter_notebook_config.py
echo "c.FileCheckpoints.checkpoint_dir = '$SCRATCH_HOME/.ipynb_checkpoints'"         >> $JPY_CONFIG
echo "c.NotebookNotary.db_file = '$JUPYTER_LOCAL_PATH/nbsignatures.db'"     >> $JPY_CONFIG
echo "c.NotebookNotary.secret_file = '$JUPYTER_LOCAL_PATH/notebook_secret'" >> $JPY_CONFIG
echo "c.NotebookApp.contents_manager_class = 'swancontents.filemanager.swanfilemanager.SwanFileManager'" >> $JPY_CONFIG
echo "c.ContentsManager.checkpoints_class = 'swancontents.filemanager.checkpoints.EOSCheckpoints'" >> $JPY_CONFIG
echo "c.NotebookApp.default_url = 'projects'" >> $JPY_CONFIG
echo "c.NotebookApp.extra_static_paths = ['$ROOT_DATA_DIR/js']" >> $JPY_CONFIG
echo "from swancontents import get_templates" >> $JPY_CONFIG
echo "c.NotebookApp.extra_template_paths = [get_templates()]" >> $JPY_CONFIG
cp -L -r $LCG_VIEW/etc/jupyter/* $JUPYTER_CONFIG_DIR

# Configure %%cpp cell highlighting
CUSTOM_JS_DIR=$JPY_DIR/custom
mkdir $CUSTOM_JS_DIR
echo "
require(['notebook/js/codecell'], function(codecell) {
  codecell.CodeCell.options_default.highlight_modes['magic_text/x-c++src'] = {'reg':[/^%%cpp/]};
});
" > $CUSTOM_JS_DIR/custom.js

# Configure kernels and terminal
# The environment of the kernels and the terminal will combine the view and the user script (if any)
log_info "Configuring kernels and terminal"
# Python (2 or 3)
if [ -f $LCG_VIEW/bin/python3 ]; then export PYVERSION=3; else export PYVERSION=2; fi
PYKERNELDIR=$KERNEL_DIR/python$PYVERSION
mkdir -p $PYKERNELDIR
cp -r /usr/local/share/jupyter/kernelsBACKUP/python3/*.png $PYKERNELDIR
echo "{
 \"display_name\": \"Python $PYVERSION\",
 \"language\": \"python\",
 \"argv\": [
  \"python\",
  \"/usr/local/bin/start_ipykernel.py\",
  \"-f\",
  \"{connection_file}\"
 ]
}" > $PYKERNELDIR/kernel.json
# ROOT
cp -rL $LCG_VIEW/etc/notebook/kernels/root $KERNEL_DIR
# R
cp -rL $LCG_VIEW/share/jupyter/kernels/ir $KERNEL_DIR
sed -i "s/IRkernel::main()/options(bitmapType='cairo');IRkernel::main()/g" $KERNEL_DIR/ir/kernel.json # Force cairo for graphics
# Octave
OCTAVE_KERNEL_PATH=$LCG_VIEW/share/jupyter/kernels/octave
if [[ -d $OCTAVE_KERNEL_PATH ]];
then
   cp -rL $OCTAVE_KERNEL_PATH $KERNEL_DIR
   export OCTAVE_KERNEL_JSON=$KERNEL_DIR/octave/kernel.json
fi

chown -R $USER:$USER $JPY_DIR $JPY_LOCAL_DIR $IPYTHONDIR
export SWAN_ENV_FILE=$SCRATCH_HOME/.bash_profile

sudo -E -u $USER sh /srv/singleuser/userconfig.sh

if [ $? -ne 0 ]
then
  log_error "Error configuring user environment"
  exit 1
fi

START_TIME_CONFIGURE_KERNEL_ENV=$( date +%s.%N )

# Spark configuration
if [[ $SPARK_CLUSTER_NAME ]]
then
  LOCAL_IP=`hostname -i`
  echo "$LOCAL_IP $SERVER_HOSTNAME" >> /etc/hosts

  # Enable the extensions in Jupyter global path to avoid having to maintain this information 
  # in the user scratch json file (specially because now we persist this file in the user directory and
  # we don't want to persist the Spark extensions across sessions)
  mkdir -p /etc/jupyter/nbconfig
  log_info "Globally enabling the Spark extensions"
  echo "{
    \"load_extensions\": {
      \"sparkconnector/extension\": true,
      \"hdfsbrowser/extension\": true
    }
  }" > /etc/jupyter/nbconfig/notebook.json
  echo "{
    \"NotebookApp\": {
      \"nbserver_extensions\": {
        \"sparkconnector.portallocator\": true,
        \"hdfsbrowser.serverextension\": true
      }
    }
  }" > /etc/jupyter/jupyter_notebook_config.json
  if [ $SPARK_CLUSTER_NAME = "k8s" ]
  then
    CLUSTER_NAME="analytix"
  else
    CLUSTER_NAME=$SPARK_CLUSTER_NAME
  fi
  echo "c.HDFSBrowserConfig.hdfs_site_path = '/cvmfs/sft.cern.ch/lcg/etc/hadoop-confext/conf/etc/$CLUSTER_NAME/hadoop.$CLUSTER_NAME/hdfs-site.xml'" >> $JPY_CONFIG
  echo "c.HDFSBrowserConfig.hdfs_site_namenodes_property = 'dfs.ha.namenodes.$CLUSTER_NAME'" >> $JPY_CONFIG
  echo "c.HDFSBrowserConfig.hdfs_site_namenodes_port = '50070'" >> $JPY_CONFIG
fi

# Configurations for extensions (used when deployed outside CERN)
if [[ $SHARE_CBOX_API_DOMAIN && $SHARE_CBOX_API_BASE ]]
then
  echo "{\"sharing\":
    {
      \"domain\": \"$SHARE_CBOX_API_DOMAIN\",
      \"base\": \"$SHARE_CBOX_API_BASE\",
      \"authentication\": \"/authenticate\",
      \"shared\": \"/sharing\",
      \"shared_with_me\": \"/shared\",
      \"share\": \"/share\",
      \"clone\": \"/clone\",
      \"search\": \"/search\"
  }
}" > /usr/local/etc/jupyter/nbconfig/sharing.json
fi

if [[ $HELP_ENDPOINT ]]
then
  echo "{
    \"help\": \"$HELP_ENDPOINT\"
}" > /usr/local/etc/jupyter/nbconfig/help.json
fi

if [[ $GALLERY_URL ]]
then
  echo "c.NotebookApp.jinja_template_vars = {
    'gallery_url': '$GALLERY_URL'
}" >> $JPY_CONFIG
fi

# Make sure we have a sane terminal
printf "export TERM=xterm\n" >> $SWAN_ENV_FILE

# If there, source users' .bashrc after the SWAN environment
BASHRC_LOCATION=$SWAN_HOME/.bashrc
printf "if [[ -f $BASHRC_LOCATION ]];
then
   source $BASHRC_LOCATION
fi\n" >> $SWAN_ENV_FILE

if [ $? -ne 0 ]
then
  log_error "Error setting the environment for kernels"
  exit 1
else
  CONFIGURE_KERNEL_ENV_TIME_SEC=$(echo $(date +%s.%N --date="$START_TIME_CONFIGURE_KERNEL_ENV seconds ago") | bc)
  log_info "user: $USER, host: ${SERVER_HOSTNAME%%.*}, metric: configure_kernel_env.${ROOT_LCG_VIEW_NAME:-none}.${SPARK_CLUSTER_NAME:-none}.duration_sec, value: $CONFIGURE_KERNEL_ENV_TIME_SEC"
fi

# Set the terminal environment
#in jupyter 6.0.0 login shell (jupyter/notebook#4112) is set by default and /etc/profile.d is respected
echo "source $SCRATCH_HOME/.bash_profile" > /etc/profile.d/swan.sh

# Allow further configuration by sysadmin (usefull outside of CERN)
if [[ $CONFIG_SCRIPT ]]; 
then
  log_info "Found Config script"
  sh $CONFIG_SCRIPT
fi

# Run notebook server
log_info "Running the notebook server"
sudo -E -u $USER sh -c 'cd $SWAN_HOME \
                        && jupyterhub-singleuser \
                           --port=8888 \
                           --ip=0.0.0.0 \
                           --user=$JPY_USER \
                           --cookie-name=$JPY_COOKIE_NAME \
                           --base-url=$JPY_BASE_URL \
                           --hub-prefix=$JPY_HUB_PREFIX \
                           --hub-api-url=$JPY_HUB_API_URL'
