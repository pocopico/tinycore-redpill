#!/bin/bash


echo "Mounting root to get the latest dsmroot patch in /.syno/patch "

if [ `mount |grep -i dsmroot|wc -l` -le 0 ] ; then 
./rploader.sh mountdsmroot now
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
	
echo "redpill-load directory"
cd /home/tc/redpill-load/

echo "Removing bundled exts directories"
for bundledext in "`grep ":" bundled-exts.json | awk '{print $2}' | sed -e 's/"//g'`"
do
bundledextdir=`curl -s "$bundledext" | jq -r -e '.id' `
if [ -d /home/tc/redpill-load/custom/extensions/${bundledextdir} ] ; then 
echo "Removing : ${bundledextdir}" 
sudo rm -rf /home/tc/redpill-load/custom/extensions/${bundledextdir}
fi 

done

echo "Creating loader ... "

sudo ./build-loader.sh 'DS3622xs+' 7.1.0-42621

loaderimg=`ls -ltr images/redpill-DS3622xs\+_7.1.0-42621* | tail -1 | awk '{print $9}'`
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

echo "Done, closing"




