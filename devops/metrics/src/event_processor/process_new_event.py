from src.event_processor.params.config import Config
from src.event_processor.params.payload_validator import PayloadValidator
from src.event_processor.database.db_connection_timeseries import DBConnectionTimeseries
from src.event_processor.logger.event_logger_new_relic import EventLoggerNewRelic
from src.event_processor.events.factory_event import FactoryEvent


def process_new_event(event_payload: dict, config: Config) -> None:

    if PayloadValidator().is_payload_valid(event_payload) == False:
        raise Exception('Invalid payload')
      
    db_connection = DBConnectionTimeseries(config.get_db_name(), config.get_db_table_name())
    event_logger = EventLoggerNewRelic(config.get_logger_api_key())
    deploy_frequency_timewindow_days = config.get_deployment_freq_timeframe_days()

    factory_event = FactoryEvent(db_connection, event_logger, deploy_frequency_timewindow_days)
    event = factory_event.create_event(event_payload)
    event.process()
    
