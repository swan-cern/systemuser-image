#!/bin/sh

log_info() {
    echo "[INFO $(date '+%Y-%m-%d %T.%3N') $(basename $0)] $1"
}

log_info "Configuring user session"

START_TIME_SETUP_SWAN_HOME=$( date +%s.%N )

# Make sure the user has the SWAN_projects folder
SWAN_PROJECTS=$SWAN_HOME/SWAN_projects/
mkdir -p $SWAN_PROJECTS

SETUP_SWAN_HOME_TIME_SEC=$(echo $(date +%s.%N --date="$START_TIME_SETUP_SWAN_HOME seconds ago") | bc)
log_info "user: $USER, host: ${SERVER_HOSTNAME%%.*}, metric: configure_user_env_swan_home.duration_sec, value: $SETUP_SWAN_HOME_TIME_SEC"

# Persist enabled notebook nbextensions
NBCONFIG=$JPY_DIR/nbconfig
mkdir -p $NBCONFIG
LOCAL_NB_NBEXTENSIONS=$SWAN_PROJECTS/.notebook_nbextensions
if [ ! -f $LOCAL_NB_NBEXTENSIONS ]; then 
  echo "{
    \"load_extensions\": {
    }
  }" > $LOCAL_NB_NBEXTENSIONS
fi
rm -f $NBCONFIG/notebook.json
ln -s $LOCAL_NB_NBEXTENSIONS $NBCONFIG/notebook.json

START_TIME_SETUP_LCG=$( date +%s.%N )

# Setup LCG
source $LCG_VIEW/setup.sh

# Append NVIDIA_LIB_PATH to LD_LIBRARY_PATH
if [[ $NVIDIA_LIB_PATH ]];
then
 export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$NVIDIA_LIB_PATH
fi

# Append NVIDIA_PATH to PATH
if [[ $NVIDIA_PATH ]];
then
 export PATH=$PATH:$NVIDIA_PATH
fi


SETUP_LCG_TIME_SEC=$(echo $(date +%s.%N --date="$START_TIME_SETUP_LCG seconds ago") | bc)
log_info "user: $USER, host: ${SERVER_HOSTNAME%%.*}, metric: configure_user_env_cvmfs.${ROOT_LCG_VIEW_NAME:-none}.duration_sec, value: $SETUP_LCG_TIME_SEC"

# Add SWAN modules path to PYTHONPATH so that it picks them
export PYTHONPATH=/usr/local/lib/swan/extensions/:$PYTHONPATH 

# Configure SparkMonitor
export KERNEL_PROFILEPATH=$PROFILEPATH/ipython_kernel_config.py 
echo "c.InteractiveShellApp.extensions.append('sparkmonitor.kernelextension')" >>  $KERNEL_PROFILEPATH

# Configure SparkConnector
if [[ $SPARK_CLUSTER_NAME ]]; 
then
 START_TIME_SETUP_SPARK=$( date +%s.%N )

 log_info "Configuring environment for Spark cluster: $SPARK_CLUSTER_NAME"
 # detect Spark major version to choose different Spark configuration 
 # the second argument of $SPARK_CONFIG_SCRIPT is the classpath compatibility for yarn
 SPARK_MJR_VERSION=$(readlink -f `which pyspark` | awk -F\/ '{print substr($7,1,1)}')
 HADOOP_MJR_VERSION=$(readlink -f `which hdfs` | awk -F\/ '{print substr($7,1,1)}')
 if [[ $SPARK_MJR_VERSION == 3 ]]; then SPARKVERSION=spark3; fi
 if [[ $HADOOP_MJR_VERSION == 3 ]]; then HADOOPVERSION='3.2'; fi
 source $SPARK_CONFIG_SCRIPT $SPARK_CLUSTER_NAME ${HADOOPVERSION:-'2.7'} ${SPARKVERSION:-'spark2'}
 #to make sure we get the ipv4 addrress when in dual stack nodes
 export SPARK_LOCAL_IP=$(getent ahostsv4 | awk "/$HOSTNAME/ {print \$1}")
 echo "c.InteractiveShellApp.extensions.append('sparkconnector.connector')" >>  $KERNEL_PROFILEPATH
 if [[ $CONNECTOR_BUNDLED_CONFIGS ]]
  then
    ln -s $CONNECTOR_BUNDLED_CONFIGS/bundles.json $JUPYTER_CONFIG_DIR/nbconfig/sparkconnector_bundles.json
    ln -s $CONNECTOR_BUNDLED_CONFIGS/spark_options.json $JUPYTER_CONFIG_DIR/nbconfig/sparkconnector_spark_options.json
  fi
 log_info "Completed Spark Configuration"

 SETUP_SPARK_TIME_SEC=$(echo $(date +%s.%N --date="$START_TIME_SETUP_SPARK seconds ago") | bc)
 log_info "user: $USER, host: ${SERVER_HOSTNAME%%.*}, metric: configure_user_env_spark.${ROOT_LCG_VIEW_NAME:-none}.${SPARK_CLUSTER_NAME:-none}.duration_sec, value: $SETUP_SPARK_TIME_SEC"
