#!/bin/bash

statjson="/home/tc/html/status.json"
stages="buildstatus downloadtools iscached downloadingpat patextraction kernelpatch extadd ramdiskpatch ramdiskcreation copyfilestodisk frienddownload gengrub cachingpat checkloader cleanbuild finishloader"

msgstatus() {

  stage=$2
  status=$3
  msg=$4

  case $1 in
  false)
    echo -e "<tr class=\"bg-info\"><td>$stage</td><td class=\"text-info\">$status</td><td>$msg</td></tr>"
    ;;
  true)
    echo -e "<tr class=\"bg-success\"><td>$stage</td><td class=\"text-success\">$status</td><td>$msg</td></tr>"
    ;;
  fail)
    echo -e "<tr class=\"bg-danger\"><td>$stage</td><td class=\"text-danger\">$status</td><td>$msg</td></tr>"
    ;;
  warn)
    echo -e "<tr class=\"bg-warning\"><td>$stage</td><td class=\"text-warning\">$status</td><td>$msg</td></tr>"
    ;;
  *)
    echo -e "<tr class=\"bg-primary\"><td>$stage</td><td class=\"text-primary\">$status</td><td>$msg</td></tr>"
    ;;
  esac

}

function getstatus() {

  cat <<EOF
<table class="table table-hover table-dark table-sm"> 
<thead class="thead-dark">
<tr class="table-active">
<td class="text-active">$synomodel</td><td>$synoversion</td><td></td>
</tr>
<tr>
<th>Stage</th>
<th>Status</th>
<th>Message</th>
</tr>
</thead>
<tbody>
EOF

  for stage in $stages; do

    status=$(jq -re ".stage.${stage}.status" $statjson)
    stagetext=$(jq -re ".stage.${stage}.description" $statjson)
    statusmsg=$(jq -re ".stage.${stage}.message" $statjson)

    #echo "$status = $stage" >>status.log
    msgstatus "$status" "$stage" "$stagetext" "$statusmsg"

  done

  echo "</tbody>"
  echo "</table>"

}

function loaderstatus() {
  tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
  userconfigfile="/home/tc/user_config.json"
  synomodel="$(jq -re '.general.model' $userconfigfile)"
  synoversion="$(jq -re '.general.version' $userconfigfile)"
  redpillmake="$(jq -re '.general.redpillmake' $userconfigfile)"
  friendautoupd="$(jq -re '.general.friendautoupd' $userconfigfile)"
  hidesensitive="$(jq -re '.general.hidesensitive' $userconfigfile)"
  synoserial="$(jq -re '.extra_cmdline.model' $userconfigfile)"
  synomac="$(jq -re '.extra_cmdline.model' $userconfigfile)"
  usbvid="$(jq -re '.extra_cmdline.model' $userconfigfile)"
  usbpid="$(jq -re '.extra_cmdline.model' $userconfigfile)"
  sataportmap="$(jq -re '.extra_cmdline.model' $userconfigfile)"
  diskidxmap="$(jq -re '.extra_cmdline.model' $userconfigfile)"
  freehomespace="$(df -h /home/tc | grep -v Filesystem | awk '{print $4}')"
  freetcrpspace="$(df -h /mnt/$tcrppart | grep -v Filesystem | awk '{print $4}')"
  cat <<EOF
<table class="table table-hover table-sm>
<thead class="thead-dark">
<tr><th>User config file build parameters</th><th></th><th></th><th></th><th></th></tr>
<tr>
<th>Parameter</th><th>Value</th><th>Parameter</th><th>Value</th>
</tr>
</thead>
<tbody>
<tr class="table-active"><td class="text-info">Model</td><td class="text-info">$synomodel</td><td class="text-info">RedPill Make</td><td class="text-info">$redpillmake</td></tr>
<tr class="table-active"><td class="text-info">Version</td><td class="text-info">$synoversion</td><td class="text-info">Friend Auto Update</td><td class="text-info">$friendautoupd</td></tr>
<tr class="table-active"><td class="text-info">Serial</td><td class="text-info">$synoserial</td><td class="text-info">Hide Sensitive Info</td><td class="text-info">$hidesensitive</td></tr>
<tr class="table-active"><td class="text-info">Mac Address</td><td class="text-info">synomac</td><td class="text-info">Free Home Space</td><td class="text-info">$freehomespace</td></tr>
<tr class="table-active"><td class="text-info">Vid</td><td class="text-info">$usbvid</td><td class="text-info"></td><td class="text-info"></td></tr>
<tr class="table-active"><td class="text-info">Pid</td><td class="text-info">$usbpid</td><td class="text-info">Free TCRP Space</td><td class="text-info">$freetcrpspace</td></tr>
<tr class="table-active"><td class="text-info">SataPortMap</td><td class="text-info">$sataportmap</td><td class="text-info"></td><td class="text-info"></td></tr>
<tr class="table-active"><td class="text-info">DiskIdxMap</td><td class="text-info">$diskidxmap</td><td class="text-info"></td><td class="text-info"></td></tr>
</tbody>
</table>
EOF

}

