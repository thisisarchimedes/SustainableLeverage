# DevOps Toolkit: Metrics

A service that accepts DevOps events (like: push to Github, Deploy etc..), store them and process them. It also sends the data to logger and dashboard (NewRelic).
- **cicd_script:** A script that runs on the CI/CD pipeline and sends the events to the service.
- **event_processor:** The backend service.

More info in our [internal Notion](https://www.notion.so/archimedesfi/Adding-DevOps-Metric-to-a-Repo-721c4732e115437dbb4926a821e565c8?pvs=4)

## Table of Contents

- [Quick Start](#quick-start)
    - [In your CICD script](#in-your-cicd-script)
    - [Run the backend service locally](#run-the-backend-service-locally)
- [Production Backend](#production-backend)
    - [Components](#components)
    - [Files and Directories](#files-and-directories)
    - [Deploy the backend](#deploy-the-backend)
- [Tests](#tests)
- [Incomming webhooks](#incomming-webhooks)
    - [Netlify deploy](#netlify-deploy)
    

## Quick Start

### In your CICD script

1. Define environment variable
```bash
export API_DEVOPS_EVENT_CATCHER="http://127.0.0.1:8000/process-event" # The URL of the backend service
export DEVOPS_EVENTS_SECRET_TOKEN="..." # The secret token that is used to authenticate with the backend service
```

2. Call the script with the relevant parameters
```bash
python report_devops_event.py <Repo name> <Event> --metadata <Metadata>
OR
node report_devops_event.js <Repo name> <Event> --metadata <Metadata>
OR
./report_devops_event.sh <Repo name> <Event> <Metadata>

```

- _Repo name_: The name of the repo that the event is related to or ALL if the event is not related to a specific repo.
- _Event_: The event name (script is doing validation on the event name) - 'push', 'deploy', 'test_pass'.
- _Metadata_: Optional. A string with additional data about the event.

3. Verify we got the event in NewRelic

NewRelic Query: `service:"devops-metrics"` 


## Run the backend service locally

1. Install dependencies

```bash
pip install -r requirements.txt
```

2. Configre AWS access

```bash
aws configure
```
* `pip install awscli` (if needed)

3. Define environment variable

```bash
DEVOPS_EVENTS_SECRET_TOKEN=""
LOGGER_API_KEY=""
DEVOPS_DB_NAME="DORAStats"
DEVOPS_TABLE_NAME="DORARawEventsTest"
DEPLOYMENT_FREQ_TIMEFRAME_DAY=30
```

4. Run the service with a flask dev server

```bash
python event_processor/entry_flask.py
```

## Production Backend

The production backend runs a Docker container on an EC2 instance. The container is running a flask server with gunicorn and listens to port 8000.

### Components

Events are sent to the backend and stored both in the DB and NewRelic.

_AWS Components:_
- **AWS Region**: us-east-1
- **AWS Timeseries DB**: Stores the events data.
    - **Database**: DORAStats
    - **Table**: DORARawEvents (test: DORARawEventsTest)
- **AWS Secrets Manager**: Stores the secret token (Name: DevOpsSecretStore).

_External Components:_
- **New Relic**: Logging an reporting


_Event structure:_

```json
{
    "Time": Event timestamp,
    "Repo": Repo name,
    "Event": push/deploy/test_pass,
    "Metadata": <Optional>
}
```
Example:
```json
{
    "Time": "2021-01-01 00:00:00",
    "Repo": "test_repo",
    "Event": "push",
    "Metadata": "{test_metadata: value}"
}
```

Supported events
- push
- deploy
- test_pass
- calc_deployment_freq (internal event - calculated by the BE and sent to logs and DB - not part of CICD script)

### Files and Directories

- **build_devops_ec2.tf**: Terraform script that creates the EC2 instance and the relevant security groups.
- **requirements.txt**: Python dependencies.
- **.env**: Environment variables that are used by the backend service.
- **DevOps.pem**: AWS certificate that is used to connect to the EC2.

- **script/build_container.sh**: Used by the TF script to  builds the Docker image and pushes it to EC2.
- **script/run_container.sh**: Run every time the EC2 is rebooted. Runs the Docker container (set in cron).
- **script/Dockerfile**: Dockerfile that builds the Docker image.
- **script/entry_point.sh**: Script that runs inside the Docker container, set some environment variables and starts the gunicorn server.

- **src/event_processor/**: Python code of the backend service.

### Deploy the backend

1. Create .env file with the relevant environment variables - it will be copied to the Docker and run on the EC2.

.env file content:
```bash
DEVOPS_EVENTS_SECRET_TOKEN=""
LOGGER_API_KEY=""
DEVOPS_DB_NAME="DORAStats"
DEVOPS_TABLE_NAME="DORARawEventsTest"
DEPLOYMENT_FREQ_TIMEFRAME_DAY=30
API_DEVOPS_EVENT_CATCHER=""
SECRET_STORE_NAME=""
AWS_DEFAULT_REGION=""
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
```

2. Get the AWS certificate

We currently use: DevOps.pem (check our internal Notion).

3. Run Terraform from the project root directory

```bash
terraform init
terraform plan
terraform apply
```

## Tests

We are using pytest for testins. See `test/` directory for tests.
```bash
python -m pytest test/ -s
```

## Incomming webhooks

### Netlify deploy

Netlify send a webhook on a successful deploy. We use it to calculate the deployment frequency.
We catch the event with a Lambda function and send it to the backend service.

Deploy the Lambda function:
1. Change role in `src/webhook_catchers/netlify/`
2. Run `src/webhook_catchers/netlify/deploy_lambda.sh`

