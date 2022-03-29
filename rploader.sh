#!/bin/bash
#
# Author : 
# Date : 22290318
# Version : 0.6.0.1
#
#
# User Variables :

rploaderver="0.6.0.1"
rploaderfile="https://raw.githubusercontent.com/pocopico/tinycore-redpill/main/rploader.sh"
rploaderrepo="https://github.com/pocopico/tinycore-redpill/raw/main/"

redpillextension="https://github.com/pocopico/rp-ext/raw/main/redpill/rpext-index.json"
modextention="https://github.com/pocopico/rp-ext/raw/main/rpext-index.json"
modalias4="https://raw.githubusercontent.com/pocopico/tinycore-redpill/main/modules.alias.4.json.gz"
modalias3="https://raw.githubusercontent.com/pocopico/tinycore-redpill/main/modules.alias.3.json.gz"
dtcbin="https://raw.githubusercontent.com/pocopico/tinycore-redpill/main/dtc"
dtsfiles="https://raw.githubusercontent.com/pocopico/tinycore-redpill/main"

fullupdatefiles="custom_config.json global_config.json modules.alias.3.json.gz modules.alias.4.json.gz rpext-index.json user_config.json dtc rploader.sh ds1621p.dts"

# END Do not modify after this line
######################################################################################################



function postupdate() {


echo "Mounting root to get the latest dsmroot patch in /.syno/patch "

if [ ! -f /home/tc/redpill-load/user_config.json ] ; then 
        ln -s /home/tc/user_config.json /home/tc/redpill-load/user_config.json
    fi 
	

if [ `mount |grep -i dsmroot|wc -l` -le 0 ] ; then 
mountdsmroot 
else 
echo "Already mounted"
fi


echo "Clearing last created loader "
rm -f redpill-load/loader.img

if [ ! -d "/lib64" ] ; then
echo "/lib64 does not exist, bringing linking /lib"
ln -s /lib /lib64
fi

if [ ! -n "`which bspatch`" ] ; then 

echo "bspatch does not exist, bringing over from repo"

curl --location "https://raw.githubusercontent.com/pocopico/tinycore-redpill/main/bspatch" -O 
  
chmod 777 bspatch
sudo mv bspatch /usr/local/bin/

fi


echo "Checking available patch"

cd /mnt/dsmroot/.syno/patch/
. ./VERSION
. ./GRUB_VER

echo "Found Platform : ${PLATFORM}  Model : $MODEL Version : ${major}.${minor}.${micro}-${buildnumber} "

echo "Do you want to use this for the loader ? [yY/nN] : "
            read answer
            
    if [ "$answer" == "y" ] || [ "$answer" == "Y" ] ; then
	patfile="`echo ${MODEL}_${buildnumber} | sed -e 's/\+/p/' | tr '[:upper:]' '[:lower:]'`.pat"
    echo "Creating pat file ${patfile} using contents of : `pwd` "			
	[ ! -d "/home/tc/redpill-load/cache" ] && mkdir /home/tc/redpill-load/cache/
	tar cfz /home/tc/redpill-load/cache/${patfile} * 
	os_sha256=`sha256sum /home/tc/redpill-load/cache/${patfile} | awk '{print $1}' `
	echo "Created pat file with sha256sum : $os_sha256"
	cd /home/tc
    else
	echo "OK, see you later"
	return
	fi

echo -n "Checking config file existence -> "
    if [ -f "/home/tc/redpill-load/config/$MODEL/${major}.${minor}.${micro}-${buildnumber}/config.json" ] ; 
    then echo "OK"
	configfile="/home/tc/redpill-load/config/$MODEL/${major}.${minor}.${micro}-${buildnumber}/config.json"
    else
    echo "No config file found, please use the proper repo, clean and download again"
    exit 99
    fi


echo -n "Editing config file -> "			
sed -i "/\"os\": {/!b;n;n;n;c\"sha256\": \"$os_sha256\"" ${configfile}
echo -n "Verifying config file -> "
verifyid="`cat  ${configfile} | jq -r -e '.os .sha256'`"


    if [ "$os_sha256" == "$verifyid" ] ; then 
    echo "OK ! "
    else 
    echo "config file, os sha256 verify FAILED, check ${configfile} "
    exit 99 
    fi 
	
removebundledexts
	
cd /home/tc/redpill-load/

echo "Creating loader ... "

sudo ./build-loader.sh ${MODEL} ${major}.${minor}.${micro}-${buildnumber}

loadername="redpill-${MODEL}_${major}.${minor}.${micro}-${buildnumber}"
loaderimg=`ls -ltr /home/tc/redpill-load/images/${loadername}* | tail -1 | awk '{print $9}'`

echo "Moving loader ${loaderimg} to loader.img "
mv -f $loaderimg loader.img

   if [ ! -n "`losetup -j loader.img | awk '{print $1}'| sed -e 's/://'`" ] ; then 
   echo -n "Setting up loader img loop -> "
   sudo losetup -fP ./loader.img
   loopdev=`losetup -j loader.img | awk '{print $1}'| sed -e 's/://'`
   echo "$loopdev"
   else
   echo -n "Loop device exists, removing "
   losetup -d `losetup -j loader.img | awk '{print $1}'| sed -e 's/://'`
   echo -n "Setting up loader img loop -> "
   sudo losetup -fP ./loader.img
   loopdev=`losetup -j loader.img | awk '{print $1}'| sed -e 's/://'`
   fi

echo -n "Mounting loop disks -> "

 [ ! -d /home/tc/redpill-load/localdiskp1 ] && mkdir /home/tc/redpill-load/localdiskp1
 [ ! -d /home/tc/redpill-load/localdiskp2 ] && mkdir /home/tc/redpill-load/localdiskp2
 
  [ ! -n "`mount |grep -i localdiskp1`" ] && sudo mount  ${loopdev}p1 localdiskp1
  [ ! -n "`mount |grep -i localdiskp2`" ] && sudo mount  ${loopdev}p2 localdiskp2

[ -n "mount |grep -i localdiskp1" ] && [ -n "mount |grep -i localdiskp2" ] && echo "mounted succesfully"

echo -n "Mounting loader disk -> "
loaderdisk="`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`"

sudo mount  /dev/${loaderdisk}1
sudo mount  /dev/${loaderdisk}2

[ -n "mount |grep -i ${loaderdisk}1" ] && [ -n "mount |grep -i ${loaderdisk}2" ] && echo "mounted succesfully"

echo -n "Copying loader files -> " 
echo -n "rd.gz : "
cp -f /home/tc/redpill-load/localdiskp1/rd.gz /mnt/${loaderdisk}1/rd.gz
cp -f /home/tc/redpill-load/localdiskp2/rd.gz /mnt/${loaderdisk}2/rd.gz
[ "`sha256sum /home/tc/redpill-load/localdiskp1/rd.gz | awk '{print $1}'`" == "`sha256sum /mnt/${loaderdisk}1/rd.gz | awk '{print $1}'`" ] && [ "`sha256sum /home/tc/redpill-load/localdiskp2/rd.gz | awk '{print $1}'`" == "`sha256sum /mnt/${loaderdisk}2/rd.gz | awk '{print $1}'`" ] && echo -n "OK !!!"
echo -n "zImage : "
cp -f /home/tc/redpill-load/localdiskp1/zImage /mnt/${loaderdisk}1/zImage
cp -f /home/tc/redpill-load/localdiskp2/zImage /mnt/${loaderdisk}2/zImage
[ "`sha256sum /home/tc/redpill-load/localdiskp1/zImage | awk '{print $1}'`" == "`sha256sum /mnt/${loaderdisk}1/zImage | awk '{print $1}'`" ] && [ "`sha256sum /home/tc/redpill-load/localdiskp2/zImage | awk '{print $1}'`" == "`sha256sum /mnt/${loaderdisk}2/zImage | awk '{print $1}'`" ] && echo "OK !!!"
echo "Do you want to overwrite your custom.gz as well ? [yY/nN] : "
read answer 

if [ "$answer" == "y" ] || [ "$answer" == "Y" ] ; then
echo "Copying custom.gz"
cp -f /home/tc/redpill-load/localdiskp1/custom.gz /mnt/${loaderdisk}1/custom.gz
[ "`sha256sum /home/tc/redpill-load/localdiskp1/custom.gz | awk '{print $1}'`" == "`sha256sum /mnt/${loaderdisk}1/custom.gz | awk '{print $1}'`" ] && echo "OK !!!"
else
echo "OK, you should be fine keeping your existing custom.gz"
fi


echo "Cleaning up... "
echo -n "Unmounting loaderdisk ${loaderdisk} -> "
sudo umount /dev/${loaderdisk}1 && sudo umount /dev/${loaderdisk}2
[ -z `mount |grep -i ${loaderdisk}1` ] && [ -z `mount |grep -i ${loaderdisk}2` ] && echo "OK !!!"

echo -n "Unmounting loader image ${loopdev} -> "
sudo umount ${loopdev}p1 && sudo umount ${loopdev}p2 
[ -z `mount |grep -i ${loopdev}p1` ] && [ -z `mount |grep -i ${loopdev}p2` ] && echo "OK !!!"
echo -n "Detaching loop loader image -> "
sudo losetup -d ${loopdev}
[ -z `losetup |grep -i loader.img` ] && echo "OK !!!"


if  [ -f /home/tc/redpill-load/loader.img ] ; then 
echo -n "Removing loader.img -> "
sudo rm -rf /home/tc/redpill-load/loader.img
[ ! -f /home/tc/redpill-load/loader.img ] && echo "OK !!!"
fi 


echo "Unmounting dsmroot -> "
[ ! -z "`mount |grep -i dsmroot`" ] && sudo umount /mnt/dsmroot
[ -z "`mount |grep -i dsmroot`" ] && echo "OK !!! "

echo "Done, closing"


}

