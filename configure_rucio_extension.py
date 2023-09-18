# Derived from https://github.com/rucio/jupyterlab-extension/blob/master/docker/configure.py

import os
import json

def write_jupyterlab_config():
    file_path = '/etc/jupyter/jupyter_notebook_config.json'
    if not os.path.isfile(file_path):
        os.makedirs('/etc/jupyter/', exist_ok=True)
    else:
        config_file = open(file_path, 'r')
        config_payload = config_file.read()
        config_file.close()

    try:
        config_json = json.loads(config_payload)
    except:
        config_json = {}

    instance_config = {
        "name": os.getenv('RUCIO_NAME', "default"),
        "display_name": os.getenv('RUCIO_DISPLAY_NAME', "Default Instance"),
        "rucio_base_url": os.getenv('RUCIO_BASE_URL'),
        "rucio_auth_url": os.getenv('RUCIO_AUTH_URL'),
        "rucio_webui_url": os.getenv('RUCIO_WEBUI_URL'),
        "rucio_ca_cert": os.getenv('RUCIO_CA_CERT'),
        "site_name": os.getenv('RUCIO_SITE_NAME'),
        "vo": os.getenv('RUCIO_VO'),
        "voms_enabled": os.getenv('RUCIO_VOMS_ENABLED', '0') == '1',
        "voms_vomses_path": os.getenv('RUCIO_VOMS_VOMSES_PATH'),
        "voms_certdir_path": os.getenv('RUCIO_VOMS_CERTDIR_PATH'),
        "voms_vomsdir_path": os.getenv('RUCIO_VOMS_VOMSDIR_PATH'),
        "destination_rse": os.getenv('RUCIO_DESTINATION_RSE'),
        "rse_mount_path": os.getenv('RUCIO_RSE_MOUNT_PATH'),
        "replication_rule_lifetime_days": int(os.getenv('RUCIO_REPLICATION_RULE_LIFETIME_DAYS')) if os.getenv('RUCIO_REPLICATION_RULE_LIFETIME_DAYS') else None,
        "path_begins_at": int(os.getenv('RUCIO_PATH_BEGINS_AT', '0')),
        "mode": os.getenv('RUCIO_MODE', 'replica'),
        "wildcard_enabled": os.getenv('RUCIO_WILDCARD_ENABLED', '0') == '1',
        "oidc_auth": os.getenv('RUCIO_OIDC_AUTH'),
        "oidc_env_name": os.getenv('RUCIO_OIDC_ENV_NAME'),
        "oidc_file_name": os.getenv('RUCIO_OIDC_FILE_NAME'),
    }

    instance_config = {k: v for k,
                       v in instance_config.items() if v is not None}
    config_json['RucioConfig'] = {
        'instances': [instance_config],
        "default_instance": os.getenv('RUCIO_DEFAULT_INSTANCE'),
        "default_auth_type": os.getenv('RUCIO_DEFAULT_AUTH_TYPE'),
    }

    config_file = open(file_path, 'w')
    config_file.write(json.dumps(config_json, indent=2))
    config_file.close()
    
if __name__ == '__main__':
    write_jupyterlab_config()
    