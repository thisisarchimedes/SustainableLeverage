
from src.event_processor.events.factory_event import FactoryEvent


class PayloadValidator:

    MAX_PAYLOAD_SIZE = 2048
    
    def is_payload_valid(self, payload: dict) -> bool:

        if payload is None:
            return False
        
        if len(payload) == 0:
            return False

        if len(payload) > self.MAX_PAYLOAD_SIZE:
            return False      

        if 'Repo' not in payload:
            return False

        if 'Event' not in payload:
            return False
        
        # valdiate event type without returning error to potential external caller
        return FactoryEvent.is_event_type_valid(payload['Event'])
        