function removebundledexts() {

echo "Entering redpill-load directory"
cd /home/tc/redpill-load/

echo "Removing bundled exts directories"
for bundledext in `grep ":" bundled-exts.json | awk '{print $2}' | sed -e 's/"//g' | sed -e 's/,/\n/g'`
do
bundledextdir=`curl --location -s "$bundledext" | jq -r -e '.id' `
if [ -d /home/tc/redpill-load/custom/extensions/${bundledextdir} ] ; then 
echo "Removing : ${bundledextdir}" 
sudo rm -rf /home/tc/redpill-load/custom/extensions/${bundledextdir}
fi 

done


}


function fullupgrade(){

backupdate="`date +%Y-%b-%H-%M`"

echo "Performing a full TCRP upgrade"
echo "Warning some of your local files will be moved to /home/tc/old/xxxx.${backupdate}"

[ ! -d /home/tc/old ] && mkdir /home/tc/old

for updatefile in ${fullupdatefiles}
do

echo "Updating ${updatefile}"

sudo mv $updatefile old/${updatefile}.${backupdate} 
sudo curl --location "${rploaderrepo}/${updatefile}" -O 

done 

sudo chown tc:staff $fullupdatefiles
gunzip -f modules.alias.*.gz
sudo chmod 700 rploader.sh 


}


