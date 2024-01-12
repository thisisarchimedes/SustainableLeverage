import pytest
from datetime import datetime
import json
import os
from src.event_processor.params.payload_validator import PayloadValidator


class TestPayloadValidator:

    def test_payload_invalid_event(self):

        payload_validator = PayloadValidator()

        payload = {
            'Time': datetime.now(),
            'Repo': 'test_repo',
            'Event': 'invalid',
            'Metadata': 'test_metadata'
        }

        res = payload_validator.is_payload_valid(payload)
        assert res == False, "is_payload_valid() should return False when event type is invalid."

    def test_payload_event_missing(self):

        payload_validator = PayloadValidator()

        payload = {
            'Time': datetime.now(),
            'Repo': 'test_repo',
            'Metadata': 'test_metadata'
        }

        res = payload_validator.is_payload_valid(payload)
        assert res == False, "test_payload_event_missing() should return False when event type is invalid."

    def test_payload_valid_without_metadata(self):

        payload_validator = PayloadValidator()

        payload = {
            'Time': datetime.now(),
            'Repo': 'test_repo',
            'Event': 'push',
        }

        res = payload_validator.is_payload_valid(payload)
        assert res == True, "test_payload_valid_without_metadata() should return True when payload is valid."
