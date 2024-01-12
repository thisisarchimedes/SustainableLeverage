from abc import ABC, abstractmethod

class Config(ABC):

    @abstractmethod
    def get_expected_auth_token(self) -> str:
        pass

    @abstractmethod
    def get_logger_api_key(self) -> str:
        pass

    @abstractmethod
    def get_db_name(self) -> str:
        pass

    @abstractmethod
    def get_db_table_name(self) -> str:
        pass
    
    @abstractmethod
    def get_deployment_freq_timeframe_days(self) -> int:
        pass

        
        
