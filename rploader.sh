#!/bin/bash
#
# Author : 
# Date : 22010502
# Version : 0.4.2
#
#
# User Variables :

rploaderver="0.4.2"
rploaderepo="https://github.com/pocopico/tinycore-redpill/raw/main/rploader.sh"

redpillextension="https://github.com/pocopico/rp-ext/raw/main/redpill/rpext-index.json"
modextention="https://github.com/pocopico/rp-ext/raw/main/rpext-index.json"

# END Do not modify after this line
######################################################################################################


function mountshare(){

    echo "smb user of the share, leave empty when you do not want to use one"
    read -r user

    echo "smb password of the share, leave empty when you do not want to use one"
    read -r password

    if [ -n "$user" ] && [ -z "$password" ]; then
        echo "u used a username, so we need a password too"
        echo "smb password of the share"
        read -r password
    fi

    echo "smb host ip or hostname"
    read -r server

    echo "smb shared folder. Start always with /"
    read -r share

    echo "local mount folder. Use foldername for the mount. This folder is created in /home/tc (default:/home/tc/mount)"
    read -r mountpoint

    if [ -z "$mountpoint" ] ; then
        echo "use /home/tc/mount folder, nothing was entered to use so we use the default folder"
        mountpoint="/home/tc/mount"

        if [ ! -d "$mountpoint" ]; then
            sudo mkdir -p "$mountpoint"
        fi
    else 
        sudo mkdir -p "$mountpoint"
    fi

    if [ -n "$user" ] && [ -n "$password" ]; then
        sudo mount.cifs "//$server$share" "$mountpoint" -o user="$user",pass="$password"
    else
        echo "No user/password given, mount without. Press enter"
        sudo mount.cifs "//$server$share" "$mountpoint"
    fi
}



function backup(){

loaderdisk=`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`
homesize=`du -sh /home/tc | awk '{print $1}'`

echo "Please make sure you are using the latest 1GB img before using backup option"
echo "Current /home/tc size is $homesize , try to keep it less than 1GB as it might not fit into your image"

echo "Should i update the $loaderdisk with your current files [Yy/Nn]"
	read answer
       if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ] ; then
       echo -n "Backing up home files to $loaderdisk : "
	        if filetool.sh -b ${loaderdisk}3 ; then 
	        echo ""
			else 
			echo "Error: Couldn't backup files"
			fi
       else
       echo "OK, keeping last status"
       fi 

}


function satamap(){

let controller=0
let diskidxmap=0

if [ "$MACHINE" = "VIRTUAL" ] && [ "$HYPERVISOR" = "VMware" ] ; then
echo "Running on VMware"
echo "Possible working solution"
echo "SataPortMap=1"
echo "DiskIdxMap=00"
else 
     for hba in `lsscsi -Hv |grep pci |grep -v usb | cut -c 44-50 | uniq`
     do
	     if [ `lsscsi -Hv |grep "$hba" | grep ata | wc -l` -gt 0 ] ; then 
         echo "HBA: $hba Disks : `lsscsi -Hv |grep "$hba" | wc -l`"
         lsscsi -Hv |grep "$hba" | wc -l >> satamap.$$
		 
		    if [ $controller = 0 ] ; then 
		    printf "%02X" $diskidxmap >> diskmap.$$
		    else 
		    let diskidxmap=$diskidxmap+`lsscsi -Hv |grep "$hba" | wc -l` ; printf "%02X" $diskidxmap >> diskmap.$$
		    fi 
			
		 else
		 
		      if [ `lsscsi -Hv | grep -B 2 $hba | head -1 | awk '{print $2}' |grep vmw |wc -l` -gt 0 ] ; then 
			  pcidev=`lsscsi -Hv | grep $hba | awk '{print $3}'`
		      echo "HBA: $hba Disks : `ls -ltrd ${pcidev}/target* | wc -l`"
		      ls -ltrd ${pcidev}/target* | wc -l >> satamap.$$
		         if [ $controller = 0 ] ; then 
		         printf "%02X" $diskidxmap >> diskmap.$$
		         else 
		         let diskidxmap=$diskidxmap+`lsscsi -Hv |grep "$hba" | wc -l` ; printf "%02X" $diskidxmap >> diskmap.$$
		         fi 
			  else 
		      pcidev=`lsscsi -Hv | grep $hba | awk '{print $3}'`
		      echo "HBA: $hba Disks : `ls -ltrd ${pcidev}/port* | wc -l`"
		      ls -ltrd ${pcidev}/port* | wc -l >> satamap.$$
		         if [ $controller = 0 ] ; then 
		         printf "%02X" $diskidxmap >> diskmap.$$
		         else 
		         let diskidxmap=$diskidxmap+`lsscsi -Hv |grep "$hba" | wc -l` ; printf "%02X" $diskidxmap >> diskmap.$$
		         fi 
			  fi
		 fi 
		 let controller=$controller+1
     done
     
     sataportmap=`cat satamap.$$ | tr -d '\n'`
     diskidxmap=`cat diskmap.$$ | tr -d '\n'`
     echo "SataPortMap=$sataportmap"
     echo "DiskIdxMap=$diskidxmap"
	 
	 
	echo "Should i update the user_config.json with these values ? [Yy/Nn]"
	read answer
       if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ] ; then
       sed -i "/\"SataPortMap\": \"/c\    \"SataPortMap\": \"$sataportmap\"," user_config.json
       sed -i "/\"DiskIdxMap\": \"/c\    \"DiskIdxMap\": \"$diskidxmap\"" user_config.json
       else
       echo "OK remember to update manually by editing user_config.json file"
       fi 
     
     rm satamap.$$
	 rm diskmap.$$
