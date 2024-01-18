import uuid
import pytest
from datetime import datetime
import pandas as pd

from src.event_processor.logger.event_logger_new_relic import EventLoggerNewRelic
from src.event_processor.params.config_local import ConfigLocal


class TestEventLoggerNewRelic():

    def test_send_event_to_logger(self) -> None:

        config = ConfigLocal()
        event_logger = EventLoggerNewRelic(config.get_logger_api_key())

        unique_id = str(uuid.uuid4())
        event = pd.DataFrame({
            'Time': datetime.now(),
            'Repo': 'test_logger',
            'Event': 'deploy',
            'Metadata': ["{'test_id': unique_id}"],
        })

        event_log_item = event_logger.get_event_log_item_from_df_event(event)
        event_logger.send_event_to_logger(event_log_item)
