import os
import sys
import requests
import json
from dotenv import load_dotenv

SERVICE="DevOps"
MESSAGE="DevOps Event: "

def send_devops_event_to_new_relic(event_msg: dict):

    load_dotenv()

    api_key = os.getenv("NEW_RELIC_API_KEY")

    endpoint = "https://log-api.newrelic.com/log/v1"  

    headers = {
        "Content-Type": "application/json",
        "Api-Key": api_key
    }

    data = {
        "service": SERVICE,
        "message": MESSAGE + event_msg["repo"],
        "info": event_msg,
    }

    requests.post(endpoint, headers=headers, data=json.dumps(data))

def create_event_msg(repo_name: str, action: str, test_pass: bool, test_time_seconds: float) -> dict:

    msg = {
        "repo": repo_name,
        "action": action,
        "test_pass": test_pass,
        "test_time_seconds": test_time_seconds,
    }

    return msg

def main():
    args = sys.argv[1:]
    repo_name = args[0]
    action = args[1]
    test_pass = args[2]
    test_time_seconds = args[3]

    msg = create_event_msg(repo_name, action, test_pass, test_time_seconds)
    send_devops_event_to_new_relic(msg)


__name__ == "__main__" and main()