fi

}

function usbidentify(){

if [ "$MACHINE" = "VIRTUAL" ] && [ "$HYPERVISOR" = "VMware" ] ; then
echo "Running on VMware, no need to set USB VID and PID, you should SATA shim instead"
exit 0
fi 

if [ "$MACHINE" = "VIRTUAL" ] && [ "$HYPERVISOR" = "QEMU" ] ; then
echo "Running on QEMU, If you are using USB shim, VID 0x46f4 and PID 0x0001 should work for you"
vendorid="0x46f4"
productid="0x0001"
echo "Vendor ID : $vendorid Product ID : $productid"

echo "Should i update the user_config.json with these values ? [Yy/Nn]"
read answer
       if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ] ; then
       sed -i "/\"pid\": \"/c\    \"pid\": \"$productid\"," user_config.json
       sed -i "/\"vid\": \"/c\    \"vid\": \"$vendorid\"," user_config.json
       else
       echo "OK remember to update manually by editing user_config.json file"
       fi
exit 0
fi 


loaderdisk=`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`

lsusb -v  2>&1|grep -B 33 -A 1 SCSI > /tmp/lsusb.out


usblist=`grep -B 33 -A 1 SCSI   /tmp/lsusb.out`
vendorid=`grep -B 33 -A 1 SCSI  /tmp/lsusb.out |grep -i idVendor  | awk '{print $2}'`
productid=`grep -B 33 -A 1 SCSI /tmp/lsusb.out |grep -i idProduct | awk '{print $2}'`

if [ `echo $vendorid | wc -w` -gt 1 ] ; then
echo "Found more than one USB disk devices, please select which one is your loader on"
usbvendor=$(for item in $vendorid  ; do grep $item /tmp/lsusb.out |awk '{print $3}';done)
select usbdev in $usbvendor
do
vendorid=`grep -B 10 -A 10 $usbdev /tmp/lsusb.out |grep idVendor | grep $usbdev |awk '{print $2}'`
productid=`grep -B 10 -A 10 $usbdev /tmp/lsusb.out | grep -A 1 idVendor  | grep idProduct |  awk '{print $2}'`
echo "Selected Device : $usbdev , with VendorID: $vendorid and ProductID: $productid"
break
done
else
usbdevice="`grep iManufacturer /tmp/lsusb.out | awk '{print $3}'` `grep iProduct /tmp/lsusb.out | awk '{print $3}' ` SerialNumber: `grep iSerial /tmp/lsusb.out | awk '{print $3}'`"
fi

usbdevice="$usbdev  `grep -B 10 -A 10 $usbdev /tmp/lsusb.out | grep iProduct | awk '{print $3}'` Serial Number : `grep -B 10 -A 10 $usbdev /tmp/lsusb.out | grep iSerial | awk '{print $3}'`"


if [ -n "$usbdevice" ] && [ -n "$vendorid" ] && [ -n "$productid" ] ; then
echo "Found $usbdevice"
echo "Vendor ID : $vendorid Product ID : $productid"

echo "Should i update the user_config.json with these values ? [Yy/Nn]"
read answer
       if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ] ; then
       sed -i "/\"pid\": \"/c\    \"pid\": \"$productid\"," user_config.json
       sed -i "/\"vid\": \"/c\    \"vid\": \"$vendorid\"," user_config.json
       else
       echo "OK remember to update manually by editing user_config.json file"
       fi
else
echo "Sorry, no usb disk could be identified"
rm /tmp/lsusb.out
fi

}

