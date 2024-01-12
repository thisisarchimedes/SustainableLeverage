import json

from src.event_processor.params.simple_authenticator import SimpleAuthenticator
from src.event_processor.params.config_aws import ConfigAWS
from src.event_processor.process_new_event import process_new_event

def entry_point_lambda(raw_event, context):
    
    try:
        headers = _get_headers(raw_event)
        body = _get_body(raw_event)

        config = ConfigAWS()
        _authenticate(headers, config)

    except Exception as e:
        print(f'Error initializing Lambda: {e}')
        return _get_response()
    
    try:
        process_new_event(body, config)
    except Exception as e:
        print(f'Error processing event: {e}')

    return _get_response()


def _authenticate(headers, config: ConfigAWS):
    
    client_auth_token = _get_auth_token(headers)
    expected_auth_token = config.get_expected_auth_token()
    if SimpleAuthenticator(expected_auth_token).is_autherized(client_auth_token) == False:
        raise Exception('Error: Unauthorized request')
        

def _get_auth_token(headers) -> str:

    auth_token = headers.get('X-Secret-Token')
    return auth_token

def _get_body(event) -> dict:
    payload = json.loads(event)['body']
    return payload
    
def _get_headers(event) -> dict:
    payload = json.loads(event)['headers']
    return payload

    
def _get_response() -> dict:
     # Always return 200 success for security reasons
    response =  {
        'statusCode': 200,
        'body': json.dumps('Request processed successfully')
    }

    return response
