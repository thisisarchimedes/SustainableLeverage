#!/bin/bash

# Expect two arguments: BEFORE_SHA and AFTER_SHA
BEFORE_SHA=$1
AFTER_SHA=$2

# Check if both arguments are provided
if [ -z "$BEFORE_SHA" ] || [ -z "$AFTER_SHA" ]; then
    echo "Usage: $0 <before_sha> <after_sha>"
    exit 1
fi

# Get commit SHAs, skip the first one and save to a bash array
IFS=$'\n' read -r -d '' -a commit_array < <(git log --pretty=format:"%H" "$BEFORE_SHA..$AFTER_SHA" | tail -n +2 && printf '\0')

# Initialize JSON array
json_array="["

# Add each SHA to the JSON array
for sha in "${commit_array[@]}"; do
    json_array+="\"$sha\","
done

# Remove the last comma and close the JSON array bracket
json_array="${json_array%,}]"

# Output the JSON array
echo "$json_array"