function serialgen(){

	    if [ "$1" = "DS3615xs" ] || [ "$1" = "DS3617xs" ] || [ "$1" = "DS916+" ] || [ "$1" = "DS918+" ] || [ "$1" = "DS920+" ] || [ "$1" = "DVA3219" ] || [ "$1" = "DVA3221" ] ; then
        serial="$(generateSerial $1)"
		mac="$(generateMacAddress $1)"
		echo "Serial Number for Model : $serial"
		echo "Mac Address for Model $1 : $mac " 
		
        echo "Should i update the user_config.json with these values ? [Yy/Nn]"
        read answer
        if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ] ; then
        sed -i "/\"sn\": \"/c\    \"sn\": \"$serial\"," user_config.json
		macaddress=`echo $mac | sed -s 's/://g'`
        sed -i "/\"mac1\": \"/c\    \"mac1\": \"$macaddress\"," user_config.json
        else
        echo "OK remember to update manually by editing user_config.json file"
        fi 
		
		else
		echo "Error : $2 is not an available model for serial number generation. "
		echo "Available Models : DS3615xs DS3617xs DS916+ DS918+ DS920+ DVA3219 DVA3221"
		fi

}


function beginArray() {

case $1 in 


DS3615xs)
permanent="LWN"
serialstart="1130 1230 1330 1430"
;;
DS3617xs)
permanent="ODN"
serialstart="1130 1230 1330 1430"
;;
DS916+)
permanent="NZN"
serialstart="1130 1230 1330 1430"
;;
DS918+)
permanent="PDN"
serialstart="1780 1790 1860 1980"
;;
DS920+)
permanent="SBR"
serialstart="2030 2040 20C0 2150"
;;
DVA3219)
permanent="RFR"
serialstart="1930 1940"
;;
DVA3221)
permanent="SJR"
serialstart="2030 2040 20C0 2150"
;;

esac

}


function random() {
     	 printf "%06d" $(($RANDOM %30000 +1 ))
}
function randomhex() {
     val=$(( $RANDOM %255 +1)) 
     echo "obase=16; $val" | bc
}

function generateRandomLetter() {
	 for i in a b c d e f g h j k l m n p q r s t v w x y z
	 do echo $i
	 done | sort -R|tail -1
}


function generateRandomValue() {
	 for i in 0 1 2 3 4 5 6 7 8 9 a b c d e f g h j k l m n p q r s t v w x y z
	 do echo $i
	 done | sort -R|tail -1
}

function toupper() {

echo $1 | tr '[:lower:]' '[:upper:]'

}


function generateMacAddress() {

#toupper "Mac Address: 00:11:32:$(randomhex):$(randomhex):$(randomhex)"
printf '00:11:32:%02X:%02X:%02X' $[RANDOM%256]  $[RANDOM%256]  $[RANDOM%256]

}

function generateSerial(){

	beginArray $1

	case $1 in 

DS3615xs)
serialnum="`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(random)	
;;
DS3617xs)
serialnum="`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(random)	
;;
DS916+)
serialnum="`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(random)	
;;
DS918+)
serialnum="`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(random)	
;;
DS920+)
serialnum=$(toupper "`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
;;
DVA3219)
serialnum=$(toupper "`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
;;
DVA3221)
serialnum=$(toupper "`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
;;

esac

	echo $serialnum

}




function prepareforcompile() {

    echo "Downloading required build software "
    tce-load -wi git compiletc coreutils bc perl5 openssl-1.1.1-dev

    if [ ! -d /lib64 ] ; then 
        sudo ln -s /lib /lib64
    fi
    if [ ! -f /lib64/libbz2.so.1 ] ; then 
        sudo ln -s /usr/local/lib/libbz2.so.1.0.8 /lib64/libbz2.so.1
    fi

}

function gettoolchain() {

    if [ -d  /usr/local/x86_64-pc-linux-gnu/ ] ; then
        echo "Toolchain already cached"
        return
    fi

    cd /home/tc 

    if [ -f dsm-toolchain.7.0.txz ] ; then
        echo "File already cached"
    else 
        echo "Downloading and caching toolchain"
        curl --progress-bar --location "${TOOLKIT_URL}" --output dsm-toolchain.7.0.txz
    fi

    echo -n "Checking file -> "
    checkfilechecksum dsm-toolchain.7.0.txz ${TOOLKIT_SHA}
    echo "OK, file matches sha256sum, extracting"
    cd / && sudo tar -xf /home/tc/dsm-toolchain.7.0.txz usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build
    if [ $? = 0 ] ; then
        return
    else 
        echo "Failed to extract toolchain"
    fi

}


function getPlatforms() {

    platform_versions=`jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' global_config.json custom_config.json  | jq -r '.build_configs[].id' `
    echo "$platform_versions"

}

function selectPlatform() {

    platform_selected=`jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' global_config.json custom_config.json | jq ".build_configs[] | select(.id==\"${1}\")"`

}
function getValueByJsonPath() {

    local JSONPATH=${1}
    local CONFIG=${2}
    jq -c -r "${JSONPATH}"<<<${CONFIG}

}

