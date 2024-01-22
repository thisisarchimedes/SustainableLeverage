const axios = require('axios');
require('dotenv').config();

const EVENT_TYPES = ['push', 'deploy', 'test_pass', 'test_run'];

class DevOpsEventReporter {
    constructor(targetUrl, secretToken = "") {
        this.targetUrl = targetUrl;
        this.secretToken = secretToken;
    }

    parseCliArguments() {
        const args = process.argv.slice(2);
        const repoName = args[0];
        const event = args[1];
        const metadata = args[2] || "";

        if (!EVENT_TYPES.includes(event)) {
            throw new Error(`The event must be one of: ${EVENT_TYPES.join(', ')}`);
        }

        return { repoName, event, metadata };
    }

    prepareRecord(repoName, event, metadata) {
        return {
            Repo: repoName,
            Event: event,
            Metadata: metadata
        };
    }

    async postEvent(record) {
        const headers = {
            'X-Secret-Token': this.secretToken,
            'Content-Type': 'application/json'
        };
    
        try {
            const response = await axios.post(this.targetUrl, record, { headers });
            return response;
        } catch (error) {
            console.error("Error in postEvent:", error);
            return { status: error.response ? error.response.status : 500, data: error.response ? error.response.data : 'Internal Server Error' };
        }
    }
    
}

async function main() {
    const targetUrl = getTargetUrl();
    const secretToken = getSecretToken();
    const eventReporter = new DevOpsEventReporter(targetUrl, secretToken);

    const args = eventReporter.parseCliArguments();
    const record = eventReporter.prepareRecord(args.repoName, args.event, args.metadata);
    const response = await eventReporter.postEvent(record);

    if (response && response.status === 200) {
        console.log("Event logged successfully.");
    } else {
        console.log(`Event logging failed. Status: ${response ? response.status : 'N/A'}, Data: ${response ? response.data : 'N/A'}`);
    }
}


function getTargetUrl() {
    const targetUrl = process.env.API_DEVOPS_EVENT_CATCHER;
    if (!targetUrl) {
        throw new Error("API_DEVOPS_EVENT_CATCHER environment variable is not set.");
    }
    return targetUrl;
}

function getSecretToken() {
    const secretToken = process.env.DEVOPS_EVENTS_SECRET_TOKEN;
    if (!secretToken) {
        throw new Error("DEVOPS_EVENTS_SECRET_TOKEN environment variable is not set.");
    }
    return secretToken;
}

main();
