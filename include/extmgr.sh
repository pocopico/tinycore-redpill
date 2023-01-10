#!/bin/bash

function extadd() {

        extvars $1 $2

        [ ! -d payload ] && mkdir payload
        cd payload

        [ ! -f platform ] && echo "$platform" >platform

        [ -f extensions ] && [ $(grep $extid extensions | wc -l) -gt 0 ] && echo "Extension $extid has been already added" && return
        echo -n "Adding $extid"
        [ ! -d $extid ] && mkdir $extid

        echo "$ext" >$extid/rpext-index.json

        echo "$extid" >>extensions
        echo " -> Done"

}

function extremove() {

        extvars $1 $2

        [ ! -d payload ] && mkdir payload

        cd payload

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

        cd payload

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
                        echo "cd $extid && ./$onboot && cd .." >>on_boot.sh
                fi
                if [ $(echo $onosload | wc -l) -gt 0 ] && [ $(grep $extid on_os_load.sh | wc -l) -eq 0 ] && [ "$onosload" != "null" ]; then
                        echo "Adding os load script"
                        echo "echo -n \":: Executing $extid os load scripts ... \" && cd $extid && ./$onosload && cd .. " >>on_os_load.sh
                fi
        done

        chmod 777 *.sh */*.sh

}

function createcustominitfile() {

        echo "Creating custom initrd structure"

        mkdir -p customtemp && cd customtemp
        mkdir -p usr/lib/modules/
        mkdir -p usr/sbin/

        #### CREATE modprobe file

        cat <<EOF >usr/sbin/modprobe
#!/usr/bin/sh
for arg in "\$@"
do
  if [ "\$arg" = "elevator-iosched" ]; then
    /sbin/insmod /usr/lib/modules/rp.ko
    rm /usr/lib/modules/rp.ko
    rm /sbin/modprobe
    exit 0
  fi
done
exit 1
EOF

        chmod 777 usr/sbin/modprobe

        echo "getredpillmodule and place it under usr/lib/modules/"
        cp /home/tc/redpill.ko usr/lib/modules

        mkdir -p exts && cp -arfp /home/tc/payload/* exts/

        #### CREATE exec.sh

        platformid="$(cat /home/tc/payload/platform)"
        extensionids="$(cat /home/tc/payload/extensions | awk '!/0$/{printf $0 " " }/0$/')"

        cat <<EOF >exts/exec.sh
#!/usr/bin/env sh

cd "$(dirname "\${0}")" || exit 1 # get to the script directory realiably in POSIX
PLATFORM_ID="$platformid"
EXTENSION_IDS="$extensionids"

_load_kmods(){

echo ":: Loading custom modules... [  OK  ]"       
./mods_load.sh

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
  _load_kmods
  ;;
on_boot_scripts)
  _run_scripts 'on_boot'
  ;;
on_os_load_scripts)
  _run_scripts 'on_os_load'
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

        echo "Creating custom.gz file and placing it in place"

        sudo find . | sudo cpio -o -H newc -R root:root >../custom.gz

}

# ./newcustom.sh extadd https://raw.githubusercontent.com/pocopico/rp-ext/master/vmxnet3/rpext-index.json ds3622xsp_42951
$1 $2 $3
