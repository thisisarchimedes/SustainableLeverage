import pandas as pd
from abc import ABC, abstractmethod

from src.event_processor.database.db_connection import DBConnection
from src.event_processor.logger.event_logger import EventLogger

class Event(ABC):

    def __init__(self, payload: pd.DataFrame | dict, db_connection: DBConnection, logger: EventLogger) -> None:
       
        if isinstance(payload, dict):
            self.payload = pd.DataFrame([payload])
        elif isinstance(payload, pd.DataFrame):
            self.payload = payload
        else:
            raise ValueError("Payload must be a dictionary or a pandas DataFrame")

        self.db_connection = db_connection
        self.logger = logger


    def get_repo_name(self) -> str:
        return self.payload['Repo'].iloc[0]  
    
    def get_event_type(self) -> str:
        return self.payload['Event'].iloc[0]  
    
    @abstractmethod
    def process(self) -> None:
        pass