function readConfig() {

    if [ ! -e custom_config.json ]; then
        cat global_config.json
    else
        jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' global_config.json custom_config.json
    fi

}

function getsynokernel() {

    if [ -d  /home/tc/linux-kernel ] ; then
        if [ -f /home/tc/linux-kernel/synoconfigs/${TARGET_PLATFORM} ] ; then 
            echo "Synokernel already cached"
            return
        else 
            echo "Synokernel is cached but does not match the required sources"
            rm -rf /home/tc/linux-kernel
            rm -rf synokernel.txz
        fi
    fi

    cd /home/tc 

    if [ -f synokernel.txz ] ; then
        echo -n "File already cached, checking file -> "
        checkfilechecksum synokernel.txz ${SYNOKERNEL_SHA}
        echo "OK, file matches sha256sum, extracting"
        tar xf /home/tc/synokernel.txz 
        mv `tar --exclude="*/*/*" -tf synokernel.txz | head -1` linux-kernel
        rm -rf synokernel.txz
    else
        echo "Downloading and caching synokernel"
        cd /home/tc && curl --progress-bar --location ${SYNOKERNEL_URL} --output synokernel.txz
        checkfilechecksum synokernel.txz ${SYNOKERNEL_SHA}
        echo "OK, file matches sha256sum, extracting"
        echo "Extracting synokernel"
        tar xf /home/tc/synokernel.txz
        mv `tar --exclude="*/*/*" -tf synokernel.txz | head -1` linux-kernel
        rm -rf synokernel.txz
    fi

}


