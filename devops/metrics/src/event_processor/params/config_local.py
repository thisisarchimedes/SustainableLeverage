import os
from dotenv import load_dotenv
from src.event_processor.params.config import Config

class ConfigLocal(Config):

    def __init__(self) -> None:
        load_dotenv()

    def get_expected_auth_token(self) -> str:
        token = os.getenv('SECRET_TOKEN')
        if token is None:
            raise ValueError("Environment variable 'SECRET_TOKEN' is not set")
        return token

    def get_logger_api_key(self) -> str:
        api_key = os.getenv('LOGGER_API_KEY')
        if api_key is None:
            raise ValueError("Environment variable 'LOGGER_API_KEY' is not set")
        return api_key
    
    def get_db_name(self) -> str:
        db_name = os.getenv('DEVOPS_DB_NAME')
        if db_name is None:
            raise ValueError("Environment variable 'DEVOPS_DB_NAME' is not set")
        return db_name

    def get_db_table_name(self) -> str:
        table_name = os.getenv('DEVOPS_TABLE_NAME')
        if table_name is None:
            raise ValueError("Environment variable 'DEVOPS_TABLE_NAME' is not set")
        return table_name
    
    def get_deployment_freq_timeframe_days(self) -> int:
        timeframe = os.getenv('DEPLOYMENT_FREQ_TIMEFRAME_DAY')
        if timeframe is None:
            raise ValueError("Environment variable 'DEPLOYMENT_FREQ_TIMEFRAME_DAY' is not set")
        return int(timeframe)
