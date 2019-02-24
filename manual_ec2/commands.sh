#! /bin/bash
set -u
set -e

INSTANCE_URL=$1

ssh -o StrictHostKeyChecking=no -i "~/.aws/my-itce-mac-keypair.pem" ubuntu@$INSTANCE_URL <<EOF
sudo apt-get update
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt-get install -y nodejs git
git clone https://github.com/acouette/FractalJS.git
cd FractalJS
npm i
npm run http-build
node dist/js/node/http/server.js
EOF
