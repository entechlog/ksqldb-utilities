import socket
import sys
import getopt
import os
import argparse
import time
import json
import yaml
import requests
import tempfile
from requests.exceptions import HTTPError
from requests.auth import HTTPBasicAuth
from tabulate import tabulate

def main():
    # Display the program start time
    print('-' * 40)
    print(os.path.basename(sys.argv[0]) + " started at ", time.ctime())
    print('-' * 40)

    print('Number of arguments          :', len(sys.argv))
    print('Argument List:', str(sys.argv))

    parser = argparse.ArgumentParser(description="""
    This script generates sample data for specified kafka topic. 
    """)
    parser.add_argument("--config_file", help="specify the path for config yaml file", required=True)
    parser.add_argument("--environment", help="specify the environment from yaml config file", required=True)
    parser.add_argument("--mode", help="specify the mode, Valid values are dryrun OR realrun", required=True)

    args = parser.parse_args()

    global config_file
    config_file = args.config_file

    global environment
    environment = args.environment

    global mode
    mode = args.mode

    print("Configuration File           : " + config_file)
    print("Environment File             : " + environment)
    print("Run Mode                     : " + mode)

def get_config():
    print("Executing step               : get_config")
    global host_name
    global basic_auth_user
    global basic_auth_password

    with open(config_file) as configFile:
        config_documents = yaml.full_load(configFile)

        for env_key, env_value in config_documents[environment].items():
            if env_key == "host_name":
                host_name = env_value
            elif env_key == "basic_auth_user":
                basic_auth_user = env_value
            elif env_key == "basic_auth_password":
                basic_auth_password = env_value
                
        print("host_name                    : " + str(host_name))
        print("basic_auth_user              : " + str(basic_auth_user))
        print("basic_auth_password          : " + str(basic_auth_password))

        #for config_key, config_value in config_documents.items():
        #    if config_key == environment:
        #        print(config_value)
        #        parsed_config = yaml.dump(config_value, sort_keys=False)
        #        print(parsed_config)

def get_schemas():

    global all_schemas
    global active_schemas

    print("Executing step               : get_schemas")
    rest_url = host_name + "/subjects?deleted=true"
    print("Get all schemas              : " + rest_url)

    try:
        response = requests.get(rest_url, verify=False, auth=HTTPBasicAuth(basic_auth_user, basic_auth_password))
        # If the response was successful, no Exception will be raised
        response.raise_for_status()
    except HTTPError as http_err:
        print(f'HTTP error occurred: {http_err}')
    except Exception as err:
        print(f'Other error occurred: {err}')
    else:
        # Uncomment only to debug
        response_json = json.loads(response.text)
        all_schemas = response_json
        print("all_schemas                  : " + str(all_schemas))

    rest_url = host_name + "/subjects"
    print("Get deleted schemas          : " + rest_url)

    try:
        response = requests.get(rest_url, verify=False, auth=HTTPBasicAuth(basic_auth_user, basic_auth_password))
        # If the response was successful, no Exception will be raised
        response.raise_for_status()
    except HTTPError as http_err:
        print(f'HTTP error occurred: {http_err}')
    except Exception as err:
        print(f'Other error occurred: {err}')
    else:
        # Uncomment only to debug
        response_json = json.loads(response.text)
        active_schemas = response_json
        print("active_schemas               : " + str(active_schemas))

def compare_schemas():

    global to_be_deleted_schemas

    print("Executing step               : compare_schemas")
    to_be_deleted_schemas = list(set(all_schemas) - set(active_schemas))
    print("to_be_deleted_schemas        : " + str(to_be_deleted_schemas))
    print("to_be_deleted_schemas count  : " + str(len(to_be_deleted_schemas)))

def delete_schemas():

    print("Executing step               : delete_schemas")
    
    for schema in to_be_deleted_schemas:
        rest_url = host_name + "/subjects/" + schema + "/?permanent=true"
        data = {}
        headers = {'content-type': 'application/json'}
    
        # Make a REST API call to put the connector property
        try:
            response = requests.delete(rest_url, headers=headers, verify=False, auth=HTTPBasicAuth(basic_auth_user, basic_auth_password))
            # If the response was successful, no Exception will be raised
            response.raise_for_status()
        except HTTPError as http_err:
            print(f'HTTP error occurred: {http_err}')  # Python 3.6
        except Exception as err:
            print(f'Other error occurred: {err}')  # Python 3.6
        else:
            print("deleted_schema               : " + schema)

def tabulate_report():
    global deleted_schemas_report
    print("Executing step               : tabulate_report")
    deleted_schemas_report = tabulate([to_be_deleted_schemas], tablefmt='grid', headers=['Schema Name'])
    print(deleted_schemas_report)

if __name__ == "__main__":
    main()
    get_config()
    get_schemas()
    compare_schemas()
    if mode == 'realrun':
        delete_schemas()
    tabulate_report()
    sys.exit()