function cleanloader() {

    echo "Clearing local redpill files"
    sudo rm -rf /home/tc/redpill*
    sudo rm -rf /home/tc/*tgz
    sudo rm -rf /home/tc/latestrploader.sh

}

function compileredpill() {

    cd /home/tc

    export DSM_VERSION=${TARGET_VERSION}
    export REDPILL_LOAD_SRC=/home/tc/redpill-load
    export REDPILL_LKM_SRC=/home/tc/redpill-lkm
    export LOCAL_RP_LOAD_USE=false
    export ARCH=x86_64
    export LOCAL_RP_LKM_USE=false

    echo "Compiling redpill with $COMPILE_METHOD"
    if [ "$COMPILE_METHOD" = "toolkit_dev" ] ; then
        export LINUX_SRC=/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build
        
    else
        export LINUX_SRC=/home/tc/linux-kernel
    fi

    cd redpill-lkm && make ${REDPILL_LKM_MAKE_TARGET} 
    strip --strip-debug /home/tc/redpill-lkm/redpill.ko
    modinfo /home/tc/redpill-lkm/redpill.ko
    REDPILL_MOD_NAME="redpill-linux-v`modinfo redpill.ko |grep vermagic | awk '{print $2}'`.ko"
    cp /home/tc/redpill-lkm/redpill.ko /home/tc/redpill-load/ext/rp-lkm/${REDPILL_MOD_NAME}

}


function checkfilechecksum() {

    local FILE="${1}"
    local EXPECTED_SHA256="${2}"
    local SHA256_RESULT=$(sha256sum ${FILE})
    if [ "${SHA256_RESULT%% *}" != "${EXPECTED_SHA256}" ];then
        echo "The ${FILE} is corrupted, expected sha256 checksum ${EXPECTED_SHA256}, got ${SHA256_RESULT%% *}"
        #rm -f "${FILE}"
        #echo "Deleted corrupted file ${FILE}. Please re-run your action!"
        echo "Please delete the file ${FILE} manualy and re-run your command!"
        exit 99
    fi

}



function tinyentry() {

cat << EOF
menuentry 'Tiny Core Image Build' {
        savedefault
        set root=(hd0,msdos3)
        echo Loading Linux...
        linux /vmlinuz64 loglevel=3 cde waitusb=5 vga=791
        echo Loading initramfs...
        initrd /corepure64.gz
        echo Booting TinyCore for loader creation
}
EOF

}


function showhelp() {
cat << EOF
$(basename ${0})

Version : $rploaderver
----------------------------------------------------------------------------------------
Usage: ${0} <action> <platform version> <static or compile module> [extension manager arguments]

Actions: build, ext, download, clean, update, listmod, serialgen, identifyusb, satamap, mountshare

- build:     Build the 💊 RedPill LKM and update the loader image for the specified 
             platform version and update current loader.
			 
- ext:       Manage extensions, options go after platform (add/force_add/info/remove/update/cleanup/auto)
			 
             example: 
             
             rploader.sh ext apollolake-7.0.1-42218 add https://raw.githubusercontent.com/pocopico/rp-ext/master/e1000/rpext-index.json
             
             or for auto detect use 
             
             rploader.sh ext apollolake-7.0.1-42218 auto 
			 
- download:  Download redpill sources only
			 
- clean:     Removes all cached files and starts over
			 
- update:    Checks github repo for latest version of rploader 
			 
- listmods:  Tries to figure out required extensions
			 
- serialgen: Generates a serial number and mac address for the following platforms 
             
             DS3615xs DS3617xs DS916+ DS918+ DS920+ DVA3219 DVA3221
			 
- identifyusb: Tries to identify your loader usb stick VID:PID and updates the user_config.json file 

- satamap: Tries to identify your SataPortMap and DiskIdxMap values and updates the user_config.json file 

- backup:   Backup and make changes /home/tc changed permanent to your loader disk

- mountshare: Mounts a remote CIFS working directory

Available platform versions:
----------------------------------------------------------------------------------------
$(getPlatforms)
----------------------------------------------------------------------------------------
Check global_settings.json for settings.
EOF

}


function checkinternet() {

    echo  -n "Checking Internet Access -> "
    nslookup github.com 2>&1 > /dev/null
    if [ $? -eq 0 ] ; then
        echo "OK"
    else
        echo "Error: No internet found, or github is not accessible"
        exit 99
    fi

}


function gitdownload() {

    cd /home/tc

    if [ -d redpill-lkm ] ; then
        echo "Redpill sources already downloaded, pulling latest"
        cd redpill-lkm ; git pull ; cd /home/tc
    else
        git clone "$LKM_SOURCE_URL"
    fi
    
    if [ -d redpill-load ] ; then
        echo "Loader sources already downloaded, pulling latest"
        cd redpill-load ; git pull ; cd /home/tc
    else
        git clone "$LD_SOURCE_URL"
    fi

}


#platform_versions=`jq -s '.[0].docker=(.[0].docker * .[1].docker) |.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' global_config.json custom_config.json  | jq '.build_configs[].id' `
#echo "Available versions : $platform_versions"




function getstaticmodule() {

    cd /home/tc

    extension=`curl -s --location "$redpillextension"`

    if [ "${TARGET_PLATFORM}" = "apollolake" ] ; then
        SYNOMODEL="ds918p_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "bromolow" ] ; then
        SYNOMODEL="ds3615xs_$TARGET_REVISION"
    fi

    echo "Looking for redpill for : $SYNOMODEL "

    #release=`echo $extension |  jq -r '.releases .${SYNOMODEL}_{$TARGET_REVISION}'`
    release=`echo $extension |  jq -r -e --arg SYNOMODEL $SYNOMODEL '.releases[$SYNOMODEL]'`
    files=`curl -s --location "$release" | jq -r '.files[] .url'`

    for file in $files; do
        echo "Getting file $file"
        curl -s -O $file
        if [ -f redpill*.tgz ]; then
            echo "Extracting module"
            tar xf redpill*.tgz
            rm redpill*.tgz 
            strip --strip-debug redpill.ko
        fi
    done

    REDPILL_MOD_NAME="redpill-linux-v`modinfo redpill.ko |grep vermagic | awk '{print $2}'`.ko"

    cp /home/tc/redpill.ko /home/tc/redpill-load/ext/rp-lkm/${REDPILL_MOD_NAME}

}


function buildloader() {

    cd /home/tc 
	
    echo -n "Checking user_config.json : "
    if jq -s . user_config.json > /dev/null ; then
    echo "Done"
    else
    echo "Error : Problem found in user_config.json"
    exit 99
    fi
	

    curl -s --progress-bar --location https://packages.slackonly.com/pub/packages/14.1-x86_64/development/bsdiff/bsdiff-4.3-x86_64-1_slack.txz --output bsdiff.txz
    cd /
    sudo tar xf /home/tc/bsdiff.txz
    rm -rf /home/tc/bsdiff.txz

    if [ ! -d /lib64 ] ; then
        sudo ln -s /lib /lib64 
    fi
    if [ ! -f /lib64/libbz2.so.1 ] ; then 
        sudo ln -s /usr/local/lib/libbz2.so.1.0.8 /lib64/libbz2.so.1
    fi
    

    if [ ! -f /home/tc/redpill-load/user_config.json ] ; then 
        ln -s /home/tc/user_config.json /home/tc/redpill-load/user_config.json
    fi 
        
    cd /home/tc/redpill-load

    if [ -d cache ] ; then 
        echo "Cache directory OK "
    else
        mkdir cache
    fi


    if [ "${TARGET_PLATFORM}" = "apollolake" ] ; then
        SYNOMODEL="DS918+"
    elif [ "${TARGET_PLATFORM}" = "bromolow" ] ; then
        SYNOMODEL="DS3615xs"
    fi


    sudo ./build-loader.sh $SYNOMODEL $TARGET_VERSION-$TARGET_REVISION loader.img

    if [ $? -ne 0 ] ; then 
        echo "FAILED : Loader creation failed check the output for any errors"
        exit 99
    fi

    sudo losetup -fP ./loader.img
    loopdev=`losetup -j loader.img | awk '{print $1}'| sed -e 's/://'`

    if [ -d part1 ] ; then
        sudo mount ${loopdev}p1 part1
    else 
        mkdir part1 
        sudo mount ${loopdev}p1 part1
    fi

    if [ -d part2 ] ; then
        sudo mount ${loopdev}p2 part2
    else 
        mkdir part2 
        sudo mount ${loopdev}p2 part2
    fi

    loaderdisk=`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`

    if [ -d localdiskp1 ] ; then 
        sudo mount  /dev/${loaderdisk}1 localdiskp1 
        echo  "Mounting /dev/${loaderdisk}1 to localdiskp1 "
    else
        mkdir localdiskp1 
        sudo mount  /dev/${loaderdisk}1 localdiskp1	
        echo  "Mounting /dev/${loaderdisk}1 to localdiskp1 "
    fi
        
    if [ -d localdiskp2 ] ; then 
        sudo mount  /dev/${loaderdisk}2 localdiskp2 
        echo  "Mounting /dev/${loaderdisk}2 to localdiskp2 "
    else
        mkdir localdiskp2
        sudo mount  /dev/${loaderdisk}2 localdiskp2	
        echo  /dev/${loaderdisk}2 localdiskp2 
    fi

    if [ `mount |grep -i part1 |wc -l` -eq 1 ] && [ `mount |grep -i part2 |wc -l` -eq 1 ] && [ `mount |grep -i localdiskp1 |wc -l` -eq 1 ] && [ `mount |grep -i localdiskp2 |wc -l` -eq 1 ] ; then
        sudo cp -rp part1/* localdiskp1/
        sudo cp -rp part2/* localdiskp2/
        echo "Creating tinycore entry"
        tinyentry |  sudo tee --append localdiskp1/boot/grub/grub.cfg
    else
        echo "ERROR: Failed to mount correctly all required partitions"
    fi

    echo "Entries in Localdisk bootloader : "
    echo "======================================================================="
    grep menuentry localdiskp1/boot/grub/grub.cfg

    sudo umount part1 
    sudo umount part2
    sudo umount localdiskp1
    sudo umount localdiskp2

    sudo losetup -D 

}


function kernelprepare() {

    export ARCH=x86_64

    cd /home/tc/linux-kernel
    cp synoconfigs/${TARGET_PLATFORM} .config
    if [ ${TARGET_PLATFORM} = "apollolake" ] ; then 
        echo '+' > .scmversion
    fi

    if [ ${TARGET_PLATFORM} = "bromolow" ] ; then 

cat << EOF > patch-reloc
--- arch/x86/tools/relocs.c
+++ arch/x86/tools/relocs.b
@@ -692,7 +692,7 @@
*
*/
static int per_cpu_shndx       = -1;
-Elf_Addr per_cpu_load_addr;
+static Elf_Addr per_cpu_load_addr;

static void percpu_init(void)
{
EOF

        if ! patch -R -p0 -s -f --dry-run <patch-reloc; then
            patch -p0 <patch-reloc
        fi

    fi

    make oldconfig
    make headers_install
    make modules_prepare

}


function getlatestrploader() {

    echo -n "Checking if a newer version exists on the repo -> "

    curl -s --location "$rploaderepo" --output latestrploader.sh 

    CURRENTSHA="`sha256sum rploader.sh | awk '{print $1}'`"
    REPOSHA="`sha256sum latestrploader.sh | awk '{print $1}'`"

    if [ "${CURRENTSHA}" != "${REPOSHA}" ] ; then 
        echo -n "There is a newer version of the script on the repo should we use that ? [yY/nN]" 
        read confirmation
        if [ "$confirmation" = "y" ] || [ "$confirmation" = "Y" ] ; then
            echo "OK, updating, please re-run after updating"
            cp -f /home/tc/latestrploader.sh /home/tc/rploader.sh
			rm -f /home/tc/latestrploader.sh
            loaderdisk=`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`
            echo "Updating tinycore loader with latest updates"
            #cleanloader 
            filetool.sh -b ${loaderdisk}3
            exit
        else
		    rm -f /home/tc/latestrploader.sh
            return
        fi
    else 
        echo "Version is current"
		rm -f /home/tc/latestrploader.sh
    fi

}



function getvars() { 

	if grep -q ^flags.*\ hypervisor\  /proc/cpuinfo ; then
    MACHINE="VIRTUAL"
    HYPERVISOR=`dmesg |grep -i "Hypervisor detected" | awk '{print $5}'`
    echo "Machine is $MACHINE Hypervisor=$HYPERVISOR"
    fi

	
    CONFIG=$(readConfig) ; selectPlatform $1

    LD_SOURCE_URL="`echo $platform_selected  |jq -r -e '.redpill_load .source_url'`"
    LKM_SOURCE_URL="`echo $platform_selected |jq -r -e '.redpill_lkm .source_url'`"
    EXTENSIONS="`echo $platform_selected |jq -r -e '.add_extensions[] .id'`"
    EXTENSIONS_SOURCE_URL="`echo $platform_selected |jq '.add_extensions[] .url'`"
    TOOLKIT_URL="`echo $platform_selected |jq -r -e '.downloads .toolkit_dev .url'`"
    TOOLKIT_SHA="`echo $platform_selected |jq -r -e '.downloads .toolkit_dev .sha256'`"
    SYNOKERNEL_URL="`echo $platform_selected  |jq -r -e '.downloads .kernel .url'`"
    SYNOKERNEL_SHA="`echo $platform_selected  |jq -r -e '.downloads .kernel .sha256'`"
    COMPILE_METHOD="`echo $platform_selected | jq -r -e '.compile_with'`"
    TARGET_PLATFORM="`echo $platform_selected | jq -r -e '.platform_version | split("-")'  | jq -r -e .[0]`"
    TARGET_VERSION="`echo $platform_selected | jq -r -e '.platform_version | split("-")'  | jq -r -e .[1]`"
    TARGET_REVISION="`echo $platform_selected | jq -r -e '.platform_version | split("-")'  | jq -r -e .[2]`"
    REDPILL_LKM_MAKE_TARGET="`echo $platform_selected | jq -r -e   '.redpill_lkm_make_target'`"


    if [ -z "$TARGET_PLATFORM" ] || [ -z  "$TARGET_VERSION" ] || [ -z "$TARGET_REVISION" ]; then
        echo "Error : Platform not found "
        showhelp
        exit 99
    fi

    #echo "Platform : $platform_selected"
    echo "Loader source : $LD_SOURCE_URL"
    echo "Redpill module source : $LKM_SOURCE_URL"
    echo "Extensions : $EXTENSIONS "
    echo "Extensions URL : $EXTENSIONS_SOURCE_URL"
    echo "TOOLKIT_URL : $TOOLKIT_URL"
    echo "TOOLKIT_SHA : $TOOLKIT_SHA"
    echo "SYNOKERNEL_URL : $SYNOKERNEL_URL" 
    echo "SYNOKERNEL_SHA : $SYNOKERNEL_SHA"
    echo "COMPILE_METHOD : $COMPILE_METHOD"
    echo "TARGET_PLATFORM       : $TARGET_PLATFORM"
    echo "TARGET_VERSION    : $TARGET_VERSION"
    echo "TARGET_REVISION : $TARGET_REVISION"
    echo "REDPILL_LKM_MAKE_TARGET : $REDPILL_LKM_MAKE_TARGET"

}

function matchpciidmodule() {

    vendor="`echo $1 | sed 's/[a-z]/\U&/g'`"
    device="`echo $2| sed 's/[a-z]/\U&/g'`"

    pciid="${vendor}d0000${device}"

    #jq -e -r ".modules[] | select(.alias | test(\"(?i)${1}\")?) |   .name " modules.alias.json
    # Correction to work with tinycore jq
    matchedmodule=`jq -e -r ".modules[] | select(.alias | contains(\"${pciid}\")?) | .name " modules.alias.json`

    # Call listextensions for extention matching

    echo "$matchedmodule"

    listextension $matchedmodule

}


function listpci( ){


    lspci -n  | while read line; do

        bus="`echo $line | cut -c 1-7`"
        class="`echo $line | cut -c 9-12`"
        vendor="`echo $line | cut -c 15-18`"
        device="`echo $line | cut -c 20-23`"

        #echo "PCI : $bus Class : $class Vendor: $vendor Device: $device"
        case $class in
            0100)
            echo "Found SCSI Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device} )"
            ;;
            0106)
            echo "Found SATA Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device} )"
            ;;
            0107)
            echo "Found SAS Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device} )"
            ;;
            0200)
            echo "Found Ethernet Interface : pciid ${vendor}d0000${device} Required Extension : $(matchpciidmodule ${vendor} ${device} )"
            ;;
            0300)
            echo "Found VGA Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device} )"
            ;;
			0c04)
            echo "Found Fibre Channel Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device} )"
            ;;
        esac
    done

}