function backuploader(){

    loaderdisk="`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`"
    tcrppart="`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`3"
    homesize=`du -sh /home/tc | awk '{print $1}'`
    backupdate="`date +%Y-%b-%H-%M`"


    if [ ! -n "$loaderdisk" ] || [ ! -n "$tcrppart" ] ; then
        echo "No Loader disk or no TCRP partition found, return"
        return 
    fi 

    if [ `df -h /mnt/${tcrppart} | grep mnt | awk '{print $4}' | cut -c 1-3` -le 50 ] ; then 
        echo "No adequate space on TCRP loader partition  /mnt/${tcrppart} "
        return 
    fi

    echo "Backing up current loader"
    echo "Checking backup folder existence" ; [ ! -d /mnt/${tcrppart}/backup ] && mkdir /mnt/${tcrppart}/backup
    echo "The backup folder holds the following backups" 
    ls -ltr /mnt/${tcrppart}/backup
    echo "Creating backup folder $backupdate" ;  [ ! -d /mnt/${tcrppart}/backup/${backupdate} ] && mkdir /mnt/${tcrppart}/backup/${backupdate}
    echo "Mounting partition 1"
    mount /dev/${loaderdisk}1
    cd /mnt/${loaderdisk}1 ; tar cfz /mnt/${tcrppart}/backup/${backupdate}/partition1.tgz *

    echo "Mounting partition 2"
    mount /dev/${loaderdisk}2
    cd /mnt/${loaderdisk}2 ; tar cfz /mnt/${tcrppart}/backup/${backupdate}/partition2.tgz *

    cd 
    echo "Listing backup files : "

    ls -ltr /mnt/${tcrppart}/backup/${backupdate}/

    echo "Partition 1 : `tar tfz /mnt/${tcrppart}/backup/${backupdate}/partition1.tgz |wc -l` files and directories "
    echo "Partition 2 : `tar tfz /mnt/${tcrppart}/backup/${backupdate}/partition2.tgz |wc -l` files and directories "

    echo "DONE"

}


