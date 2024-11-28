#!/bin/env python3

import sys
import json
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv
import os

env_path="~/.env"
load_dotenv(env_path) # Load .env file located at home directory

#CHAT_ID="xxxx" --> Modify this line with the chat id of the telegram group
# You can get the chat id with the following url: https://sean-bradley.medium.com/get-telegram-chat-id-80b575520659
CHAT_ID=os.getenv("GROUP_CHAT_ID") 

# Read configuration parameters
alert_file = open(sys.argv[1])
hook_url = sys.argv[3]

# Read the alert file
alert_json = json.loads(alert_file.read())
alert_file.close()

# Extract data fields
alert_level = alert_json['rule']['level'] if 'level' in alert_json['rule'] else "N/A"
description = alert_json['rule']['description'] if 'description' in alert_json['rule'] else "N/A"
agent = alert_json['agent']['name'] if 'name' in alert_json['agent'] else "N/A"
# Generate request
msg_data = {}
msg_data['chat_id'] = CHAT_ID
msg_data['text'] = {}
msg_data['text']['description'] =  description
msg_data['text']['alert_level'] = str(alert_level)
msg_data['text']['agent'] =  agent
headers = {'content-type': 'application/json', 'Accept-Charset': 'UTF-8'}


# Send the request
requests.post(hook_url, headers=headers, data=json.dumps(msg_data))

sys.exit(0)