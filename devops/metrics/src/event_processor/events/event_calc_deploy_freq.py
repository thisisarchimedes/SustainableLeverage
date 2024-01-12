import datetime

from src.event_processor.events.event import Event
from src.event_processor.calculations.dora_deploy_frequency_calculator import DORADeployFrequencyCalculator


class EventCalcDeployFrequency(Event):

    def process(self) -> None:

        self.db_connection.write_event_to_db(self.payload)

        res = self.logger.get_event_log_item_from_df_event(self.payload)
        self.logger.send_event_to_logger(res)
