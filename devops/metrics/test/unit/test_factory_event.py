import pytest
from datetime import datetime, timedelta
import os
import pandas as pd

from src.event_processor.events.factory_event import FactoryEvent
from src.event_processor.database.db_connection_fake import DBConnectionFake

from src.event_processor.logger.event_logger_fake import EventLoggerFake


class TestFactoryEvent:

    def test_create_event(self):

        payload = {
            'Time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'Repo': 'test_repo',
            'Event': 'push',
            'Metadata': "{'test_metadata'}"
        }

        db_connection = DBConnectionFake(None, None)
        logger = EventLoggerFake()

        event_factory = FactoryEvent(db_connection, logger, 10)
        event = event_factory.create_event(payload)

        assert event is not None, "create_event() should return an event object."
        assert event.get_event_type(
        ) == 'push', "create_event() should return an event object with the correct event type."

    def test_process_test_pass_event(self):

        payload = {
            'Time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'Repo': 'test_repo',
            'Event': 'test_pass',
            'Metadata': '{time: 50}'
        }

        db_connection = DBConnectionFake(None, None)
        logger = EventLoggerFake()

        event_factory = FactoryEvent(db_connection, logger, 10)
        event = event_factory.create_event(payload)

        event.process()

        res_df = db_connection.get_repo_events("test_repo")

        metadata_value = str(res_df['Metadata'].iloc[len(res_df.index) - 1])
        assert metadata_value == "{time: 50}" , "process() should write the event to the database."
            
        event_value = str(res_df['Event'].iloc[len(res_df.index) - 1])
        assert event_value == str("test_pass") , "process() should write the event to the database."

        assert event.get_event_type() == 'test_pass', "process() should write the event to the database."


    def test_process_push_event(self):

        payload = {
            'Time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'Repo': 'test_repo',
            'Event': 'push',
        }

        db_connection = DBConnectionFake(None, None)
        logger = EventLoggerFake()

        event_factory = FactoryEvent(db_connection, logger, 10)
        event = event_factory.create_event(payload)

        event.process()

        res_df = db_connection.get_repo_events("test_repo")
        repo_name = str(res_df['Repo'].iloc[0])
        assert repo_name == str(
            payload['Repo']), "process() should write the event to the database."

        assert event.get_event_type() == 'push', "process() should write the event to the database."

    def test_process_calc_deploy_frequency_event(self):

        payload = {
            'Time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'Repo': 'test_repo',
            'Event': 'calc_deploy_frequency',
        }

        db_connection = DBConnectionFake(None, None)
        logger = EventLoggerFake()

        event_factory = FactoryEvent(db_connection, logger, 10)
        event = event_factory.create_event(payload)

        event.process()

        res_df = db_connection.get_repo_events("test_repo")
        repo_name = str(res_df['Repo'].iloc[0])
        assert repo_name == str(
            payload['Repo']), "process() should write the event to the database."

        assert event.get_event_type(
        ) == 'calc_deploy_frequency', "process() should write the event to the database."

    
    def test_process_deploy_event(self):

        payload = {
            'Time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'Repo': 'test_repo',
            'Event': 'deploy'
        }

        db_connection = DBConnectionFake(None, None)
        logger = EventLoggerFake()

        event_factory = FactoryEvent(db_connection, logger, 10)
        event = event_factory.create_event(payload)

        start_date = datetime.now() - timedelta(days=90)
        res_df = db_connection.get_deploy_frequency_events_since_date(
            start_date)
        num_rows_before = len(res_df.index)

        event.process()

        start_date = datetime.now() - timedelta(days=90)
        res_df = db_connection.get_deploy_frequency_events_since_date(
            start_date)
        num_rows_after = len(res_df.index)

        assert num_rows_after == num_rows_before + \
            1, "process() should write the event to the database."
        
    def test_process_calc_deploy_frequency_event(self):

        payload = {
            'Time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'Repo': 'test_repo',
            'Event': 'calc_deploy_frequency',
            'Metadata': '{"deploy_frequency": 12.5}'
        }

        db_connection = DBConnectionFake(None, None)
        logger = EventLoggerFake()

        event_factory = FactoryEvent(db_connection, logger, 10)
        event = event_factory.create_event(payload)

        start_date = datetime.now() - timedelta(days=90)
        res_df = db_connection.get_deploy_frequency_events_since_date(
            start_date)
        num_rows_before = len(res_df.index)

        event.process()

        start_date = datetime.now() - timedelta(days=90)
        res_df = db_connection.get_deploy_frequency_events_since_date(
            start_date)
        num_rows_after = len(res_df.index)

        assert num_rows_after == num_rows_before + \
            1, "process() should write the event to the database."
    