function getmodulealiasjson() {

    echo "{"
    echo "\"modules\" : ["

    for module in `ls *.ko`; do
        if [ `modinfo ./$module --field alias |grep -ie pci -ie usb | wc -l` -ge 1 ] ; then
            for alias in `modinfo ./$module --field alias |grep -ie pci -ie usb`; do
                echo "{"
                echo "\"name\" :  \"${module}\"",
                echo "\"alias\" :  \"${alias}\""
                echo "}",
            done
        fi
    #       echo "},"
    done |  sed '$ s/,//'

    echo "]"
    echo "}"

    #
    # To query alias for module run #cat n | jq '.modules[] | select(.alias | test ("8086d00001000")?) .name'
    # or cat modules.alias.json | jq '.modules[] | select(.alias | test("(?i)1000d00000030")?) |  .name'
    # 
    #

}

function getmodaliasfile() {

    echo "{"
    echo "\"modules\" : ["

    grep -ie pci -ie usb /lib/modules/`uname -r`/modules.alias | while read line; do

        read alias pciid module <<<"$line"
        echo "{"
        echo "\"name\" :  \"${module}\"",
        echo "\"alias\" :  \"${pciid}\""
        echo "}",
        #       echo "},"

    done |  sed '$ s/,//'

    echo "]"
    echo "}"

}

