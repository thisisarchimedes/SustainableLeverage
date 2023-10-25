import requests
import os
import sys


def set_wbtc_balance_of_vault(storageSlot, wbtc_address, amount):
    aws_fork_url = os.environ["AWS_FORK_URL"]
    requests.post(
        aws_fork_url,
        json={
            "jsonrpc": "2.0",
            "method": "hardhat_setStorageAt",
            "params": [wbtc_address, storageSlot, amount],
            "id": 67,
        },
    )


def main():
    args = sys.argv[1:]
    return set_wbtc_balance_of_vault(*args)


__name__ == "__main__" and main()
