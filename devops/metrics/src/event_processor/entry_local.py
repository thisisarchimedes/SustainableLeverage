from src.event_processor.params.config_local import ConfigLocal
from src.event_processor.process_new_event import process_new_event


def entry_point_local(event_payload: dict):
    
    process_new_event(event_payload, ConfigLocal())


