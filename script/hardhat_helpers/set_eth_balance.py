import requests
import os
import sys


def set_eth_balance_of_address(address, amount):
    fork_url = "http://localhost:8545" #THE_FORK_URL
   
    requests.post(
        url=fork_url,
        json={
            "jsonrpc": "2.0",
            "method": "hardhat_setBalance",
            "params": [address, amount],
            "id": 67,
        },
    )


def main():
    args = sys.argv[1:]
    return set_eth_balance_of_address(*args)


__name__ == "__main__" and main()