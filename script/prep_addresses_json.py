import json
import os

# Path to the deployments JSON and the output directory
deployments_json_path = 'deployments/deployments.json'
deployments_json_path_out = 'deployments/deployments_abis.json'
output_directory = 'out/'

# Read the deployments JSON
with open(deployments_json_path, 'r') as file:
    deployments = json.load(file)

# Iterate over each deployment and add the ABI
for deployment in deployments:
    contract_name = deployment['name']
    abi_path = os.path.join(output_directory, f"{contract_name}.sol", f"{contract_name}.json")

    if os.path.exists(abi_path):
        with open(abi_path, 'r') as abi_file:
            contract_data = json.load(abi_file)
            deployment['abi'] = contract_data['abi']

# Write the updated JSON back to the file
with open(deployments_json_path_out, 'w') as file:
    json.dump(deployments, file, indent=4)
