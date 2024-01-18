#!/usr/bin/env bash

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo   "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
 "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

pip install --no-cache-dir -r requirements.txt
sudo apt-get install awscli -y

cd ~
sudo docker build --no-cache -t devops-event-processor . -f script/Dockerfile

(crontab -l 2>/dev/null; echo "@reboot /home/ubuntu/script/run_container.sh >> /home/ubuntu/script/logfile.log 2>&1") | crontab -
