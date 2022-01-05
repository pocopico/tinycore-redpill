# tinycore-redpill
This is a testing version. Do not use unless you are certain you have no data to lose.

# Instructions 

A normal build process would start with :

 

1. Image burn

a. For physical gunzip and burn img file to usb stick
b. For virtual gunzip and use the provided vmdk file 

2. Boot tinycore

3. ssh to your booted loader or just open the desktop terminal 

4. Bring over your json files (global_config.json,custom_config.json, user_config.json )

5. Check the contents of user_config.json, if satisfied keep or else run :

a. Change you serial and mac address by running ./rploader.sh serialgen DS3615xs
b. Update user_config.json with your VID:PID of your usb stick by running ./rploader.sh identifyusb now
c. Update user_config.json with your SataPortMap and DiskIdxMap by running ./rploader.sh satamap now (needs testing)

d. Backup your changes to local loader disk by running  ./rploader.sh backup now

6. ./rploader.sh build bromolow-7.0.1-42218
