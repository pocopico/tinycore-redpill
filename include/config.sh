#!/bin/sudo bash

HOMEPATH="/home/tc"
TEMPPAT="${HOMEPATH}/temppat"
CONFIGFILES="${HOMEPATH}/redpill-load/config"
PATCHEXTRACTOR="${HOMEPATH}/patch-extractor"
THISURL="index.sh"
BUILDLOG="/home/tc/html/buildlog.txt"
USERCONFIGFILE="/home/tc/user_config.json"
TOOLSPATH="https://raw.githubusercontent.com/pocopico/tinycore-redpill/develop/tools/"
TOOLS="bspatch bzImage-to-vmlinux.sh calc_run_size.sh crc32 dtc kexec ramdisk-patch.sh vmlinux-to-bzImage.sh xxd zimage-patch.sh kpatch zImage_template.gz"
