import requests
import os
import sys


def reset_node():
    # The line below automatiaclly updates by Github Actions using sed (this script is called via Foundry and doesn't have env vars)
    fork_url = "http://localhost:8545" #THE_FORK_URL
    requests.post(
        url=fork_url,
        json={
            "jsonrpc": "2.0",
            "method": "hardhat_reset",
            "params": [],
            "id": 67,
        },
    )


def main():
    return reset_node()


__name__ == "__main__" and main()
