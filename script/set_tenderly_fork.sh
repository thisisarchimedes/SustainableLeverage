#! /bin/bash

curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Access-Key: 2JbqTDp48aqgjcE9N2nUoYi8VtDy1eKk" \
  -d '{
        "network_id": "1",
        "chain_config": {
          "chain_id": 1337
        }
      }' \
  https://api.tenderly.co/api/v1/account/ArchimedesFinance/project/cicd/fork
