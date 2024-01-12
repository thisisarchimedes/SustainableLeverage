from datetime import datetime, timedelta
import pandas as df

from src.event_processor.events.event import Event
from src.event_processor.calculations.dora_deploy_frequency_calculator import DORADeployFrequencyCalculator
from src.event_processor.database.db_connection import DBConnection
from src.event_processor.logger.event_logger import EventLogger


class EventDeploy(Event):

    def __init__(self, 
                 payload: dict, 
                 db_connection: DBConnection, 
                 logger: EventLogger, 
                 deploy_frequency_timewindow_days: int) -> None:
        super().__init__(payload, db_connection, logger)

        self.deploy_frequency_timewindow_days = deploy_frequency_timewindow_days

    def process(self) -> None:

        self.db_connection.write_event_to_db(self.payload)

        res = self.logger.get_event_log_item_from_df_event(self.payload)
        self.logger.send_event_to_logger(res)

        daily_deploy_volume_df = self.db_connection.get_daily_deploy_volume(None)
        dora_deploy_frequency_calculator = DORADeployFrequencyCalculator()
        start_date = datetime.now() - timedelta(days=self.deploy_frequency_timewindow_days)
        end_date = datetime.now()

        deploy_frequency = dora_deploy_frequency_calculator.get_deployment_frequency(daily_deploy_volume=daily_deploy_volume_df,
                                                                                     start_date=start_date,
                                                                                     end_date=end_date)

        metadata = '{"deploy_frequency": ' + str(deploy_frequency) + '}'
        event = {
            'Time': datetime.now(),
            'Repo': 'ALL',
            'Event': 'calc_deploy_frequency',
            'Metadata': metadata
        }
        
        event_df = df.DataFrame([event])
        self.db_connection.write_event_to_db(event_df)

        res = self.logger.get_event_log_item_from_df_event(event_df)
        self.logger.send_event_to_logger(res)
