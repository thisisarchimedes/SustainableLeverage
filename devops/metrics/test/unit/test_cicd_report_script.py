import pytest
import requests
import requests_mock
import subprocess
from src.cicd_script.report_devops_event import DevOpsEventReporter
import json

class TestCICDReportScript:

    def test_unsupported_event(self):

        result = subprocess.run(['python', 'src/report_devops_event.py', 'test_repo', 'invalid'], capture_output=True, text=True)
        assert result.returncode != 0, "Script should have failed but it didn't."

    def test_generate_push_event_json(self):
        
        event_reporter = DevOpsEventReporter("http://localhost:5000")

        record = event_reporter.prepare_record("test_repo", "push", "")
    
        expected = {'Repo': 'test_repo', 'Event': 'push', 'Metadata': ''}

        assert record == expected, "JSON output is not correct."

    def test_post_payload_to_api_endpoint(self):

        with requests_mock.Mocker() as m:

            test_url = "http://localhost:5000"
            expected_response = {'status': 'success'}
            m.post(test_url, json=expected_response)

            event_reporter = DevOpsEventReporter(test_url)

            record = event_reporter.prepare_record("test_repo", "push", "")
            response = event_reporter.post_event(record)

            assert response.status_code == 200
            assert response.json() == expected_response


