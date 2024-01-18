
from src.event_processor.params.config_local import ConfigLocal


class TestConfigLocal:

    def test_get_expected_auth_token(self):

        config = ConfigLocal()
        expected_auth_token = config.get_expected_auth_token()

        assert expected_auth_token == "secret_token_123"

    def test_get_logger_api_key(self):

        config = ConfigLocal()
        logger_api_key = config.get_logger_api_key()

        assert len(logger_api_key) > 10

    def test_get_db_name(self):

        config = ConfigLocal()
        db_name = config.get_db_name()

        assert db_name == "DORAStats"

    def test_get_db_table_name(self):

        config = ConfigLocal()
        db_name = config.get_db_table_name()

        assert db_name == "DORARawEventsTest"

    def test_get_deploy_frequency_days(self):

        config = ConfigLocal()
        days = config.get_deployment_freq_timeframe_days()

        assert days > 14