function restoreloader(){

    loaderdisk="`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`"
    tcrppart="`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`3"
    homesize=`du -sh /home/tc | awk '{print $1}'`
    PS3="Select backup folder to restore : "
    options=""


    if [ ! -n "$loaderdisk" ] || [ ! -n "$tcrppart" ] ; then
        echo "No Loader disk or no TCRP partition found, return"
        return 
    fi 

    echo "Restoring loader from backup"
    echo "The backup folder holds the following backups" 

    for folder in `ls /mnt/${tcrppart}/backup | sed -e 's/\///g'` ; do
        options=" $options ${folder}"
        echo -n $folder 
        echo -n "Partition 1 : `tar tfz /mnt/${tcrppart}/backup/${folder}/partition1.tgz |wc -l` files and directories "
        echo "Partition 2 : `tar tfz /mnt/${tcrppart}/backup/${folder}/partition2.tgz |wc -l` files and directories "
    done 

    select restorefolder in ${options[@]} ; do
        if [ "$REPLY" == "quit" ] ; then
            return
        fi 
        if [ -f "/mnt/${tcrppart}/backup/$restorefolder/partition1.tgz" ]; then
            echo " Restore folder : $restorefolder" 
            echo -n "You have chosen ${restorefolder} : "
            echo "Folder contains : "
            ls -ltr /mnt/${tcrppart}/backup/$restorefolder
            
            echo -n "Do you want to restore [yY/nN] : "
            read answer
            
            if [ "$answer" == "y" ] || [ "$answer" == "Y" ] ; then
                echo restoring $restorefolder 
                echo "Mounting partition 1"
                mount /dev/${loaderdisk}1
                echo "Restoring partition1 "
                cd /mnt/${loaderdisk}1 ; tar xfz /mnt/${tcrppart}/backup/${backupdate}/partition1.tgz *
                ls -ltr /mnt/${loaderdisk}1 
                echo "Mounting partition 2"
                mount /dev/${loaderdisk}2
                echo "Restoring partition2 "
                cd /mnt/${loaderdisk}2 ; tar xfz /mnt/${tcrppart}/backup/${backupdate}/partition2.tgz *
                ls -ltr /mnt/${loaderdisk}2
                return
            else 
                echo "OK, retry "
                return
            fi
        fi
        echo "Invalid choice : $REPLY"
    done

}


function mountdsmroot(){

    # DSM Disks will be linux_raid_member and will  have the 
    # same DSM PARTUUID with the addition of the partition number e.g : 
    #/dev/sdb1: UUID="629ae3df-7eef-54e3-05d9-49f7b0bbaec7" TYPE="linux_raid_member" PARTUUID="d5ff7cea-01"
    #/dev/sdb2: UUID="260b3a01-ff65-a527-05d9-49f7b0bbaec7" TYPE="linux_raid_member" PARTUUID="d5ff7cea-02"
    # So a command like the below will list the first partition of a DSM disk
    #blkid /dev/sd* |grep -i raid  | awk '{print $1 " " $4}' |grep UUID | grep "\-01" | awk -F ":" '{print $1}'

    dsmrootdisk="`blkid /dev/sd* |grep -i raid  | awk '{print $1 " " $4}' |grep UUID | grep "\-01" | awk -F ":" '{print $1}' | head -1`"

    [[ ! -d /mnt/dsmroot ]] && mkdir /mnt/dsmroot

    [ ! `mount |grep -i dsmroot | wc -l` -gt 0 ] && sudo mount -t ext4 $dsmrootdisk /mnt/dsmroot 

    if [ `mount |grep -i dsmroot | wc -l` -gt 0 ] ; then 
        echo "Succesfully mounted under /mnt/dsmroot"
    else
        echo "Failed to mount"
        return 
    fi

    echo "Checking if patch version exists" 

    if [ -d /mnt/dsmroot/.syno/patch ] ; then
        echo "Patch directory exists"
        sudo cp /mnt/dsmroot/.syno/patch/VERSION /tmp/VERSION ; sudo chmod 666 /tmp/VERSION
        . /tmp/VERSION
        echo "DSM Root holds a patch version $productversion-$base-$nano "
    else 
        echo "No DSM patch directory exists"
        return 
    fi

}

