import os
import json
from dotenv import load_dotenv
import boto3

from src.event_processor.params.config import Config

class ConfigAWS(Config):

    def __init__(self):
        self._load_environment_variables()
        self._initialize_secrets_manager_client()

    
    def get_expected_auth_token(self) -> str:
        secret = self._fetch_secret()
        return self._extract_value_from_secret(secret, 'SECRET_TOKEN')
    
    
    def get_logger_api_key(self) -> str:
        secret = self._fetch_secret()
        return self._extract_value_from_secret(secret, 'LOGGER_API_KEY')

    def get_db_name(self) -> str:
        db_name = os.getenv('DEVOPS_DB_NAME')
        if not db_name:
            raise ValueError("DEVOPS_DB_NAME environment variable is not set.")
        return db_name
        

    def get_db_table_name(self) -> str:
        db_table_name = os.getenv('DEVOPS_TABLE_NAME')
        if not db_table_name:
            raise ValueError("DEVOPS_TABLE_NAME environment variable is not set.")
        return db_table_name
    
    def get_deployment_freq_timeframe_days(self) -> int:
        days = os.getenv('DEPLOYMENT_FREQ_TIMEFRAME_DAY')
        if not days:
            raise ValueError("DEPLOYMENT_FREQ_TIMEFRAME_DAY environment variable is not set.")
        
        return int(days)
        

    def _load_environment_variables(self):
        self.secret_store_name = os.getenv('SECRET_STORE_NAME')
        if not self.secret_store_name:
            raise ValueError("SECRET_STORE_NAME environment variable is not set.")
        

    def _initialize_secrets_manager_client(self):
        try:
            self.secrets_manager_client = boto3.client('secretsmanager')
            if self.secrets_manager_client is None:
                raise ValueError("Failed to initialize AWS Secrets Manager client.")
        except Exception as e:
            raise ValueError(f"Failed to initialize AWS Secrets Manager client: {str(e)}")
        

    def _fetch_secret(self):
        try:
            response = self.secrets_manager_client.get_secret_value(SecretId=self.secret_store_name)
        except Exception as e:
            raise e
        if 'SecretString' not in response:
            raise ValueError("Secret token not found in Secrets Manager.")
        
        return response['SecretString']

    def _extract_value_from_secret(self, secret_str, key):
        secret_dict = json.loads(secret_str)
        if key not in secret_dict:
            raise ValueError(f"{key} not found in the secret.")
        return secret_dict[key]
