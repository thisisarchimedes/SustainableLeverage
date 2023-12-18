import os

# Load the TOML configuration file
with open("foundry.toml", "r") as file:
    config_lines = file.readlines()

# Get the TENDERLY_KEY environment variable
tenderly_key = os.getenv("API_KEY_TENDERLY", "default_value_if_not_set")

# Replace 'TENDERLY_KEY' in the etherscan section with the environment variable
updated_config_lines = []
for line in config_lines:
    if 'key=API_KEY_TENDERLY' in line:
        updated_config_lines.append(line.replace('API_KEY_TENDERLY', f'"{tenderly_key}"'))
    else:
        updated_config_lines.append(line)

# Save the updated configuration back to the file
with open("foundry.toml", "w") as file:
    file.writelines(updated_config_lines)

print("Updated foundry.toml with TENDERLY_KEY environment variable.")