function mountdatadisk(){

    echo "Assembling MD ..."
    sudo mdadm -Asf

    for mdarray in "`ls /dev/md* | awk -F "\/" '{print $3}'`" ; do
        echo "Mounting $mdarray"
        echo "Getting md devices for array $mdarray"

        # Keep for LVM root disks recovery in future release 
        if [ "$(fstype /dev/${mdarray})" == "LVM2_member" ] ; then 
            echo "Found LVM array, downloading LVM" 
            tce-load -iw lvm2
            sudo vgchange -a y 
            for volume in `sudo lvs |grep -i vol | awk '{print $2"-"$1}'`
            do
            
                if [ "$(fstype /dev/mapper/$volume)" == "btrfs" ] ; then
                    echo "BTRFS Mounting is not supported in tinycore"
                    return
                fi
                mkdir /mnt/$volume
                sudo mount /dev/mapper/$volume
            done 
        else
            echo "Mounting $mdarray "
            sudo mkdir /mnt/$mdarray
            sudo mount /dev/$mdarray /mnt/$mdarray        
        fi
    done 

}

function patchdtc(){

    loaderdisk=`mount |grep -i optional | grep cde | awk -F / '{print $3}' |uniq | cut -c 1-3`
    localdisks=`lsblk |grep -i disk |grep -i sd | awk '{print $1}' |grep -v $loaderdisk`
    localnvme=`lsblk |grep -i nvme |awk '{print $1}' `


    if [ "${TARGET_PLATFORM}" = "v1000" ] ; then
        SYNOMODEL="ds1621p"
    else 
        echo "${TARGET_PLATFORM} does not require model.dtc patching "
        return 
    fi

    if [ ! -d /lib64 ] ; then 
        sudo ln -s /lib /lib64
    fi

    echo "Downloading dtc binary"
    curl --location --progress-bar "$dtcbin" -O 
    chmod 700 dtc 

    if [ ! -f ${SYNOMODEL}.dts ] ; then
        echo "dts file for ${SYNOMODEL} not found, trying to download"
        curl --location --progress-bar  -O "${dtsfiles}/${SYNOMODEL}.dts"
    fi

    echo "Found `echo $localdisks|wc -w` disks and `echo $localnvme |wc -w` nvme"
    let diskslot=1
    echo "Collecting disk paths"
    
    for disk in $localdisks; do
        diskpath=`udevadm info --query path --name $disk | awk -F "\/" '{print $4 ":" $5 }' | awk -F ":" '{print $2 ":" $3 "," $6}'`
        echo "Found local disk $disk with path $diskpath, adding into internal_slot $diskslot"
        sed -i "/internal_slot\@${diskslot} {/!b;n;n;n;n;n;cpcie_root = \"$diskpath\";" ${SYNOMODEL}.dts
        let diskslot=$diskslot+1	
    done 
    
    if [ `echo $localnvme | wc -w` -gt 0 ] ; then 
        let nvmeslot=1
        echo "Collecting nvme paths"
        
        for nvme in $localnvme ; do
            nvmepath=`udevadm info --query path --name $nvme | awk -F "\/" '{print $4 ":" $5 }' | awk -F ":" '{print $2 ":" $3 "," $6}'`
            echo "Found local nvme $nvme with path $nvmepath, adding into m2_card $nvmeslot"
            sed -i "/m2_card\@${nvmeslot} {/!b;n;n;n;cpcie_root = \"$nvmepath\";" ${SYNOMODEL}.dts
            let nvmeslot=$diskslot+1	
        done 
            
    else 
        echo "NO NVME disks found, returning"
    fi
    
    echo "Converting dts to dtb"
    ./dtc -I dts -O dtb ${SYNOMODEL}.dts > ${SYNOMODEL}.dtb 2>&1 > /dev/null

    echo "Remember to replace extension model file ..."

}

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

