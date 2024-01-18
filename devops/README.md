# DevOps

This repo intends to be cloned with all other production repo. It provides a set of tools to monitor DevOps metrics we care about (like time it takes for a PR test to complete). This is always a work in progress, and we add and remove metrics as we go

## How to use independently

### Prerequisites

Create a `.env` file with the following variables

```bash
NEW_RELIC_API_KEY="..."
```

Create a virtual environment and install the requirements

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
source .env
```

### Run the script

```bash
python3 src/report_new_relic.py repo_name action is_successful time_in_seconds
```

### Check New Relic

```SQL
SELECT `message` FROM Log WHERE `service` = 'DevOps' SINCE 12 hours ago
```

## How to use in a repo

- Add a submodule to the repo: `git submodule add https://github.com/thisisarchimedes/devops devops`

- Make sure you are using this repo as a submodule in your repo
- Make sure you have the need variables in your `.env` file
- Make sure you set up Github Actions Secrets with the same variables
- Add to Github Action script - here is an example:

Add NEW_RELIC_API_KEY to Github Actions Secrets and expose it to Github Actions script
```yaml
env:
  NEW_RELIC_API_KEY: ${{ secrets.NEW_RELIC_API_KEY }}
```
Then, add the following to the Github Actions script
```yaml
    - name: "Run the tests"
        run: |
            start=$(date +%s)
            
            forge test
            
            end=$(date +%s)
            duration=$((end-start))
            echo "DURATION=$duration" >> $GITHUB_ENV
            echo "Time taken to run the script: $duration seconds"
                
    - name: "Report DevOps Metrics"
        run: |
            echo "Time taken to run the script: ${{ env.DURATION }} seconds"
            python ~/devops/src/report_new_relic.py ${{ github.repository }} "PR Test" "true" ${{ env.DURATION }}
```

You might need to add Python support to the Github Actions script
    
```yaml
    - name: "Prepare Python environment"
      uses: actions/setup-python@v4
      with:
        python-version: "3.10"

    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r ~/devops/requirements.txt
```

# Expected log formation

Here is an example of a log item
```json
{
    info.action:"PR Test"
    info.repo:"thisisarchimedes/SustainableLeverage"
    info.test_pass:"true"
    info.test_time_seconds:"40"
    message:"DevOps Event: thisisarchimedes/SustainableLeverage"
    service:"DevOps"
    timestamp:1703262871412
}
```

Current supported info.action:
- "PR Test": when a PR test is run
