from abc import ABC, abstractmethod
from datetime import date
from typing import List, Optional
import pandas as pd


class DBConnection(ABC):

    def __init__(self, database_name: str, table_name: str):
        self.database_name = database_name
        self.table_name = table_name

    @abstractmethod
    def write_event_to_db(self, event_df: pd.DataFrame) -> None:
        pass

    @abstractmethod
    def get_all_events(self) -> pd.DataFrame:
        """
        |Timestamp|Repo|Event|Metadata|
        """
        pass
    
    @abstractmethod
    def get_repo_events(self, repo_name: str) -> pd.DataFrame:
        """
        |Timestamp|Repo|Event|Metadata|
        """
        pass
    
    @abstractmethod
    def get_daily_deploy_volume(self, repos_name: Optional[List[str]]) -> pd.DataFrame:
        """
        |Day|DeployCount|
        """
        pass
    
    @abstractmethod
    def get_deploy_frequency_events_since_date(self, start_date: date) -> pd.DataFrame:
        pass
