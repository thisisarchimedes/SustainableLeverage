import requests
import os
import sys


def get_block_number():
    fork_url = "http://localhost:8545" #THE_FORK_URL
    res = requests.post(
        url=fork_url,
        json={
            "jsonrpc": "2.0",
            "method": "eth_blockNumber",
            "params": [],
            "id": 67,
        },
    )

    return res.json()["result"]


def main():
    print(get_block_number())



__name__ == "__main__" and main()
