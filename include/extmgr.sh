#!/bin/bash

HOMEPATH="/home/tc"
PAYLOADDIR="${HOMEPATH}/payload"
CONFIGFILES="${HOMEPATH}/config"

function getstaticmodule() {
        redpillextension="https://github.com/pocopico/rp-ext/raw/main/redpill${redpillmake}/rpext-index.json"
        SYNOMODEL="$(cat ${PAYLOADDIR}/platform)"

        echo "Removing any old redpill.ko modules"
        [ -f redpill.ko ] && rm -f redpill.ko

        extension=$(curl --insecure --silent --location "$redpillextension")

        echo "Looking for redpill for : $SYNOMODEL"

        release="$(echo $extension | jq -r -e --arg SYNOMODEL $SYNOMODEL '.releases[$SYNOMODEL]')"
        files="$(curl --insecure --silent --location "$release" | jq -r '.files[] .url' | grep -v ".sh")"

        if [ -n "$files" ] && [ "$files" != "null" ]; then
                echo "SynoModel: $SYNOMODEL, Redpill Make : $redpillmake, Release : $release "
                echo "Adding RP LKM files : $files"
        else
                echo "No RP LKM files found for $SYNOMODEL"
        fi

        for file in $files; do
                echo "Getting file $file"
                curl --insecure --silent -O $file
                if [ -f redpill*.tgz ]; then
                        echo "Extracting module"
                        gunzip redpill*.tgz
                        tar xf redpill*.tar
                        rm redpill*.tar
                        strip --strip-debug redpill.ko
                fi
        done

        if [ -f redpill.ko ] && [ -n $(strings redpill.ko | grep -i $model) ]; then
                echo "Copying redpill.ko module to ramdisk"
                cp redpill.ko usr/lib/modules/rp.ko
        else
                echo "Module does not contain platform information for ${model}"
        fi

        [ -f usr/lib/modules/rp.ko ] && echo "Redpill module is in place" && rm redpill.ko

}

function extadd() {

        shift 1
        extvars "$1" "$2"

        [ ! -d ${PAYLOADDIR} ] && mkdir ${PAYLOADDIR}
        cd ${PAYLOADDIR}

        [ ! -f platform ] && echo "$platform" >platform

        [ -f extensions ] && [ $(grep $extid extensions | wc -l) -gt 0 ] && echo "Extension $extid has been already added" && return
        echo -n "Adding $extid"
        [ ! -d $extid ] && mkdir $extid

        echo "$ext" >$extid/rpext-index.json

        echo "$extid" >>extensions
        echo " -> Done"

}

function extremove() {

        shift 1

        extvars "$1" "$2"

        [ ! -d ${PAYLOADDIR} ] && mkdir ${PAYLOADDIR}

        cd ${PAYLOADDIR}

        [ -f extensions ] && [ $(grep $extid extensions | wc -l) -gt 0 ] && echo "Extension $extid will be removed"

        echo "Removing $extid payload" && rm -rf $extid
        sed -i "/$extid/d" extensions
        sed -i "/$extid/d" on_boot.sh
        sed -i "/$extid/d" on_os_load.sh

}

function extvars() {

        ext="$(curl --silent --location $1)"
        platform="$2"
        [ $(echo $ext | grep 404 | wc -l) -eq 1 ] && echo "Extension not found" && exit 1
        if [ -f platform ] && [ ! "$(cat platform)" == "$platform" ]; then
                echo "Payload already has extensions for $(cat platform), using platform $(cat platform)"
                platform="$(cat platform)"
                extcontents="$(echo $ext | jq -r -e ".releases .$platform")"
        else
                extcontents="$(echo $ext | jq -r -e ".releases .$2")"
        fi

        extid="$(echo $ext | jq -r -e .id)"
        extrelease="$(curl --silent --location $extcontents)"

        [ $(echo $extrelease | jq . | wc -l) -eq 0 ] && echo "Extension does not contain information about platform $2" && exit 1

        payload="$(echo $extrelease | jq -r -e ".files[]")"

}