function listmodules() {

    if [ ! -f modules.alias.json  ] ; then 
        echo "Creating module alias json file"
        getmodaliasfile > modules.alias.json
    fi

    echo -n "Testing modules.alias.json -> "
    if  `jq '.' modules.alias.json > /dev/null`  ; then
        echo "File OK"	
        echo "------------------------------------------------------------------------------------------------"
        echo -e "It looks that you will need the following modules : \n\n" 
        listpci
        echo "------------------------------------------------------------------------------------------------"
    else 
        echo "Error : File modules.alias.json could not be parsed"	
    fi 

}

function listextension() {

    if [ ! -f rpext-index.json ] ; then
        curl --progress-bar --location "${modextention}" --output rpext-index.json
    fi

    ## Get extension author rpext-index.json and then parse for extension download with :
    #       jq '. | select(.id | contains("vxge")) .url  ' rpext-index.json

    if [ ! -z $1 ] ; then
        echo "Searching for matching extension for $1"
        matchingextension=(`jq ". | select(.id | contains(\"${1}\")) .url  " rpext-index.json`)


        if [ ! -z $matchingextension ] ; then
            echo "Found matching extension : "
            echo $matchingextension
            ./redpill-load/ext-manager.sh add "${matchingextension//\"}"
        fi 

        extensionslist+="${matchingextension} "
        #echo $extensionslist
    else
        echo "No matching extension"
    fi

}

