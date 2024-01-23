from typing import Optional
from flask import Flask, request, jsonify
import logging
from logging.handlers import RotatingFileHandler
import json

from src.event_processor.params.simple_authenticator import SimpleAuthenticator
from src.event_processor.params.config_aws import ConfigAWS
from src.event_processor.process_new_event import process_new_event

DEBUG = True

app = Flask(__name__)

# Set up logging
handler = RotatingFileHandler('flask.log', maxBytes=10000, backupCount=3)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
logger.addHandler(handler)

@app.route("/test", methods=["GET"])
def process_test_request():
    logger.info("Test request received")
    return jsonify({"message": "Request processed successfully!"}), 200  

@app.route('/process-event', methods=['POST'])
def process_event():
    msg: str = ''

    try:
        headers = request.headers
        body = request.json

        config = ConfigAWS()
        _authenticate(headers, config)

    except Exception as e:
        msg = f'Error initializing request: {e}'
        logger.error(msg)
        return _get_response(msg)

    try:
        logger.info(f'Processing event: {body}')
        process_new_event(body, config)
    except Exception as e:
        msg = f'Error processing event: {e}'
        logger.error(msg)

    return _get_response(None)

def _authenticate(headers, config: ConfigAWS):
    client_auth_token = _get_auth_token(headers)
    expected_auth_token = config.get_expected_auth_token()
    logger.info(f'Client auth token: {client_auth_token} ?= {expected_auth_token}')
    if not SimpleAuthenticator(expected_auth_token).is_autherized(client_auth_token):
        raise Exception('Error: Unauthorized request')

def _get_auth_token(headers) -> str:
    auth_token = headers.get('X-Secret-Token')
    return auth_token

def _get_response(msg: Optional[str]) -> any:
    
    if (msg is None) or (DEBUG == False):
        response = jsonify('Request processed successfully')
        response.status_code = 200
    else:
        response = jsonify(msg)
        response.status_code = 400
    
    return response

if __name__ == "__main__":
    app.run(debug=DEBUG)
