#!/bin/bash
echo *******Updating respositories*******
sleep 2
apt-get update
echo *******Installing IPerf3*******
sleep 2
apt-get install iperf3 -y
echo *******Installing RSSH for RCP Pulls*******
sleep 2
apt-get install rssh -y
echo *******Installing PIP for Flask Installation*******
sleep 2
apt-get install python-pip
echo *******Installing Flask*******
sleep 2
pip install flask
echo *******Setup complete*******
sleep 2
