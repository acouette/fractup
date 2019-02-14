#! /bin/bash
echo "installing curl"
sudo apt-get install -y curl
sudo apt-get remove -y python-minimal
sudo apt-get install -y python-minimal:amd64
curl -sL https://deb.nodesource.com/setup_10.x | sudo bash -
sudo apt-get install -y nodejs
