
from src.event_processor.params.simple_authenticator import SimpleAuthenticator


class TestSimpleAuthenticator:

    def test_is_unautherized(self):

        event_processor = SimpleAuthenticator("SECRET_TOKEN")

        res = event_processor.is_autherized("INVALID_TOKEN")

        assert res == False, "is_autherized() should return False when no auth token is provided."

    def test_is_autherized(self):

        event_processor = SimpleAuthenticator("SECRET_TOKEN")

        res = event_processor.is_autherized("SECRET_TOKEN")

        assert res == True, "is_autherized() should return True when correct auth token is provided."