function processexts() {

        cd ${PAYLOADDIR}

        for ext in $(cat extensions); do

                extvars "file://$PWD/$ext/rpext-index.json" "$(cat platform)"

                echo "Downloading extension $extid payload for platform $platform"

                files="$(echo $extrelease | jq -r -e '.files[] .name')"

                #echo "Found files : $files"

                for file in $files; do
                        name=$(echo $extrelease | jq -r -e ".files[] | select(.name | contains(\"$file\")) .name")
                        download=$(echo $extrelease | jq -r -e ".files[] | select(.name | contains(\"$file\")) .url")
                        modules="$(echo $extrelease | jq -r -e '.kmods')"
                        echo " Downloading : $name "
                        cd $extid && curl --silent --location $download -O && cd ..

                        packed=$(echo $extrelease | jq -r -e ".files[] | select(.name | contains(\"$file\")) .packed")

                        if [ "$packed" == "true" ]; then
                                echo "File $name , is packed, extracting"
                                if [ -f $extid/$name ] && [ $(echo $modules | grep ko | wc -l) -gt 0 ]; then
                                        [ ! -f "mods_load.sh" ] && touch mods_load.sh && echo "#!/usr/bin/env sh" >>mods_load.sh
                                        hasmodules=$(tar --wildcards *.ko -tvf $extid/$name | wc -l)
                                        echo "File contains $hasmodules modules, copying to modules folder"
                                        [ ! -d modules ] && mkdir modules
                                        tar xf $extid/$name -C modules && rm $extid/$name

                                        for mod in $(echo "$modules" | grep ko | sed -e "s/\"//g" | sed -e "s/://g" | sed -e "s/,//g" | awk '{print  $1}'); do
                                                if [ $(grep $mod mods_load.sh | wc -l) -eq 0 ]; then
                                                        modname=$(basename $mod .ko)
                                                        echo "adding module $modname"
                                                        echo "echo -n \":: Loading module $modname ... \" && /sbin/insmod modules/$mod && [ $(lsmod | grep -i $modname | wc -l) -gt 0 ] && echo \"[  OK  ]\" || echo \"[  FAIL  ]\"" >>mods_load.sh
                                                fi
                                        done
                                else
                                        tar xfz $extid/$name -C $extid && rm $extid/$name
                                fi

                        fi

                done
                touch on_boot.sh && touch on_os_load.sh
                onboot="$(echo $extrelease | jq -r -e '.scripts .on_boot')"
                onosload="$(echo $extrelease | jq -r -e '.scripts .on_os_load')"

                if [ $(echo $onboot | wc -l) -gt 0 ] && [ $(grep $extid on_boot.sh | wc -l) -eq 0 ] && [ "$onboot" != "null" ]; then
                        echo "Adding boot script"
                        echo "cd /exts/$extid && ./$onboot && cd .." >>on_boot.sh
                fi
                if [ $(echo $onosload | wc -l) -gt 0 ] && [ $(grep $extid on_os_load.sh | wc -l) -eq 0 ] && [ "$onosload" != "null" ]; then
                        echo "Adding os load script"
                        echo "echo -n \":: Executing $extid os load scripts ... \" && cd /exts/$extid && ./$onosload && cd .. " >>on_os_load.sh
                fi
        done

        find . -type f -name "*.sh" -exec chmod 777 {} \;
        chmod 777 *.sh
        chmod 777 */*.sh

}

function readconfig() {

        userconfigfile=/home/tc/user_config.json

        if [ -f $userconfigfile ]; then
                model="$(jq -r -e '.general .model' $userconfigfile)"
                version="$(jq -r -e '.general .version' $userconfigfile)"
                smallfixnumber="$(jq -r -e '.general .smallfixnumber' $userconfigfile)"
                redpillmake="$(jq -r -e '.general .redpillmake' $userconfigfile)"
                friendautoupd="$(jq -r -e '.general .friendautoupd' $userconfigfile)"
                hidesensitive="$(jq -r -e '.general .hidesensitive' $userconfigfile)"
                serial="$(jq -r -e '.extra_cmdline .sn' $userconfigfile)"
                rdhash="$(jq -r -e '.general .rdhash' $userconfigfile)"
                zimghash="$(jq -r -e '.general .zimghash' $userconfigfile)"
                mac1="$(jq -r -e '.extra_cmdline .mac1' $userconfigfile)"
        else
                echo "ERROR ! User config file : $userconfigfile not found"
        fi

        [ -z "$redpillmake" ] || [ "$redpillmake" = "null" ] && echo "redpillmake setting not found while reading $userconfigfile, defaulting to dev" && redpillmake="dev"

}

function createcustominitfile() {

        readconfig

        echo "Creating custom initrd structure"

        mkdir -p customtemp && cd customtemp
        mkdir -p usr/lib/modules/
        mkdir -p usr/sbin/

        #### CREATE modprobe file

        MODPROBE=$(cat ${CONFIGFILES}/${model}/${version}/config.json | jq -r -e ' .extra .ramdisk_copy' | sed -e 's/"//g' | grep modprobe | sed -s 's/@@@COMMON@@@/\/home\/tc\/config\/_common/' | awk -F: '{print $1}')

        cat $MODPROBE >usr/sbin/modprobe

        chmod 777 usr/sbin/modprobe

        getstaticmodule $2

        mkdir -p exts && cp -arfp ${PAYLOADDIR}/* exts/

        #### CREATE exec.sh

        platformid="$(cat ${PAYLOADDIR}/platform)"
        extensionids="$(cat ${PAYLOADDIR}/extensions | awk '!/0$/{printf $0 " " }/0$/')"

        cat <<EOF >exts/exec.sh
#!/usr/bin/env sh

cd "$(dirname "\${0}")" || exit 1 # get to the script directory realiably in POSIX
PLATFORM_ID="$platformid"
EXTENSION_IDS="$extensionids"

_load_kmods(){

if [ -f ./mods_load.sh ] ; then
echo ":: Loading custom modules... [  OK  ]"       
./mods_load.sh
fi

}

_run_scripts(){

case \$1 in
on_boot)        
echo "Executing Junior scripts"
./on_boot.sh
;;
on_os_load)
echo "Executing OS load scripts"
./on_os_load.sh
;;
esac

}

cd /exts

case \$1 in
load_kmods)
  _load_kmods >> /exts/extlog.log
  ;;
on_boot_scripts)
  _run_scripts "on_boot" 2>&1 >> /exts/extlog.log
;;
on_os_load_scripts)
  _run_scripts "on_os_load" 2>&1 >> /exts/extlog.log
   cp /exts/extlog.log /tmpRoot/.log.junior/
  mkdir -p /tcrp && cd /dev && mount synoboot3 /tcrp && mkdir -p /tcrp/extlog && cp -rf /var/log/* /tcrp/extlog/ && cp /exts/extlog.log /tcrp/extlog/ && umount /tcrp
  ;;
*)
  if [ \$# -lt 1 ]; then
    echo "Usage: \$0 ACTION_NAME <...args>"
  else
    echo "Invalid ACTION_NAME=\${1}"
  fi
  exit 1
  ;;
esac

EOF

        chmod 777 exts/exec.sh

        echo "I'm in $PWD and i'm Creating custom.gz file and placing it in place /home/tc/custom.gz"

        find . | cpio -o -H newc -R root:root >/home/tc/custom.gz

        ls -ltr "/home/tc/custom.gz"

}

function syntaxcheck() {

        if [ "$1" == "extadd" ] || [ "$1" == "extremove" ] || [ "$1" == "processexts" ] || [ "$1" == "createcustominitfile" ]; then

                echo "Error : $0 Insufficient number of arguments : $#, command $1, option $2"

                case $1 in
                extadd)
                        echo "example : $0 extadd https://raw.githubusercontent.com/pocopico/rp-ext/master/vmxnet3/rpext-index.json ds3622xsp_42962"
                        ;;
                extremove)
                        echo "example : $0 extremove https://raw.githubusercontent.com/pocopico/rp-ext/master/vmxnet3/rpext-index.json ds3622xsp_42962"
                        ;;
                processexts)
                        echo "example : $0 $1 ds3622xsp_42962"
                        ;;
                createcustominitfile)
                        echo "example : $0 createcustominitfile ds3622xsp_42962"
                        ;;
                esac
        else
                echo "$0, $1 is an invalid command. Valid commands are : extadd, extremove, processexts, createcustominitfile"

        fi

        exit 1

}

# ./newcustom.sh extadd https://raw.githubusercontent.com/pocopico/rp-ext/master/vmxnet3/rpext-index.json ds3622xsp_42951
#$1 $2 $3

echo "$(date "+%Y-%b-%d-%H:%m") CMD LOGGED : $0 , $@" >>$0.log

case $1 in

extadd)
        [ $# -lt 3 ] && syntaxcheck $@
        extadd $@
        ;;

extremove)
        [ $# -lt 2 ] && syntaxcheck $@
        extremove $@
        ;;

createcustominitfile)
        [ $# -lt 2 ] && syntaxcheck $@
        createcustominitfile $@
        ;;

processexts)
        [ $# -lt 2 ] && syntaxcheck $@
        processexts $@
        ;;

*)
        syntaxcheck $@
        ;;
esac
