import requests


def call_eth_call():
    # The line below automatiaclly updates by Github Actions using sed (this script is called via Foundry and doesn't have env vars)
    fork_url =  "http://localhost:8545"#THE_FORK_URL
    
     
    data = '0x313ce567'

    # Define the parameters for the eth_call method
    params = {
        'jsonrpc': '2.0',
        'method': 'eth_call',
        'params': [{'to': '0x06c4e1058a921022e412d3434E22Ca3EceB1684d', 'data': data}, 'latest'],
        'id': 1
    }
    res = requests.post(
        url=fork_url,
        json=params,
    )

    #return res.json()["result"]
    return res.json()

def main():
    print(call_eth_call())



__name__ == "__main__" and main()