function checkmachine() {

    if grep -q ^flags.*\ hypervisor\  /proc/cpuinfo ; then
        MACHINE="VIRTUAL"
        HYPERVISOR=`dmesg |grep -i "Hypervisor detected" | awk '{print $5}'`
        echo "Machine is $MACHINE Hypervisor=$HYPERVISOR"
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

    checkmachine

    let controller=0
    let diskidxmap=0

    if [ "$MACHINE" = "VIRTUAL" ] && [ "$HYPERVISOR" = "VMware" ] ; then
        echo "Running on VMware, Possible working solution, SataPortMap=1 DiskIdxMap=00"
    else 
        for hba in `lsscsi -Hv |grep pci |grep -v usb | cut -c 44-50 | uniq` ; do
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

    checkmachine

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
        select usbdev in $usbvendor ; do
            vendorid=`grep -B 10 -A 10 $usbdev /tmp/lsusb.out |grep idVendor | grep $usbdev |awk '{print $2}'`
            productid=`grep -B 10 -A 10 $usbdev /tmp/lsusb.out | grep -A 1 idVendor  | grep idProduct |  awk '{print $2}'`
            echo "Selected Device : $usbdev , with VendorID: $vendorid and ProductID: $productid"
            break
        done
    else
        usbdevice="`grep iManufacturer /tmp/lsusb.out | awk '{print $3}'` `grep iProduct /tmp/lsusb.out | awk '{print $3}' ` SerialNumber: `grep iSerial /tmp/lsusb.out | awk '{print $3}'`"
    fi

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

    if [ "$1" = "DS3615xs" ] || [ "$1" = "DS3617xs" ] || [ "$1" = "DS916+" ] || [ "$1" = "DS918+" ] || [ "$1" = "DS920+" ] || [ "$1" = "DS3622xs+" ] || [ "$1" = "FS6400" ] || [ "$1" = "DVA3219" ] || [ "$1" = "DVA3221" ] || [ "$1" = "DS1621+" ] ; then
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
        echo "Available Models : DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xs+ FS6400 DVA3219 DVA3221 DS1621+"
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
        DS3622xs+)
                    permanent="SQR"
                    serialstart="2030 2040 20C0 2150"
                    ;;
        DS1621+)
                    permanent="S7R"
                    serialstart="2080"
                    ;;
        FS6400)
                    permanent="PSN"
                    serialstart="1960"
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
    for i in a b c d e f g h j k l m n p q r s t v w x y z ; do
        echo $i
    done | sort -R|tail -1
}


function generateRandomValue() {
    for i in 0 1 2 3 4 5 6 7 8 9 a b c d e f g h j k l m n p q r s t v w x y z ; do
        echo $i
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
        FS6400)
                    serialnum="`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(random)	
                    ;;
        DS920+)
                    serialnum=$(toupper "`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
                    ;;
        DS3622xs+)
                    serialnum=$(toupper "`echo "$serialstart" |  tr ' ' '\n' | sort -R | tail -1`$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
                    ;;
        DS1621+)
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

- build:        Build the 💊 RedPill LKM and update the loader image for the specified 
                platform version and update current loader.

- ext:          Manage extensions, options go after platform (add/force_add/info/remove/update/cleanup/auto)

                example: 

                rploader.sh ext apollolake-7.0.1-42218 add https://raw.githubusercontent.com/pocopico/rp-ext/master/e1000/rpext-index.json

                or for auto detect use 

                rploader.sh ext apollolake-7.0.1-42218 auto 

- download:     Download redpill sources only

- clean:        Removes all cached files and starts over

- update:       Checks github repo for latest version of rploader 

