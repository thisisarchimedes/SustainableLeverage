import requests
import os
import sys


def get_chain_id():    
    fork_url = "http://localhost:8545" #THE_FORK_URL

    res = requests.post(
        url=fork_url,
        json={
            "jsonrpc": "2.0",
            "method": "eth_chainId",
            "params": [],
            "id": 67,
        },
    )

    chain_id = res.json()["result"]

    # convert chain_id from hex to decimal
    return int(chain_id, 16)

def main():
    print(get_chain_id())



__name__ == "__main__" and main()
