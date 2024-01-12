from dataclasses import dataclass
import pandas as pd
import json

from src.event_processor.logger.event_logger import EventLogItem, EventLogger


class EventLoggerFake(EventLogger):

    logger_path = 'test/fake_db/logger.csv'

    def send_event_to_logger(self, event_log_item: EventLogItem) -> None:
           
        event_df = pd.DataFrame(json.loads(event_log_item.event), index=[0])

        repo = event_df['Repo'].iloc[0]
        event_type = event_df['Event'].iloc[0]

        event_log_item.message = f'Repo: {repo} ; Event: {event_type}'

        event_df.to_csv(self.logger_path, mode='a+', header=False, index=False)