- listmods:     Tries to figure out required extensions

- serialgen:    Generates a serial number and mac address for the following platforms 

                DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xs+ FS6400 DVA3219 DVA3221 DS1621+

- identifyusb:  Tries to identify your loader usb stick VID:PID and updates the user_config.json file 

- patchdtc:     Tries to identify and patch your dtc model for your disk and nvme devices.

- satamap:      Tries to identify your SataPortMap and DiskIdxMap values and updates the user_config.json file 

- backup:       Backup and make changes /home/tc changed permanent to your loader disk

- backuploader: Backup current loader partitions to your TCRP partition

- restoreloader:Restore current loader partitions from your TCRP partition

- mountdsmroot: Mount DSM root for manual intervention on DSM root partition

- postupdate:   Runs a postupdate process to recreate your rd.gz, zImage and custom.gz for junior to match root

- mountshare:   Mounts a remote CIFS working directory

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
        git clone -b $LKM_BRANCH "$LKM_SOURCE_URL"
    fi
    
    if [ -d redpill-load ] ; then
        echo "Loader sources already downloaded, pulling latest"
        cd redpill-load ; git pull ; cd /home/tc
    else
        git clone -b $LD_BRANCH "$LD_SOURCE_URL"
    fi

}

function getstaticmodule() {

    cd /home/tc
	
	
    if [ -d /home/tc/custom-module ] && [ -f /home/tc/custom-module/redpill.ko ] ; then
    echo "Found custom redpill module, do you want to use this instead ? [yY/nN] : "
    read answer
            
       if [ "$answer" == "y" ] || [ "$answer" == "Y" ] ; then
       REDPILL_MOD_NAME="redpill-linux-v`modinfo redpill.ko |grep vermagic | awk '{print $2}'`.ko"
       cp /home/tc/custom-module/redpill.ko  /home/tc/redpill-load/ext/rp-lkm/${REDPILL_MOD_NAME}
       return
       fi
		 
	fi
	
	echo "Removing any old redpill.ko modules"
	if [ -f /home/tc/redpill.ko ] && rm -f  /home/tc/redpill.ko 

    extension=`curl -s --location "$redpillextension"`

    if [ "${TARGET_PLATFORM}" = "apollolake" ] ; then
        SYNOMODEL="ds918p_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "bromolow" ] ; then
        SYNOMODEL="ds3615xs_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "broadwell" ] ; then
        SYNOMODEL="ds3617xs_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "broadwellnk" ] ; then
        SYNOMODEL="ds3622xsp_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "v1000" ] ; then
        SYNOMODEL="ds1621p_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "denverton" ] ; then
        SYNOMODEL="dva3221_$TARGET_REVISION"
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

    mv /home/tc/redpill.ko /home/tc/redpill-load/ext/rp-lkm/${REDPILL_MOD_NAME}
	
	

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

    removebundledexts

    curl -s --progress-bar --location "https://packages.slackonly.com/pub/packages/14.1-x86_64/development/bsdiff/bsdiff-4.3-x86_64-1_slack.txz" --output bsdiff.txz
	[ ! -f /home/tc/bsdiff.txz ] && echo "bsdiff binary was not downloaded"
    [ -f /home/tc/bsdiff.txz ] && 	cd / &&    sudo tar xf /home/tc/bsdiff.txz &&    rm -rf /home/tc/bsdiff.txz && cd /home/tc

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
    elif [ "${TARGET_PLATFORM}" = "broadwell" ] ; then
        SYNOMODEL="DS3617xs"
    elif [ "${TARGET_PLATFORM}" = "broadwellnk" ] ; then
        SYNOMODEL="DS3622xs+"
    elif [ "${TARGET_PLATFORM}" = "v1000" ] ; then
        SYNOMODEL="DS1621+"
    elif [ "${TARGET_PLATFORM}" = "denverton" ] ; then
        SYNOMODEL="DVA3221"
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

    curl -s --location "$rploaderfile" --output latestrploader.sh 
    curl -s --location "$modalias3" --output modules.alias.3.json.gz ; gunzip -f  modules.alias.3.json.gz
    curl -s --location "$modalias4" --output modules.alias.4.json.gz ; gunzip -f modules.alias.4.json.gz

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

    CONFIG=$(readConfig) ; selectPlatform $1

    LD_SOURCE_URL="`echo $platform_selected  |jq -r -e '.redpill_load .source_url'`"
    LD_BRANCH="`echo $platform_selected |jq -r -e '.redpill_load .branch'`"
    LKM_SOURCE_URL="`echo $platform_selected |jq -r -e '.redpill_lkm .source_url'`"
    LKM_BRANCH="`echo $platform_selected |jq -r -e '.redpill_lkm .branch'`"
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

    case $TARGET_PLATFORM in

        bromolow)
                    KERNEL_MAJOR="3"
                    MODULE_ALIAS_FILE="modules.alias.3.json"
                    ;;
        apollolake | broadwell | broadwellnk | v1000 | denverton )
                    KERNEL_MAJOR="4"
                    MODULE_ALIAS_FILE="modules.alias.4.json"
                    ;;
    esac 

    #echo "Platform : $platform_selected"
    echo "Loader source : $LD_SOURCE_URL Loader Branch : $LD_BRANCH "
    echo "Redpill module source : $LKM_SOURCE_URL : Redpill module branch : $LKM_BRANCH "
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
    echo "KERNEL_MAJOR : $KERNEL_MAJOR"
    echo "MODULE_ALIAS_FILE= $MODULE_ALIAS_FILE"
}

