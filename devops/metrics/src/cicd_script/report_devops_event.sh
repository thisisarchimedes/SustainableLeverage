#!/bin/bash

# Constants
EVENT_TYPES=("push" "deploy" "test_pass", "test_run")

# Function to get the target URL from environment variable
get_target_url() {
    local target_url="$API_DEVOPS_EVENT_CATCHER"
    if [ -z "$target_url" ]; then
        echo "API_DEVOPS_EVENT_CATCHER environment variable is not set."
        exit 1
    fi
    echo "$target_url"
}

# Function to get the secret token from environment variable
get_secret_token() {
    local secret_token="$DEVOPS_EVENTS_SECRET_TOKEN"
    if [ -z "$secret_token" ]; then
        echo "DEVOPS_EVENTS_SECRET_TOKEN environment variable is not set."
        exit 1
    fi
    echo "$secret_token"
}

# Function to check if the event type is valid
is_valid_event_type() {
    local event="$1"
    for type in "${EVENT_TYPES[@]}"; do
        if [ "$event" == "$type" ]; then
            return 0
        fi
    done
    return 1
}

# Main function
main() {
    # Load environment variables if .env file exists
    if [ -f ".env" ]; then
        export $(cat .env | xargs)
    fi

    # Parsing CLI arguments
    repo_name="$1"
    event="$2"
    metadata="$3"

    # Validate input
    if [ -z "$repo_name" ] || [ -z "$event" ]; then
        echo "Usage: $0 <repo_name> <event> [metadata]"
        exit 1
    fi

    if ! is_valid_event_type "$event"; then
        echo "Invalid event type. Must be one of: ${EVENT_TYPES[*]}"
        exit 1
    fi

    # Prepare record
    record=$(jq -n \
                --arg repoName "$repo_name" \
                --arg event "$event" \
                --arg metadata "$metadata" \
                '{Repo: $repoName, Event: $event, Metadata: $metadata}')

    # Get target URL and secret token
    target_url=$(get_target_url)
    secret_token=$(get_secret_token)

    # Post event
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$target_url" \
                   -H "Content-Type: application/json" \
                   -H "X-Secret-Token: $secret_token" \
                   -d "$record")

    # Check response
    if [ "$response" -eq 200 ]; then
        echo "Event logged successfully."
    else
        echo "Event logging failed. Status code: $response"
    fi
}

# Run main function with passed arguments
main "$@"
