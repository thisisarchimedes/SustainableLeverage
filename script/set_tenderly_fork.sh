#! /bin/bash

curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Access-Key: $TENDERLY_API_KEY" \
  -d '{
        "network_id": "1",
        "chain_config": {
          "chain_id": 1337
        }
      }' \
  https://api.tenderly.co/api/v1/account/ArchimedesFinance/project/cicd/fork
