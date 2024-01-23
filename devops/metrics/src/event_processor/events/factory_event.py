
from src.event_processor.database.db_connection import DBConnection

from src.event_processor.events.event import Event
from src.event_processor.events.event_push import EventPush
from src.event_processor.events.event_test_pass import EventTestPass
from src.event_processor.events.event_deploy import EventDeploy
from src.event_processor.events.event_calc_deploy_freq import EventCalcDeployFrequency
from src.event_processor.events.event_test_run import EventTestRun

from src.event_processor.logger.event_logger import EventLogger

class FactoryEvent():

    def __init__(self, 
                 db_connection: DBConnection, 
                 logger: EventLogger, 
                 deploy_frequency_timewindow_days: int = 30) -> None:
        
        self.db_connection = db_connection
        self.logger = logger
        self.deploy_frequency_timewindow_days = deploy_frequency_timewindow_days

    def create_event(self, payload: dict) -> Event:
        
        event: Event
        
        if payload['Event'] == 'push':
            event = EventPush(payload, self.db_connection, self.logger)
        elif payload['Event'] == 'test_pass':
            event = EventTestPass(payload, self.db_connection, self.logger)
        elif payload['Event'] == 'deploy':
            event = EventDeploy(payload, self.db_connection, self.logger, self.deploy_frequency_timewindow_days)
        elif payload['Event'] == 'calc_deploy_frequency':
            event = EventCalcDeployFrequency(payload, self.db_connection, self.logger)
        elif payload['Event'] == 'test_run':
            event = EventTestRun(payload, self.db_connection, self.logger)
        else:
            raise Exception("Invalid event type.")
        
        return event
    
    
    @staticmethod
    def is_event_type_valid(event_type: str) -> bool:
        
        if event_type == 'push':
            return True
        elif event_type == 'test_pass':
            return True
        elif event_type == 'deploy':
            return True
        elif event_type == 'calc_deploy_frequency':
            return True
        elif event_type == 'test_run':
            return True
        else:
            return False