#!/bin/bash
platform="$1"
modextension="https://github.com/pocopico/rp-ext/raw/main/rpext-index.json"


        MODULE_ALIAS_FILE="modules.alias.4.json"


function listextension() {

  if [ ! -f rpext-index.json ]; then
#    curl --insecure --progress-bar --location ${modextension} --output rpext-index.json
	echo "rpext-index.json not found"
  fi

  ## Get extension author rpext-index.json and then parse for extension download with :
  #       jq '. | select(.id | contains("vxge")) .url  ' rpext-index.json

  if [ ! -z $1 ]; then
    echo "Searching for matching extension for $1"
    matchingextension="$(jq -r -e ". | select(.id | endswith(\"${1}\")) .url  " rpext-index.json)"

    if [ ! -z "$matchingextension" ]; then
      echo "Found matching extension : "
      echo $matchingextension
      echo "Adding extension "
      /home/tc/tools/extmgr.sh extadd $matchingextension $platform
    fi

    extensionslist+="${matchingextension} "
    #echo $extensionslist
  else
    echo "No matching extension"
  fi

}

function matchpciidmodule() {

  vendor="$(echo $1 | sed 's/[a-z]/\U&/g')"
  device="$(echo $2 | sed 's/[a-z]/\U&/g')"

  pciid="${vendor}d0000${device}"

  #jq -e -r ".modules[] | select(.alias | test(\"(?i)${1}\")?) |   .name " modules.alias.json
  # Correction to work with tinycore jq
  matchedmodule=$(jq -e -r ".modules[] | select(.alias | contains(\"${pciid}\")?) | .name " $MODULE_ALIAS_FILE)

  # Call listextensions for extention matching

  echo "$matchedmodule"

  listextension $matchedmodule

}

function listpci() {

  lspci -n | while read line; do

    bus="$(echo $line | cut -c 1-7)"
    class="$(echo $line | cut -c 9-12)"
    vendor="$(echo $line | cut -c 15-18)"
    device="$(echo $line | cut -c 20-23)"

    #echo "PCI : $bus Class : $class Vendor: $vendor Device: $device"
    case $class in
    0100)
      echo "Found SCSI Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
      ;;
    0106)
      echo "Found SATA Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
      ;;
    0101)
      echo "Found IDE Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
      ;;
    0107)
      echo "Found SAS Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
      ;;
    0200)
      echo "Found Ethernet Interface : pciid ${vendor}d0000${device} Required Extension : $(matchpciidmodule ${vendor} ${device})"
      ;;
    0300)
      echo "Found VGA Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
      ;;
    0c04)
      echo "Found Fibre Channel Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
      ;;
    esac
  done

}

function listmodules() {

  if [ ! -f $MODULE_ALIAS_FILE ]; then
    echo "Creating module alias json file"
    getmodaliasfile >modules.alias.4.json
  fi

  echo -n "Testing $MODULE_ALIAS_FILE -> "
  if $(jq '.' $MODULE_ALIAS_FILE >/dev/null); then
    echo "File OK"
    echo "------------------------------------------------------------------------------------------------"
    echo -e "It looks that you will need the following modules : \n\n"
    listpci
    echo "------------------------------------------------------------------------------------------------"
  else
    echo "Error : File $MODULE_ALIAS_FILE could not be parsed"
  fi

}

listmodules


