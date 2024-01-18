import pytest
import json
from datetime import datetime

from src.event_processor.params.config_aws import ConfigAWS
from src.event_processor.entry_lambda import entry_point_lambda


class TestIntegrationLambdaProcessEvent():

    def test_process_event_deploy(self, capfd):

        auth_token = ConfigAWS().get_expected_auth_token()

        devops_event_payload = {
            'Time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'Repo': 'test_repo',
            'Event': 'deploy',
            'Metadata': 'LAMBDA'
        }

        aws_event = {
            "httpMethod": "POST",
            "body": devops_event_payload,
            "headers": {
                "Content-Type": "application/json",
                "X-Secret-Token": auth_token
            },

        }

        aws_context = {
            "function_name": "my_lambda_function",
            "function_version": "$LATEST",
            "invoked_function_arn": "arn:aws:lambda:...",
            "memory_limit_in_mb": "128",
            "aws_request_id": "some-unique-id",
            "log_group_name": "/aws/lambda/my_lambda_function",
            "log_stream_name": "2021/03/29/[$LATEST]abcdef1234567890"
        }

        aws_event_serailized = json.dumps(aws_event).encode('utf-8')
        aws_context_serailized = json.dumps(aws_context).encode('utf-8')

        entry_point_lambda(aws_event_serailized, aws_context_serailized)
        out, err = capfd.readouterr()

        # Split the output into lines and check each line
        for line in out.split('\n'):
            assert not line.startswith(
                'Error'), f"Test failed due to error print statement {out}"

        # Optionally, also check the standard error (stderr)
        for line in err.split('\n'):
            assert not line.startswith(
                'Error'), f"Test failed due to error print statement {err}"
