#!/bin/bash

echo "$0 : Rebooting" | tee /home/tc/html/buildlog.txt
sudo /sbin/reboot -f | tee /home/tc/html/buildlog.txt