fi

# Run user startup script
export JUPYTER_DATA_DIR=$LCG_VIEW/share/jupyter 
export TMP_SCRIPT=`mktemp`

if [[ $USER_ENV_SCRIPT && -f `eval echo $USER_ENV_SCRIPT` ]];
then
 START_TIME_SETUP_SCRIPT=$( date +%s.%N )
 
 log_info "Found user script: $USER_ENV_SCRIPT"
 export TMP_SCRIPT=`mktemp`
 cat `eval echo $USER_ENV_SCRIPT` > $TMP_SCRIPT
 source $TMP_SCRIPT

 SETUP_SCRIPT_TIME_SEC=$(echo $(date +%s.%N --date="$START_TIME_SETUP_SCRIPT seconds ago") | bc)
 log_info "user: $USER, host: ${SERVER_HOSTNAME%%.*}, metric: configure_user_env_script.duration_sec, value: $SETUP_SCRIPT_TIME_SEC"
else
 log_info "Cannot find user script: $USER_ENV_SCRIPT";
fi

# In k8s, $KRB5CCNAME_NB_TERM points to the location of the EOS kerberos ticket that notebook and terminal
# processes use. The Jupyter server uses the same ticket stored in another location ($KRB5CCNAME). With the
# code below, we force that $KRB5CCNAME becomes $KRB5CCNAME_NB_TERM only for notebook and terminal processes.
# This duality exists to prevent the user from overwriting the EOS kerberos ticket that the Jupyter server
# uses, e.g. by doing `kinit` from a notebook or a terminal.
# In puppet, $KRB5CCNAME_NB_TERM does not exist. Thus we give it a value and make $KRB5CCNAME point to that
# value.
# Both in k8s and puppet, renewals of the EOS kerberos tickets are automatically done to prevent expiration,
# both for the Jupyter server and the notebooks and terminals. However, if the user runs an explicit kinit
# and generates new kerberos credentials for notebooks and terminals, they are responsible for renewing those
# credentials from that point on.
if [[ -z $KRB5CCNAME_NB_TERM ]]
then
  KRB5CCNAME_NB_TERM="/tmp/krb5cc_${USER_ID}_${RANDOM}"
fi
export KRB5CCNAME=$KRB5CCNAME_NB_TERM

# As the LCG setup might set PYTHONHOME, run python with -I (Isolated Mode) to prevent
# the lookup for modules in a Python 3 path and user site
/usr/local/bin/python3 -I /srv/singleuser/configure_kernels_and_terminal.py

# Remove our extra paths (where we install our extensions) in the kernel (via SwanKernelEnv kernel extension), 
# leaving the user env cleaned. It should be the last one called to allow the kernel to load our extensions correctly.
echo "c.InteractiveShellApp.extensions.append('swankernelenv')" >>  $KERNEL_PROFILEPATH