function ext_manager() {

    local _SCRIPTNAME="${0}"
    local _ACTION="${1}"
    local _PLATFORM_VERSION="${2}"
    shift 2
    local _REDPILL_LOAD_SRC="/home/tc/redpill-load"
    export MRP_SRC_NAME="${_SCRIPTNAME} ${_ACTION} ${_PLATFORM_VERSION}"
    ${_REDPILL_LOAD_SRC}/ext-manager.sh $@
    exit $?

}



if [ $# -lt 2 ] ; then
    showhelp
    exit 99
fi

case $1 in

    download)
        getvars $2
        checkinternet
        gitdownload 
        ;;

    build)

        getvars $2
        checkinternet
        getlatestrploader
        gitdownload


        if [ "$3" = "compile" ] ; then
            prepareforcompile
            if [ "$COMPILE_METHOD" = "toolkit_dev" ] ; then 
                gettoolchain
                compileredpill
                echo "Starting loader creation "
                buildloader
            else
                getsynokernel
                kernelprepare
                compileredpill
                echo "Starting loader creation "
                buildloader
            fi 
        else 
            echo "Using static compiled redpill extension"
            getstaticmodule
            echo "Got $REDPILL_MOD_NAME "
            listmodules
            echo "Starting loader creation "
            buildloader
        fi 
        ;;

    ext)

        getvars $2
        checkinternet
        gitdownload
		
           if [ "$3" = "auto" ] ; then 
           listmodules
           else 
           ext_manager $@ # instead of listmodules
           fi 
		
        ;;


    clean)
        cleanloader
        ;;

    update)
        checkinternet
        getlatestrploader
        ;;

    listmods)
        listmodules
        echo "$extensionslist"
        ;;
	serialgen)
        serialgen $2
        ;;
	interactive)
	    if [ -f interactive.sh ] ; then 
	    . ./interactive.sh
		else
		#curl --location --progress-bar "https://github.com/pocopico/tinycore-redpill/raw/main/interactive.sh" --output interactive.sh
		#. ./interactive.sh
		exit 99
	    fi 
		;;
    identifyusb)
        usbidentify
		;;
	satamap)
	    satamap
		;;
	backup)
	    backup
		;;	
	mountshare)
		mountshare	
		;;
    *)
        showhelp
        exit 99
        ;;

esac 
