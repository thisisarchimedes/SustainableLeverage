import os
import dataclasses
import datetime

from bson import json_util
import json

import requests
import pandas as pd

from src.event_processor.logger.event_logger import EventLogItem, EventLogger


class EventLoggerNewRelic(EventLogger):

    def __init__(self, api_key: str | None) -> None:

        self.new_relic_url = "https://log-api.newrelic.com/log/v1"
        self.api_key = api_key
        if not self.api_key:
            raise EnvironmentError("NEW_RELIC_API_KEY environment variable not set")
        

    def send_event_to_logger(self, event_log_item: EventLogItem) -> None:
              
        payload = self._get_event_payload_str(event_log_item)
        headers = self._get_request_headers()

        response = requests.post(self.new_relic_url, headers=headers, data=payload)
        if not response.ok:
            raise Exception(f"Failed to send event to New Relic: {response.text}")
        
        
    def _get_event_payload_str(self, event_log_item: EventLogItem) -> str:   
    
        log_item_dict = {
            'event': event_log_item.event,
            'message': event_log_item.message,
            'service': event_log_item.service,
        }
        
        json_event_log_item = json.dumps(log_item_dict)
        return json_event_log_item
        

    def _get_request_headers(self) -> dict:
        headers = {
            "Api-Key": self.api_key,
            "Content-Type": "application/json",
        }

        return headers