function matchpciidmodule() {

    vendor="`echo $1 | sed 's/[a-z]/\U&/g'`"
    device="`echo $2| sed 's/[a-z]/\U&/g'`"

    pciid="${vendor}d0000${device}"

    #jq -e -r ".modules[] | select(.alias | test(\"(?i)${1}\")?) |   .name " modules.alias.json
    # Correction to work with tinycore jq
    matchedmodule=`jq -e -r ".modules[] | select(.alias | contains(\"${pciid}\")?) | .name " $MODULE_ALIAS_FILE `

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
            0101)
                echo "Found IDE Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device} )"
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

    if [ ! -f $MODULE_ALIAS_FILE  ] ; then 
        echo "Creating module alias json file"
        getmodaliasfile > modules.alias.4.json
    fi

    echo -n "Testing $MODULE_ALIAS_FILE -> "
    if  `jq '.' $MODULE_ALIAS_FILE > /dev/null`  ; then
        echo "File OK"	
        echo "------------------------------------------------------------------------------------------------"
        echo -e "It looks that you will need the following modules : \n\n" 
        listpci
        echo "------------------------------------------------------------------------------------------------"
    else 
        echo "Error : File $MODULE_ALIAS_FILE could not be parsed"	
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


        case $3 in 
        
            compile)
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
                        ;;

            static)
                        echo "Using static compiled redpill extension"
                        getstaticmodule
                        echo "Got $REDPILL_MOD_NAME "
                        listmodules
                        echo "Starting loader creation "
                        buildloader
                        ;;

            manual)
                    
                        echo "Using static compiled redpill extension"
                        getstaticmodule
                        echo "Got $REDPILL_MOD_NAME "
                        echo "Manual extension handling,skipping extension auto detection "
                        echo "Starting loader creation "
                        buildloader
                        ;;

            *)
                        echo "No extra build option specified, using default <static> "
                        echo "Using static compiled redpill extension"
                        getstaticmodule
                        echo "Got $REDPILL_MOD_NAME "
                        listmodules
                        echo "Starting loader creation "
                        buildloader
                        ;;

        esac 
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
        getvars $2
        checkinternet
        gitdownload
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

    patchdtc)
        getvars $2
        checkinternet
        patchdtc
        ;;

    satamap)
        satamap
        ;;

    backup)
        backup
        ;;

    backuploader)
        backuploader
        ;;

    restoreloader)
        restoreloader
        ;;
    postupdate)
	    getvars $2
        checkinternet
		gitdownload
		getstaticmodule
        postupdate
        ;;

    mountdsmroot)
        mountdsmroot
        ;;
	fullupgrade)
        fullupgrade
        ;;

    mountshare)
        mountshare
        ;;
    *)
        showhelp
        exit 99
        ;;

esac 