function setstatus() {

  stage=$1
  status=$2
  msg=$3

  json=$(jq ".stage.${stage}.status = \"${status}\"" $statjson)
  echo $json | jq . >$statjson
  json=$(jq ".stage.${stage}.message = \"${msg}\"" $statjson)
  echo $json | jq . >$statjson

}

function clearstatus() {

  stages="$stages"

  cp $statjson ${statjson}.bak

  for stage in $stages; do

    json=$(jq ".stage.${stage}.status = \"warn\"" $statjson)
    echo $json | jq . >$statjson
    json=$(jq ".stage.${stage}.message = \" \"" $statjson)
    echo $json | jq . >$statjson
  done

}

function recreatejson() {

  cat <<EOF >$statjson
{
  "stage": {
    "buildstatus": {
      "description": "Building started",
      "status": "warn",
      "message": ""
    },
    "downloadtools": {
      "description": "Downloading extraction tools",
      "status": "warn",
      "message": ""
    },
    "iscached": {
      "description": "Caching pat file",
      "status": "warn",
      "message": ""
    },
    "downloadingpat": {
      "description": "Downloading pat file",
      "status": "warn",
      "message": ""
    },
    "patextraction": {
      "description": "Pat file extracted",
      "status": "warn",
      "message": ""
    },
    "kernelpatch": {
      "description": "Kernel patching",
      "status": "warn",
      "message": ""
    },
    "extadd": {
      "description": "Extensions collection",
      "status": "warn",
      "message": ""
    },
    "ramdiskpatch": {
      "description": "Ramdisk patching",
      "status": "warn",
      "message": ""
    },
    "ramdiskcreation": {
      "description": "Ramdisk creation",
      "status": "warn",
      "message": ""
    },
     "copyfilestodisk": {
      "description": "Copying all files to disk",
      "status": "warn",
      "message": ""
    },
    "frienddownload": {
      "description": "TCRP Friend downloading",
      "status": "warn",
      "message": ""
    },
    "gengrub": {
      "description": "Generating GRUB entries",
      "status": "warn",
      "message": ""
    },
    "cachingpat": {
      "description": "Caching pat file to disk",
      "status": "warn",
      "message": ""
    },
    "cleanbuild": {
      "description": "Cleaning build directory",
      "status": "warn",
      "message": ""
    },
    "checkloader": {
      "description": "Last loader checks",
      "status": "warn",
      "message": ""
    },
    "finishloader": {
      "description": "Loader build status",
      "status": "warn",
      "message": ""
    }
  }
}
EOF

}

case $1 in

clearstatus)
  clearstatus
  ;;
recreatejson)
  echo "recreating json"
  recreatejson
  ;;
status)
  getstatus
  ;;
setstatus)
  setstatus "$2" "$3" "$4"
  ;;
loaderstatus)
  loaderstatus
  ;;
*)
  getstatus
  ;;
esac
