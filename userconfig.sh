#!/bin/sh

echo "Configuring user session"

# Make sure the user has the SWAN_projects folder
mkdir -p $SWAN_HOME/SWAN_projects/

# Setup LCG
source $LCG_VIEW/setup.sh

# Add SWAN modules path to PYTHONPATH so that it picks them
export PYTHONPATH=$EXTRA_LIBS/modules/:$PYTHONPATH 

# To prevent conflicts with older versions of Jupyter dependencies in CVMFS
# add these packages to the beginning of PYTHONPATH
if [[ $PYVERSION -eq 3 ]]; 
then 
 export PYTHONPATH=/usr/local/lib/swan/:$PYTHONPATH
fi 

# Configure SparkMonitor
export KERNEL_PROFILEPATH=$PROFILEPATH/ipython_kernel_config.py 
echo "c.InteractiveShellApp.extensions.append('sparkmonitor.kernelextension')" >>  $KERNEL_PROFILEPATH

# Configure SparkConnector
if [[ $SPARK_CLUSTER_NAME ]]; 
then
 echo "Configuring environment for Spark cluster: $SPARK_CLUSTER_NAME"
 source $SPARK_CONFIG_SCRIPT $SPARK_CLUSTER_NAME
 export SPARK_LOCAL_IP=`hostname -i`
 NBCONFIG=$SCRATCH_HOME/.jupyter/nbconfig
 mkdir -p $NBCONFIG
 echo "{
   \"load_extensions\": {
     \"sparkconnector/extension\": true
   }
 }" > $NBCONFIG/notebook.json
 echo "c.InteractiveShellApp.extensions.append('sparkconnector.connector')" >>  $KERNEL_PROFILEPATH
 echo "Completed Spark Configuration"
fi

# Run user startup script
export JUPYTER_DATA_DIR=$LCG_VIEW/share/jupyter 
export TMP_SCRIPT=`mktemp`

if [[ $USER_ENV_SCRIPT && -f `eval echo $USER_ENV_SCRIPT` ]]; 
then
 echo "Found user script: $USER_ENV_SCRIPT"
 export TMP_SCRIPT=`mktemp`
 cat `eval echo $USER_ENV_SCRIPT` > $TMP_SCRIPT
 source $TMP_SCRIPT
else
 echo "Cannot find user script: $USER_ENV_SCRIPT";
fi

# Configure kernels
# As the LCG setup might set PYTHONHOME, run python with -E to prevent this python 2 code
# to lookup for modules in a Python 3 path (if this is the selected stack)
python -E <<EOF
import os
import json

def addEnv(dtext):
    d=eval(dtext)
    d["env"]=dict(os.environ)
    return d

kdirs = os.listdir("$KERNEL_DIR")
kfile_names = ["$KERNEL_DIR/%s/kernel.json" % kdir for kdir in kdirs]
kfile_contents = [open(kfile_name).read() for kfile_name in kfile_names]
kfile_contents_mod = map(addEnv, kfile_contents)
print kfile_contents_mod
map(lambda d: open(d[0],"w").write(json.dumps(d[1])), zip(kfile_names,kfile_contents_mod))
termEnvFile = open("$SWAN_ENV_FILE", "w")
[termEnvFile.write("export %s=\"%s\"\n" % (key, val)) if key != "SUDO_COMMAND" else None for key, val in dict(os.environ).iteritems()]
EOF

# Make sure that `python` points to the correct python bin from CVMFS
printf "alias python=\"$(which python$PYVERSION)\"\n" >> $SWAN_ENV_FILE