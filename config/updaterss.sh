#!/bin/bash

# This script is used to update the rss feed for the user

# Get the user's config file

for file in $(ls */*/config.json); do

    # Get the rss_server value

    rss_server="https://raw.githubusercontent.com/pocopico/redpill-load/develop/rss.xml"
    rss_server_ssl="https://raw.githubusercontent.com/pocopico/redpill-load/develop/rss.xml"
    rss_server_v2="https://raw.githubusercontent.com/pocopico/redpill-load/develop/rss.json"

    [ $(jq -re ".synoinfo.rss_server" $file) ] || echo "File : $file looks corrupted, please check it"

    [ $(jq -re ".synoinfo.rss_server" $file) != "$rss_server" ] && echo -n "File : $file, " && jsonfile=$(jq ".synoinfo+={\"rss_server\":\"$rss_server\"}" $file) && echo $jsonfile >$file && [ $(jq -re ".synoinfo.rss_server" $file) == "$rss_server" ] && echo -n "rss_server updated "
    [ $(jq -re ".synoinfo.rss_server_ssl" $file) != "$rss_server_ssl" ] && echo -n "File : $file, " && jsonfile=$(jq ".synoinfo+={\"rss_server_ssl\":\"$rss_server_ssl\"}" $file) && echo $jsonfile >$file && [ $(jq -re ".synoinfo.rss_server_ssl" $file) == "$rss_server_ssl" ] && echo -n "rss_server_ssl updated "
    [ $(jq -re ".synoinfo.rss_server_v2" $file) != "$rss_server_v2" ] && echo -n "File : $file, " && jsonfile=$(jq ".synoinfo+={\"rss_server_v2\":\"$rss_server_v2\"}" $file) && echo $jsonfile >$file && [ $(jq -re ".synoinfo.rss_server_v2" $file) == "$rss_server_v2" ] && echo "rss_server_v2 updated "

done
