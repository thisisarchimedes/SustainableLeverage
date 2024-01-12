
class SimpleAuthenticator():

    def __init__(self, secret: str) -> None:
        self.secret = secret

    def is_autherized(self, token: str) -> bool:

        if token == self.secret:
            return True
        
        return False
    