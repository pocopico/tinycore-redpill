#!/bin/bash
#
# Author :
# Date : 220914
# Version : 0.9.2.6
#
#
# User Variables :

rploaderver="0.9.2.6"
build="main"
redpillmake="prod"

rploaderfile="https://raw.githubusercontent.com/pocopico/tinycore-redpill/$build/rploader.sh"
rploaderrepo="https://github.com/pocopico/tinycore-redpill/raw/$build/"

redpillextension="https://github.com/pocopico/rp-ext/raw/main/redpill${redpillmake}/rpext-index.json"
modextention="https://github.com/pocopico/rp-ext/raw/main/rpext-index.json"
modalias4="https://raw.githubusercontent.com/pocopico/tinycore-redpill/$build/modules.alias.4.json.gz"
modalias3="https://raw.githubusercontent.com/pocopico/tinycore-redpill/$build/modules.alias.3.json.gz"
dtcbin="https://raw.githubusercontent.com/pocopico/tinycore-redpill/$build/tools/dtc"
dtsfiles="https://raw.githubusercontent.com/pocopico/tinycore-redpill/$build"
timezone="UTC"
ntpserver="pool.ntp.org"
userconfigfile="/home/tc/user_config.json"

fullupdatefiles="custom_config.json custom_config_jun.json global_config.json modules.alias.3.json.gz modules.alias.4.json.gz rpext-index.json user_config.json rploader.sh"

# END Do not modify after this line
######################################################################################################

# extract nano  LD_LIBRARY_PATH=/home/tc/archive/lib /home/tc/archive/synoarchive.nano -xvf ../synology_geminilake_dva1622.pat

function history() {

    cat <<EOF
    --------------------------------------------------------------------------------------
    0.7.0.0 Added build for version greater than 42218
    0.7.0.1 Added required extension parsing adding and downloading
    0.7.0.2 Added usb patch in patchdtc
    0.7.0.3 Added portnumber on patchdtc
    0.7.0.4 Make sure that local cache folder is created early in the process
    0.7.0.5 Enabled interactive
    0.7.0.6 Added save/restore session functions
    0.7.0.7 Added a check date function
    0.7.0.8 Added the ability to use local dtb file
    0.7.0.9 Added flyride satamap review
    0.7.1.0 Added the history, version and enhanced patchdtc function
    0.7.1.1 Added a syntaxcheck function
    0.7.1.2 Added sync time with NTP server : pool.ntp.org (Set timezone and ntpserver variables accordingly )
    0.7.1.3 Added the option to create JUN mod loader (By Jumkey)
    0.7.1.4 Added the use of the additional custom_config_jun.json for JUN mod loader creation
    0.7.1.5 Updated satamap function to support higher the 9 port counts per HBA.
    0.7.1.6 Updated satamap function to fix the broken q35 KVM controller, and to stop scanning for CD-ROM's
    0.7.1.7 Updated serialgen function to include the option for using the realmac
    0.7.1.8 Updated satamap function to fine tune SATA port identification and identify SATABOOT
    0.7.1.9 Updated patchdtc function to fix wrong port identification for VMware hosted systems
    0.8.0.0 Stable version. All new features will be moved to develop repo
    0.9.0.0 Development version. Moving all new features to development build
    0.9.0.1 Updated postupdate to facilitate update to update2
    0.9.0.2 Added system monitor function 
    0.9.0.3 Updated satamap to support DUMMY PORT detection 
    0.9.0.4 More satamap fixes
    0.9.0.5 Added the option to get grub variables into user_config.json
    0.9.0.6 Experimental DVA1622 (geminilake) addition
    0.9.0.7 Experimental DVA1622 serialgen
    0.9.0.8 Experimental DVA1622 increase disk count to 16
    0.9.0.9 Fixed missing bspatch
    0.9.1.0 Added dtc depth patch
    0.9.1.1 Default action for DTB system is to use the dtbpatch by fbelavenuto
    0.9.1.2 Fixed a jq issue in listextension
    0.9.1.3 Fixed bsdiff not found issue
    0.9.1.4 Fixed overlaping downloadextractor processes
    0.9.1.5 Enhanced postupdate process to update user_config.json to new format
    0.9.1.6 Fixed compressed non-compressed RAMDISK issue 
    0.9.1.7 Enhanced build process to update user_config.json during build process 
    0.9.1.8 Enhanced build process to create friend files
    0.9.1.9 Further enhanced build process 
    0.9.2.0 Introducing TCRP Friend
    0.9.2.1 If TCRP Friend is used then default option will be TCRP Friend
    0.9.2.2 Upgrade your system by adding TCRP Friend with command bringfriend
    0.9.2.3 Adding experimental DS2422+ support
    0.9.2.4 Added the redpillmake variable to select between prod and dev modules
    0.9.2.5 Adding experimental RS4021xs+ support
    0.9.2.5 Added the downloadupgradepat action **experimental
    --------------------------------------------------------------------------------------
EOF

}

function httpconf() {

    cat >/home/tc/lighttpd.conf <<EOF
server.document-root = "/home/tc/"
server.modules  = ( "mod_cgi" , "mod_alias" )
server.errorlog             = "/home/tc/error.log"
server.pid-file             = "/home/tc/lighttpd.pid"
server.username             = "tc"
server.groupname            = "staff"
server.port                 = 80
alias.url       = ( "/rploader/" => "/home/tc/" )
cgi.assign = ( ".sh" => "/usr/local/bin/bash" )
index-file.names           = ( "index.html","index.htm", "index.sh" )
EOF

    sudo lighttpd -f /home/tc/lighttpd.conf

}

function getgrubconf() {

    tcrpdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"
    grubdisk="${tcrpdisk}1"

    echo "Mounting bootloader disk to get grub contents"
    sudo mount /dev/$grubdisk

    if [ $(df | grep -i $grubdisk | wc -l) -gt 0 ]; then
        echo -n "Mounted succesfully : $(df -h | grep $grubdisk)"
        [ -f /mnt/$grubdisk/boot/grub/grub.cfg ] && [ $(cat /mnt/$grubdisk/boot/grub/grub.cfg | wc -l) -gt 0 ] && echo "  -> Grub cfg is accessible and readable"
    else
        echo "Couldnt mount device : $grubdisk "
        exit 99
    fi

    echo "Getting known loader grub variables"

    grep pid /mnt/$grubdisk/boot/grub/grub.cfg >/tmp/grub.vars

    while IFS=" " read -r -a line; do
        printf "%s\n" "${line[@]}"
    done </tmp/grub.vars | egrep -i "sataportmap|sn|pid|vid|mac|hddhotplug|diskidxmap|netif_num" | sort | uniq >/tmp/known.vars

    if [ -f /tmp/known.vars ]; then
        echo "Sourcing vars, found in grub : "
        . /tmp/known.vars
        rows="%-15s| %-15s | %-10s | %-10s | %-10s | %-15s | %-15s %c\n"
        printf "$rows" Serial Mac Netif_num PID VID SataPortMap DiskIdxMap
        printf "$rows" $sn $mac1 $netif_num $pid $vid $SataPortMap $DiskIdxMap

        echo "Checking user config against grub vars"

        for var in pid vid sn mac1 SataPortMap DiskIdxMap; do
            if [ $(jq -r .extra_cmdline.$var user_config.json) == "${!var}" ]; then
                echo "Grub var $var = ${!var} Matches your user_config.json"
            else
                echo "Grub var $var = ${!var} does not match your user_config.json variable which is set to : $(jq -r .extra_cmdline.$var user_config.json) "
                echo "Should we populate user_config.json with these variables ? [Yy/Nn] "
                read answer
                if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
                    json="$(jq --arg newvar "${!var}" '.extra_cmdline.'$var'= $newvar' user_config.json)" && echo -E "${json}" | jq . >user_config.json
                else
                    echo "OK, you can edit yourself later"
                fi
            fi
        done

    else

        echo "Could not read variables"
    fi

}

function monitor() {

    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"
    mount /dev/${loaderdisk}1
    mount /dev/${loaderdisk}2

    while [ -z "$GATEWAY_INTERFACE" ]; do
        clear
        echo -e "-------------------------------System Information----------------------------"
        echo -e "Hostname:\t\t"$(hostname) "uptime:\t\t\t"$(uptime | awk '{print $3,$4}' | sed 's/,//')
        echo -e "Manufacturer:\t\t"$(cat /sys/class/dmi/id/chassis_vendor) "Product Name:\t\t"$(cat /sys/class/dmi/id/product_name)
        echo -e "Version:\t\t"$(cat /sys/class/dmi/id/product_version)
        echo -e "Serial Number:\t\t"$(sudo cat /sys/class/dmi/id/product_serial)
        echo -e "Machine Type:\t\t"$(
            vserver=$(lscpu | grep Hypervisor | wc -l)
            if [ $vserver -gt 0 ]; then echo "VM"; else echo "Physical"; fi
        ) "Operating System:\t"$(grep PRETTY_NAME /etc/os-release | awk -F \= '{print $2}')
        echo -e "Kernel:\t\t\t"$(uname -r)
        echo -e ""$(lscpu | head -1)"\t" "Processor Name:\t\t"$(awk -F':' '/^model name/ {print $2}' /proc/cpuinfo | uniq | sed -e 's/^[ \t]*//')
        echo -e "Active Users:\t\t"$(who -u | cut -d ' ' -f1 | grep -v USER | xargs -n1)
        echo -e "System Main IP:\t\t"$(ifconfig | grep inet | awk '{print $2}' | awk -F \: '{print $2}')
        [ $(ps -ef | grep -i sshd | wc -l) -gt 0 ] && echo -e "SSHD connections ready" || echo -e "SSHD connections not ready"
        echo -e "-------------------------------Loader boot entries------------------------------"
        grep -i menuentry /mnt/${loaderdisk}1/boot/grub/grub.cfg | awk -F \' '{print $2}'
        echo -e "-------------------------------CPU/Memory Usage------------------------------"
        echo -e "Memory Usage:\t"$(free | awk '/Mem/{printf("%.2f%"), $3/$2*100}')
        echo -e "Swap Usage:\t"$(free | awk '/Swap/{printf("%.2f%"), $3/$2*100}')
        echo -e "CPU Usage:\t"$(cat /proc/stat | awk '/cpu/{printf("%.2f%\n"), ($2+$4)*100/($2+$4+$5)}' | awk '{print $0}' | head -1)
        echo -e "-------------------------------Disk Usage >80%-------------------------------"
        df -Ph | grep -v loop
        [ $(lscpu | grep Hypervisor | wc -l) -gt 0 ] && echo "$(hostname) is a VM"

        echo "Press ctrl-c to exti"
        sleep 10
    done

}

function syntaxcheck() {

    if [ $# -lt 2 ] && [ "$1" == "download" ] || [ "$1" == "build" ] || [ "$1" == "ext" ] || [ "$1" == "restoresession" ] || [ "$1" == "listmods" ] || [ "$1" == "serialgen" ] || [ "$1" == "patchdtc" ] || [ "$1" == "postupdate" ]; then

        echo "Error : Number of arguments : $#, options $@ "
        case $1 in

        download)
            echo "Syntax error, You have to specify one of the existing platforms" && getPlatforms
            ;;

        build)
            echo "Syntax error, You have to specify one of the existing platforms" && getPlatforms
            ;;

        ext)
            echo "Syntax error, You have to specify one of the existing platforms, the action and the extension URL"
            echo "example:"
            echo "rploader.sh ext apollolake-7.0.1-42218 add https://raw.githubusercontent.com/pocopico/rp-ext/master/e1000/rpext-index.json"
            echo "or for auto detect use"
            echo "rploader.sh ext apollolake-7.0.1-42218 auto"
            ;;

        restoresession)
            echo "Syntax error, You have to specify one of the existing platforms" && getPlatforms
            ;;

        listmods)
            echo "Syntax error, You have to specify one of the existing platforms" && getPlatforms
            ;;

        serialgen)
            echo "Syntax error, You have to specify one of the existing models"
            echo "DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xs+ FS6400 DVA3219 DVA3221 DS1621+ DVA1622 DS2422+ RS4021xs+"
            ;;

        patchdtc)
            echo "Syntax error, You have to specify one of the existing platforms" && getPlatforms
            ;;

        postupdate)
            echo "Syntax error, You have to specify one of the existing platforms" && getPlatforms
            ;;

        *)
            echo "Syntax error, not valid arguments or not enough options"
            showhelp
            ;;

        esac

        exit 99

    else
        return
    fi

}

function version() {

    shift 1
    echo $rploaderver

    [ "$1" == "history" ] && history

}

function savesession() {

    lastsessiondir="/mnt/${tcrppart}/lastsession"

    echo -n "Saving user session for future use. "

    [ ! -d ${lastsessiondir} ] && sudo mkdir ${lastsessiondir}

    echo -n "Saving current extensions "

    cat /home/tc/redpill-load/custom/extensions/*/*json | jq '.url' >${lastsessiondir}/extensions.list

    [ -f ${lastsessiondir}/extensions.list ] && echo " -> OK !"

    echo -n "Saving current user_config.json "

    cp /home/tc/user_config.json ${lastsessiondir}/user_config.json

    [ -f ${lastsessiondir}/user_config.json ] && echo " -> OK !"

}

function restoresession() {

    lastsessiondir="/mnt/${tcrppart}/lastsession"

    if [ -d $lastsessiondir ]; then

        echo -n "Found last user session :  , restore session ? [yY/nN] : "
        read answer

        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then

            if [ -d $lastsessiondir ] && [ -f ${lastsessiondir}/extensions.list ]; then
                for extension in $(cat ${lastsessiondir}/extensions.list); do
                    echo "Adding extension ${extension} "
                    cd /home/tc/redpill-load/ && ./ext-manager.sh add "$(echo $extension | sed -s 's/"//g' | sed -s 's/,//g')"
                done
            fi
            if [ -d $lastsessiondir ] && [ -f ${lastsessiondir}/user_config.json ]; then
                echo "Copying last user_config.json"
                cp ${lastsessiondir}/user_config.json /home/tc
            fi

        fi
    else
        echo "OK, we will not restore last session"
    fi
}

function downloadextractor() {
    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"
    tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
    local_cache="/mnt/${tcrppart}/auxfiles"
    temp_folder="/tmp/synoesp"

    if [ -d ${local_cache/extractor /} ] && [ -f ${local_cache}/extractor/scemd ]; then

        echo "Found extractor locally cached"

        echo "Copying required libraries to local lib directory"
        sudo cp /mnt/${tcrppart}/auxfiles/extractor/lib* /lib/
        echo "Linking lib to lib64"
        [ ! -h /lib64 ] && sudo ln -s /lib /lib64
        echo "Copying executable"
        sudo cp /mnt/${tcrppart}/auxfiles/extractor/scemd /bin/syno_extract_system_patch

        echo "Removing temp folder /tmp/synoesp"
        rm -rf $temp_folder

        echo "Checking if tool is accessible"
        /bin/syno_extract_system_patch 2>&1 >/dev/null
        if [ $? -eq 255 ]; then echo "Executed succesfully"; else echo "Cound not execute"; fi

    else

        echo "Getting required extraction tool"
        echo "------------------------------------------------------------------"
        echo "Checking tinycore cache folder"

        [ -d $local_cache ] && echo "Found tinycore cache folder, linking to home/tc/custom-module" && [ ! -h /home/tc/custom-module ] && sudo ln -s $local_cache /home/tc/custom-module

        echo "Creating temp folder /tmp/synoesp"

        mkdir ${temp_folder}

        if [ -d /home/tc/custom-module ] && [ -f /home/tc/custom-module/*42218*.pat ]; then

            patfile=$(ls /home/tc/custom-module/*42218*.pat | head -1)
            echo "Found custom pat file ${patfile}"
            echo "Processing old pat file to extract required files for extraction"
            tar -C${temp_folder} -xf /${patfile} rd.gz
        else
            curl --location https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3622xs%2B_42218.pat --output /home/tc/oldpat.tar.gz
            [ -f /home/tc/oldpat.tar.gz ] && tar -C${temp_folder} -xf /home/tc/oldpat.tar.gz rd.gz
        fi

        echo "Entering synoesp"
        cd ${temp_folder}

        xz -dc <rd.gz >rd 2>/dev/null || echo "extract rd.gz"
        echo "finish"
        cpio -idm <rd 2>&1 || echo "extract rd"
        mkdir extract

        mkdir /mnt/${tcrppart}/auxfiles && cd /mnt/${tcrppart}/auxfiles

        echo "Copying required files to local cache folder for future use"

        mkdir /mnt/${tcrppart}/auxfiles/extractor

        for file in usr/lib/libcurl.so.4 usr/lib/libmbedcrypto.so.5 usr/lib/libmbedtls.so.13 usr/lib/libmbedx509.so.1 usr/lib/libmsgpackc.so.2 usr/lib/libsodium.so usr/lib/libsynocodesign-ng-virtual-junior-wins.so.7 usr/syno/bin/scemd; do
            echo "Copying $file to /mnt/${tcrppart}/auxfiles"
            cp $file /mnt/${tcrppart}/auxfiles/extractor
        done

        echo "Copying required libraries to local lib directory"
        sudo cp /mnt/${tcrppart}/auxfiles/extractor/lib* /lib/
        echo "Linking lib to lib64"
        [ ! -h /lib64 ] && sudo ln -s /lib /lib64
        echo "Copying executable"
        sudo cp /mnt/${tcrppart}/auxfiles/extractor/scemd /bin/syno_extract_system_patch

        echo "Removing temp folder /tmp/synoesp"
        rm -rf $temp_folder

        echo "Checking if tools is accessible"
        /bin/syno_extract_system_patch
        if [ $? -eq 255 ]; then echo "Executed succesfully"; else echo "Cound not execute"; fi

    fi

}

function processpat() {

    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"
    tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
    local_cache="/mnt/${tcrppart}/auxfiles"
    temp_pat_folder="/tmp/pat"

    if [ "${TARGET_PLATFORM}" = "apollolake" ]; then
        SYNOMODEL="ds918p_$TARGET_REVISION" && MODEL="DS918+"
    elif [ "${TARGET_PLATFORM}" = "bromolow" ]; then
        SYNOMODEL="ds3615xs_$TARGET_REVISION" && MODEL="DS3615xs"
    elif [ "${TARGET_PLATFORM}" = "broadwell" ]; then
        SYNOMODEL="ds3617xs_$TARGET_REVISION" && MODEL="DS3617xs"
    elif [ "${TARGET_PLATFORM}" = "broadwellnk" ]; then
        SYNOMODEL="ds3622xsp_$TARGET_REVISION" && MODEL="DS3622xs+"
    elif [ "${TARGET_PLATFORM}" = "v1000" ]; then
        SYNOMODEL="ds1621p_$TARGET_REVISION" && MODEL="DS1621+"
    elif [ "${TARGET_PLATFORM}" = "denverton" ]; then
        SYNOMODEL="dva3221_$TARGET_REVISION" && MODEL="DVA3221"
    elif [ "${TARGET_PLATFORM}" = "geminilake" ]; then
        SYNOMODEL="ds920p_$TARGET_REVISION" && MODEL="DS920+"
    elif [ "${TARGET_PLATFORM}" = "dva1622" ]; then
        SYNOMODEL="dva1622_$TARGET_REVISION" && MODEL="DVA1622"
    elif [ "${TARGET_PLATFORM}" = "ds2422p" ]; then
        SYNOMODEL="ds2422p_$TARGET_REVISION" && MODEL="DS2422+"
    elif [ "${TARGET_PLATFORM}" = "rs4021xsp" ]; then
        SYNOMODEL="rs4021xsp_$TARGET_REVISION" && MODEL="RS4021xs+"
    fi

    if [ ! -d "${temp_pat_folder}" ]; then
        echo "Creating temp folder ${temp_pat_folder} "
        mkdir ${temp_pat_folder} && cd ${temp_pat_folder}
    fi

    echo "Checking for cached pat file"
    [ -d $local_cache ] && echo "Found tinycore cache folder, linking to home/tc/custom-module" && [ ! -h /home/tc/custom-module ] && sudo ln -s $local_cache /home/tc/custom-module

    if [ -d ${local_cache} ] && [ -f ${local_cache}/*${SYNOMODEL}*.pat ] || [ -f ${local_cache}/*${MODEL}*${TARGET_REVISION}*.pat ]; then

        [ -f /home/tc/custom-module/*${SYNOMODEL}*.pat ] && patfile=$(ls /home/tc/custom-module/*${SYNOMODEL}*.pat | head -1)
        [ -f ${local_cache}/*${MODEL}*${TARGET_REVISION}*.pat ] && patfile=$(ls /home/tc/custom-module/*${MODEL}*${TARGET_REVISION}*.pat | head -1)

        echo "Found locally cached pat file ${patfile}"

        testarchive "${patfile}"
        if [ ${isencrypted} = "no" ]; then
            echo "File ${patfile} is already unencrypted"
            echo "Copying file to /home/tc/redpill-load/cache folder"
            cp ${patfile} /home/tc/redpill-load/cache/
        elif [ ${isencrypted} = "yes" ]; then
            [ -f /home/tc/redpill-load/cache/${SYNOMODEL}.pat ] && testarchive /home/tc/redpill-load/cache/${SYNOMODEL}.pat
            if [ -f /home/tc/redpill-load/cache/${SYNOMODEL}.pat ] && [ ${isencrypted} = "no" ]; then
                echo "Unecrypted file is already cached in :  /home/tc/redpill-load/cache/${SYNOMODEL}.pat"
                patfile="/home/tc/redpill-load/cache/${SYNOMODEL}.pat"
            else
                echo "Extracting encrypted pat file : ${patfile} to ${temp_pat_folder}"
                sudo /bin/syno_extract_system_patch ${patfile} ${temp_pat_folder} || echo "extract latest pat"
                echo "Creating unecrypted pat file ${SYNOMODEL}.pat to /home/tc/redpill-load/cache folder "
                mkdir -p /home/tc/redpill-load/cache/
                cd ${temp_pat_folder} && tar -czf /home/tc/redpill-load/cache/${SYNOMODEL}.pat ./
                patfile="/home/tc/redpill-load/cache/${SYNOMODEL}.pat"

            fi

        else

            echo "Something went wrong, please check cache files"
            exit 99
        fi

        tar xvf /home/tc/redpill-load/cache/${SYNOMODEL}.pat ./VERSION && . ./VERSION && rm ./VERSION
        os_sha256=$(sha256sum ${patfile} | awk '{print $1}')
        echo "Pat file  sha256sum is : $os_sha256"

        echo -n "Checking config file existence -> "
        if [ -f "/home/tc/redpill-load/config/$MODEL/${major}.${minor}.${micro}-${buildnumber}/config.json" ]; then
            echo "OK"
            configfile="/home/tc/redpill-load/config/$MODEL/${major}.${minor}.${micro}-${buildnumber}/config.json"
        else
            echo "No config file found, please use the proper repo, clean and download again"
            exit 99
        fi

        echo -n "Editing config file -> "
        sed -i "/\"os\": {/!b;n;n;n;c\"sha256\": \"$os_sha256\"" ${configfile}
        echo -n "Verifying config file -> "
        verifyid="$(cat ${configfile} | jq -r -e '.os .sha256')"

        if [ "$os_sha256" == "$verifyid" ]; then
            echo "OK ! "
        else
            echo "config file, os sha256 verify FAILED, check ${configfile} "
            exit 99
        fi

        echo "Clearing temp folders"
        sudo rm -rf ${temp_pat_folder}

        return

    else

        echo "Could not find pat file locally cached"
        configdir="/home/tc/redpill-load/config/${MODEL}/${TARGET_VERSION}-${TARGET_REVISION}"
        configfile="${configdir}/config.json"
        pat_url=$(cat ${configfile} | jq '.os .pat_url' | sed -s 's/"//g')
        echo -e "Configdir : $configdir \nConfigfile: $configfile \nPat URL : $pat_url"
        echo "Downloading pat file from URL : ${pat_url} "

        if [ $(df -h /${local_cache} | grep mnt | awk '{print $4}' | cut -c 1-3) -le 370 ]; then
            echo "No adequate space on ${local_cache} to download file into cache folder, clean up the space and restart"
            exit 99
        fi

        [ -n $pat_url ] && curl --location ${pat_url} -o "/${local_cache}/${SYNOMODEL}.pat"
        patfile="/${local_cache}/${SYNOMODEL}.pat"
        if [ -f ${patfile} ]; then
            testarchive ${patfile}
        else
            echo "Failed to download PAT file $patfile from ${pat_url} "
            exit 99
        fi

        if [ "${isencrypted}" = "yes" ]; then
            echo "File ${patfile}, has been cached but its encrypted, re-running decrypting process"
            processpat
        else
            return
        fi

    fi

}

function testarchive() {

    archive="$1"
    archiveheader="$(od -bc ${archive} | head -1 | awk '{print $3}')"

    case ${archiveheader} in
    105)
        echo "${archive}, is a Tar file"
        isencrypted="no"
        return 0
        ;;
    255)
        echo "File ${archive}, is  encrypted"
        isencrypted="yes"
        return 1
        ;;
    213)
        echo "File ${archive}, is a compressed tar"
        isencrypted="no"
        ;;
    *)
        echo "Could not determine if file ${archive} is encrypted or not, maybe corrupted"
        ls -ltr ${archive}
        echo ${archiveheader}
        exit 99
        ;;
    esac

}

function addrequiredexts() {

    echo "Processing add_extensions entries found on custom_config.json file : ${EXTENSIONS}"

    for extension in ${EXTENSIONS_SOURCE_URL}; do
        echo "Adding extension ${extension} "
        cd /home/tc/redpill-load/ && ./ext-manager.sh add "$(echo $extension | sed -s 's/"//g' | sed -s 's/,//g')"
    done
    for extension in ${EXTENSIONS}; do
        echo "Updating extension : ${extension} contents for model : ${SYNOMODEL}  "
        cd /home/tc/redpill-load/ && ./ext-manager.sh _update_platform_exts ${SYNOMODEL} ${extension}
    done

    if [ ${TARGET_PLATFORM} = "geminilake" ] || [ ${TARGET_PLATFORM} = "v1000" ] || [ ${TARGET_PLATFORM} = "dva1622" ] || [ ${TARGET_PLATFORM} = "ds2422p" ] || [ ${TARGET_PLATFORM} = "rs4021xsp" ]; then
        #patchdtc
        echo "Patch dtc is superseded by fbelavenuto dtbpatch"
    fi

}

function installapache() {

    echo "Installing apache2 and php module"

    tce-load -iw apache2.4.tcz
    tce-load -iw apache2.4-doc.tcz
    tce-load -iw php-8.0-mod.tcz
    tce-load -iw libnghttp2.tcz
    #cd /usr/local/
    #sudo tar xvf /home/tc/tcrphtml/tc.apache.tar.gz etc/httpd/
    #apachectl start

}

function updateuserconfig() {

    echo "Checking user config for general block"
    generalblock="$(jq -r -e '.general' $userconfigfile)"
    if [ "$generalblock" = "null" ] || [ -n "$generalblock" ]; then
        echo "Result=${generalblock}, File does not contain general block, adding block"

        for field in model version redpillmake zimghash rdhash usb_line sata_line; do
            jsonfile=$(jq ".general+={\"$field\":\"\"}" $userconfigfile)
            echo $jsonfile | jq . >$userconfigfile
        done
    fi
}

function updateuserconfigfield() {

    block="$1"
    field="$2"
    value="$3"

    if [ -n "$1 " ] && [ -n "$2" ]; then
        jsonfile=$(jq ".$block+={\"$field\":\"$value\"}" $userconfigfile)
        echo $jsonfile | jq . >$userconfigfile
    else
        echo "No values to update specified"
    fi
}

removefriend() {

    clear
    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"

    echo "------------------------------------------------------------------------------------------------------------"
    echo "You are not satisfied with TCRP friend."
    echo "Understandable, but you will not be able to perform automatic patching after updates."
    echo "you can still though use the postupdate process instead or just set the default option to SATA or USB as usual"
    echo "------------------------------------------------------------------------------------------------------------"

    echo -n "Do you still want to remove TCRP Friend, please answer [Yy/Nn]"
    read answer

    if [ "${answer}" = "Y" ] || [ "${answer}" = "y" ]; then

        mount /dev/${loaderdisk}1 2>/dev/null
        mount /dev/${loaderdisk}2 2>/dev/null
        mount /dev/${loaderdisk}3 2>/dev/null

        echo "Removing TCRP Friend from ${loaderdisk}3 "
        [ -f /mnt/${loaderdisk}3/initrd-friend ] && sudo rm -rf /mnt/${loaderdisk}3/initrd-friend
        [ -f /mnt/${loaderdisk}3/bzImage-friend ] && sudo rm -rf /mnt/${loaderdisk}3/bzImage-friend
        echo "Removing initrd-dsm and zimage-dsm from ${loaderdisk}3 "
        [ ! "$(sha256sum /mnt/${loaderdisk}3/initrd-dsm | awk '{print $2}')" = "$(sha256sum /mnt/${loaderdisk}1/rd.gz | awk '{print $2}')" ] && cp /mnt/${loaderdisk}3/initrd-dsm /mnt/${loaderdisk}1/rd.gz
        [ -f /mnt/${loaderdisk}3/initrd-dsm ] && sudo rm -rf /mnt/${loaderdisk}3/initrd-dsm
        [ ! "$(sha256sum /mnt/${loaderdisk}3/zImage-dsm | awk '{print $2}')" = "$(sha256sum /mnt/${loaderdisk}1/zImage | awk '{print $2}')" ] && cp /mnt/${loaderdisk}3/zImage-dsm /mnt/${loaderdisk}1/zImage
        [ -f /mnt/${loaderdisk}3/zimage-dsm ] && sudo rm -rf /mnt/${loaderdisk}3/zimage-dsm
        echo "Removing TCRP Friend Grub entry "
        [ $(grep -i "Tiny Core Friend" /mnt/${loaderdisk}1/boot/grub/grub.cfg | wc -l) -eq 1 ] && sed -i "/Tiny Core Friend/,+9d" /mnt/${loaderdisk}1/boot/grub/grub.cfg

        if [ "$MACHINE" = "VIRTUAL" ]; then
            echo "Setting default boot entry to SATA"
            cd /home/tc/redpill-load/ && sudo sed -i "/set default=\"*\"/cset default=\"1\"" /mnt/${loaderdisk}1/boot/grub/grub.cfg
        else
            echo "Setting default boot entry to USB"
            cd /home/tc/redpill-load/ && sudo sed -i "/set default=\"*\"/cset default=\"0\"" /mnt/${loaderdisk}1/boot/grub/grub.cfg
        fi
    else
        echo "OK ! Wise choice !!! "
    fi

}

bringfriend() {

    clear

    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"

    mount /dev/${loaderdisk}1 2>/dev/null
    mount /dev/${loaderdisk}2 2>/dev/null
    mount /dev/${loaderdisk}3 2>/dev/null

    if [ -f /mnt/${loaderdisk}3/lastsession/user_config.json ]; then
        cp /mnt/${loaderdisk}3/lastsession/user_config.json /home/tc/user_config.json
        getgrubconf
    else
        getgrubconf
    fi

    if [ -f /mnt/${loaderdisk}3/bzImage-friend ] && [ -f /mnt/${loaderdisk}3/initrd-friend ] && [ -f /mnt/${loaderdisk}3/zImage-dsm ] && [ -f /mnt/${loaderdisk}3/initrd-dsm ] && [ -f /mnt/${loaderdisk}3/user_config.json ] && [ $(grep -i "Tiny Core Friend" /mnt/${loaderdisk}1/boot/grub/grub.cfg | wc -l) -eq 1 ]; then
        echo "Your TCRP friend seems in place, do you want to re-run the process ?"
        read answer
        if [ "${answer}" = "Y" ] || [ "${answer}" = "y" ]; then
            echo "OK re-running the TCRP Friend bring over process"
        else
            echo "Wise choice"
            exit 0
        fi
    fi

    echo "You are upgrading your system with TCRP friend."
    echo "Your system will still be able to boot using the USB/SATA options."
    echo "After bringing over TCRP Friend, The default boot option will be set TCRP Friend."
    echo "You will still have the option to move to SATA/USB but for automatic patching after an update,"
    echo "please leave the default to TCRR Friend"

    echo -n "If you agree with the above, please answer [Yy/Nn]"
    read answer

    if [ "${answer}" = "Y" ] || [ "${answer}" = "y" ]; then

        if [ ! -f /mnt/${loaderdisk}3/initrd-friend ] || [ ! -f /mnt/${loaderdisk}3/bzImage-friend ]; then

            [ ! -f /home/tc/friend/initrd-friend ] && [ ! -f /home/tc/friend/bzImage-friend ] && bringoverfriend

            if [ -f /home/tc/friend/initrd-friend ] && [ -f /home/tc/friend/bzImage-friend ]; then

                cp /home/tc/friend/initrd-friend /mnt/${loaderdisk}3/
                cp /home/tc/friend/bzImage-friend /mnt/${loaderdisk}3/

            fi

        fi

        if [ -f /mnt/${loaderdisk}3/initrd-friend ] || [ -f /mnt/${loaderdisk}3/bzImage-friend ]; then

            [ $(grep -i "Tiny Core Friend" /mnt/${loaderdisk}1/boot/grub/grub.cfg | wc -l) -eq 1 ] || tcrpfriendentry | sudo tee --append /mnt/${loaderdisk}1/boot/grub/grub.cfg

            # Compining rd.gz and custom.gz

            echo "Compining rd.gz and custom.gz and copying zimage to ${loaderdisk}3 "

            [ ! -d /home/tc/rd.temp ] && mkdir /home/tc/rd.temp
            [ -d /home/tc/rd.temp ] && cd /home/tc/rd.temp
            if [ "$(od /mnt/${loaderdisk}1/rd.gz | head -1 | awk '{print $2}')" = "000135" ]; then
                RD_COMPRESSED="true"
            else
                RD_COMPRESSED="false"
            fi

            if [ "$RD_COMPRESSED" = "false" ]; then
                echo "Ramdisk in not compressed "
                cat /mnt/${loaderdisk}1/rd.gz | sudo cpio -idm 2>/dev/null >/dev/null
                cat /mnt/${loaderdisk}1/custom.gz | sudo cpio -idm 2>/dev/null >/dev/null
                sudo chmod +x /home/tc/rd.temp/usr/sbin/modprobe
                (cd /home/tc/rd.temp && sudo find . | sudo cpio -o -H newc -R root:root >/mnt/${loaderdisk}3/initrd-dsm) 2>&1 >/dev/null
            else
                unlzma -dc /mnt/${loaderdisk}1/rd.gz | sudo cpio -idm 2>/dev/null >/dev/null
                cat /mnt/${loaderdisk}1/custom.gz | sudo cpio -idm 2>/dev/null >/dev/null
                sudo chmod +x /home/tc/rd.temp/usr/sbin/modprobe
                (cd /home/tc/rd.temp && sudo find . | sudo cpio -o -H newc -R root:root | xz -9 --format=lzma >/mnt/${loaderdisk}3/initrd-dsm) 2>&1 >/dev/null
            fi

            . /home/tc/rd.temp/etc/VERSION

            MODEL="$(grep upnpmodelname /home/tc/rd.temp/etc/synoinfo.conf | awk -F= '{print $2}' | sed -e 's/"//g')"
            VERSION="${productversion}-${buildnumber}"

            cp -f /mnt/${loaderdisk}1/zImage /mnt/${loaderdisk}3/zImage-dsm

            updateuserconfig

            updateuserconfigfield "general" "model" "$MODEL"
            updateuserconfigfield "general" "version" "${VERSION}"
            updateuserconfigfield "general" "redpillmake" "${redpillmake}"
            zimghash=$(sha256sum /mnt/${loaderdisk}2/zImage | awk '{print $1}')
            updateuserconfigfield "general" "zimghash" "$zimghash"
            rdhash=$(sha256sum /mnt/${loaderdisk}2/rd.gz | awk '{print $1}')
            updateuserconfigfield "general" "rdhash" "$rdhash"

            USB_LINE="$(grep -A 5 "USB," /mnt/${loaderdisk}1/boot/grub/grub.cfg | grep linux | cut -c 16-999)"
            SATA_LINE="$(grep -A 5 "SATA," /mnt/${loaderdisk}1/boot/grub/grub.cfg | grep linux | cut -c 16-999)"

            echo "Updated user_config with USB Command Line : $USB_LINE"
            json=$(jq --arg var "${USB_LINE}" '.general.usb_line = $var' $userconfigfile) && echo -E "${json}" | jq . >$userconfigfile
            echo "Updated user_config with SATA Command Line : $SATA_LINE"
            json=$(jq --arg var "${SATA_LINE}" '.general.sata_line = $var' $userconfigfile) && echo -E "${json}" | jq . >$userconfigfile

            cp $userconfigfile /mnt/${loaderdisk}3/

            echo "Setting default boot entry to TCRP Friend"
            sudo sed -i "/set default=\"*\"/cset default=\"3\"" /mnt/${loaderdisk}1/boot/grub/grub.cfg

            if [ ! -f /mnt/${loaderdisk}3/bzImage-friend ] || [ ! -f /mnt/${loaderdisk}3/initrd-friend ] || [ ! -f /mnt/${loaderdisk}3/zImage-dsm ] || [ ! -f /mnt/${loaderdisk}3/initrd-dsm ] || [ ! -f /mnt/${loaderdisk}3/user_config.json ] || [ ! $(grep -i "Tiny Core Friend" /mnt/${loaderdisk}1/boot/grub/grub.cfg | wc -l) -eq 1 ]; then
                echo "ERROR !!! Something went wrong, please re-run the process"
            fi
            echo "Cleaning up temp files"
            cd /home/tc
            sudo rm -rf /home/tc/friend
            sudo rm -rf /home/tc/rd.temp
            echo "Unmounting file systems"
            sudo umount /dev/${loaderdisk}1
            sudo umount /dev/${loaderdisk}2

        fi

    else

        echo "OK ! its your choice"
        sudo umount /dev/${loaderdisk}1
        sudo umount /dev/${loaderdisk}2
    fi

}

function postupdate() {

    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"

    cd /home/tc

    updateuserconfig
    updateuserconfigfield "general" "model" "$MODEL"
    updateuserconfigfield "general" "version" "${TARGET_VERSION}-${TARGET_REVISION}"
    updateuserconfigfield "general" "redpillmake" "${redpillmake}"
    echo "Creating temp ramdisk space" && mkdir /home/tc/ramdisk

    echo "Mounting partition ${loaderdisk}1" && sudo mount /dev/${loaderdisk}1
    echo "Mounting partition ${loaderdisk}2" && sudo mount /dev/${loaderdisk}2

    zimghash=$(sha256sum /mnt/${loaderdisk}2/zImage | awk '{print $1}')
    updateuserconfigfield "general" "zimghash" "$zimghash"
    rdhash=$(sha256sum /mnt/${loaderdisk}2/rd.gz | awk '{print $1}')
    updateuserconfigfield "general" "rdhash" "$rdhash"

    zimghash=$(sha256sum /mnt/${loaderdisk}2/zImage | awk '{print $1}')
    updateuserconfigfield "general" "zimghash" "$zimghash"
    rdhash=$(sha256sum /mnt/${loaderdisk}2/rd.gz | awk '{print $1}')
    updateuserconfigfield "general" "rdhash" "$rdhash"
    echo "Backing up $userconfigfile "
    cp $userconfigfile /mnt/${loaderdisk}3

    cd /home/tc/ramdisk

    echo "Extracting update ramdisk"

    if [ $(od /mnt/${loaderdisk}2/rd.gz | head -1 | awk '{print $2}') == "000135" ]; then
        sudo unlzma -c /mnt/${loaderdisk}2/rd.gz | cpio -idm 2>&1 >/dev/null
    else
        sudo cat /mnt/${loaderdisk}2/rd.gz | cpio -idm 2>&1 >/dev/null
    fi

    . ./etc.defaults/VERSION && echo "Found Version : ${productversion}-${buildnumber}-${smallfixnumber}"

    echo -n "Do you want to use this for the loader ? [yY/nN] : "
    read answer

    if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then

        echo "Extracting redpill ramdisk"

        if [ $(od /mnt/${loaderdisk}1/rd.gz | head -1 | awk '{print $2}') == "000135" ]; then
            sudo unlzma -c /mnt/${loaderdisk}1/rd.gz | cpio -idm
            RD_COMPRESSED="yes"
        else
            sudo cat /mnt/${loaderdisk}1/rd.gz | cpio -idm
        fi

        . ./etc.defaults/VERSION && echo "The new smallupdate version will be  : ${productversion}-${buildnumber}-${smallfixnumber}"

        echo -n "Do you want to use this for the loader ? [yY/nN] : "
        read answer

        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then

            echo "Recreating ramdisk "

            if [ "$RD_COMPRESSED" = "yes" ]; then
                sudo find . 2>/dev/null | sudo cpio -o -H newc -R root:root | xz -9 --format=lzma >../rd.gz
            else
                sudo find . 2>/dev/null | sudo cpio -o -H newc -R root:root >../rd.gz
            fi

            cd ..

            echo "Adding fake sign" && sudo dd if=/dev/zero of=rd.gz bs=68 count=1 conv=notrunc oflag=append

            echo "Putting ramdisk back to the loader partition ${loaderdisk}1" && sudo cp -f rd.gz /mnt/${loaderdisk}1/rd.gz

            echo "Removing temp ramdisk space " && rm -rf ramdisk

            echo "Done"
        else
            echo "Removing temp ramdisk space " && rm -rf ramdisk
            exit 0

        fi

    fi

}

function postupdatev1() {

    echo "Mounting root to get the latest dsmroot patch in /.syno/patch "

    if [ ! -f /home/tc/redpill-load/user_config.json ]; then
        [ ! -h /home/tc/redpill-load/user_config.json ] && ln -s /home/tc/user_config.json /home/tc/redpill-load/user_config.json
    fi

    if [ $(mount | grep -i dsmroot | wc -l) -le 0 ]; then
        mountdsmroot
        [ $(mount | grep -i dsmroot | wc -l) -le 0 ] && echo "Failed to mount DSM root, cannot continue the postupdate process, returning" && return
    else
        echo "Already mounted"
    fi

    echo "Clearing last created loader "
    rm -f redpill-load/loader.img

    if [ ! -d "/lib64" ]; then
        echo "/lib64 does not exist, bringing linking /lib"
        [ ! -h /lib64 ] && ln -s /lib /lib64
    fi

    if [ ! -n "$(which bspatch)" ]; then

        echo "bspatch does not exist, bringing over from repo"

        curl --location "https://raw.githubusercontent.com/pocopico/tinycore-redpill/$build/tools/bspatch" -O

        chmod 777 bspatch
        sudo mv bspatch /usr/local/bin/

    fi

    echo "Checking available patch"

    if [ -d "/mnt/dsmroot/.syno/patch/" ]; then
        cd /mnt/dsmroot/.syno/patch/
        . ./VERSION
        . ./GRUB_VER
    else
        echo "Patch directory not found, please remember that you have to run update usign DSM manual upgrade first"
        echo "Postupdate is not possible, returning"
        return
    fi

    echo "Found Platform : ${PLATFORM}  Model : $MODEL Version : ${major}.${minor}.${micro}-${buildnumber} "

    echo -n "Do you want to use this for the loader ? [yY/nN] : "
    read answer

    if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
        patfile="$(echo ${MODEL}_${buildnumber} | sed -e 's/\+/p/' | tr '[:upper:]' '[:lower:]').pat"
        echo "Creating pat file ${patfile} using contents of : $(pwd) "
        [ ! -d "/home/tc/redpill-load/cache" ] && mkdir /home/tc/redpill-load/cache/
        tar cfz /home/tc/redpill-load/cache/${patfile} *
        os_sha256=$(sha256sum /home/tc/redpill-load/cache/${patfile} | awk '{print $1}')
        echo "Created pat file with sha256sum : $os_sha256"
        cd /home/tc
    else
        echo "OK, see you later"
        return
    fi

    echo -n "Checking config file existence -> "
    if [ -f "/home/tc/redpill-load/config/$MODEL/${major}.${minor}.${micro}-${buildnumber}/config.json" ]; then
        echo "OK"
        configfile="/home/tc/redpill-load/config/$MODEL/${major}.${minor}.${micro}-${buildnumber}/config.json"
    else
        echo "No config file found, please use the proper repo, clean and download again"
        exit 99
    fi

    echo -n "Editing config file -> "
    sed -i "/\"os\": {/!b;n;n;n;c\"sha256\": \"$os_sha256\"" ${configfile}
    echo -n "Verifying config file -> "
    verifyid="$(cat ${configfile} | jq -r -e '.os .sha256')"

    if [ "$os_sha256" == "$verifyid" ]; then
        echo "OK ! "
    else
        echo "config file, os sha256 verify FAILED, check ${configfile} "
        exit 99
    fi

    removebundledexts

    cd /home/tc/redpill-load/

    addrequiredexts

    echo "Creating loader ${MODEL} ${major}.${minor}.${micro}-${buildnumber} ... "

    sudo ./build-loader.sh ${MODEL} ${major}.${minor}.${micro}-${buildnumber}

    loadername="redpill-${MODEL}_${major}.${minor}.${micro}-${buildnumber}"
    loaderimg=$(ls -ltr /home/tc/redpill-load/images/${loadername}* | tail -1 | awk '{print $9}')

    echo "Moving loader ${loaderimg} to loader.img "
    if [ -f "${loaderimg}" ]; then
        mv -f $loaderimg loader.img
    else
        echo "Failed to find loader ${loaderimg}, exiting"
        exit 99
    fi

    if [ ! -n "$(losetup -j loader.img | awk '{print $1}' | sed -e 's/://')" ]; then
        echo -n "Setting up loader img loop -> "
        sudo losetup -fP ./loader.img
        loopdev=$(losetup -j loader.img | awk '{print $1}' | sed -e 's/://')
        echo "$loopdev"
    else
        echo -n "Loop device exists, removing "
        losetup -d $(losetup -j loader.img | awk '{print $1}' | sed -e 's/://')
        echo -n "Setting up loader img loop -> "
        sudo losetup -fP ./loader.img
        loopdev=$(losetup -j loader.img | awk '{print $1}' | sed -e 's/://')
    fi

    echo -n "Mounting loop disks -> "

    [ ! -d /home/tc/redpill-load/localdiskp1 ] && mkdir /home/tc/redpill-load/localdiskp1
    [ ! -d /home/tc/redpill-load/localdiskp2 ] && mkdir /home/tc/redpill-load/localdiskp2

    [ ! -n "$(mount | grep -i localdiskp1)" ] && sudo mount ${loopdev}p1 localdiskp1
    [ ! -n "$(mount | grep -i localdiskp2)" ] && sudo mount ${loopdev}p2 localdiskp2

    [ -n "mount |grep -i localdiskp1" ] && [ -n "mount |grep -i localdiskp2" ] && echo "mounted succesfully"

    echo -n "Mounting loader disk -> "
    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"

    sudo mount /dev/${loaderdisk}1
    sudo mount /dev/${loaderdisk}2

    [ -n "mount |grep -i ${loaderdisk}1" ] && [ -n "mount |grep -i ${loaderdisk}2" ] && echo "mounted succesfully"

    echo -n "Copying loader files -> "
    echo -n "rd.gz : "
    cp -f /home/tc/redpill-load/localdiskp1/rd.gz /mnt/${loaderdisk}1/rd.gz
    cp -f /home/tc/redpill-load/localdiskp2/rd.gz /mnt/${loaderdisk}2/rd.gz
    [ "$(sha256sum /home/tc/redpill-load/localdiskp1/rd.gz | awk '{print $1}')" == "$(sha256sum /mnt/${loaderdisk}1/rd.gz | awk '{print $1}')" ] && [ "$(sha256sum /home/tc/redpill-load/localdiskp2/rd.gz | awk '{print $1}')" == "$(sha256sum /mnt/${loaderdisk}2/rd.gz | awk '{print $1}')" ] && echo -n "OK !!!"
    echo -n " zImage : "
    cp -f /home/tc/redpill-load/localdiskp1/zImage /mnt/${loaderdisk}1/zImage
    cp -f /home/tc/redpill-load/localdiskp2/zImage /mnt/${loaderdisk}2/zImage
    [ "$(sha256sum /home/tc/redpill-load/localdiskp1/zImage | awk '{print $1}')" == "$(sha256sum /mnt/${loaderdisk}1/zImage | awk '{print $1}')" ] && [ "$(sha256sum /home/tc/redpill-load/localdiskp2/zImage | awk '{print $1}')" == "$(sha256sum /mnt/${loaderdisk}2/zImage | awk '{print $1}')" ] && echo -n "OK !!!"
    echo -n " grub.cfg : "
    cp -f /home/tc/redpill-load/localdiskp1/boot/grub/grub.cfg /mnt/${loaderdisk}1/boot/grub/grub.cfg
    [ "$(sha256sum /home/tc/redpill-load/localdiskp1/boot/grub/grub.cfg | awk '{print $1}')" == "$(sha256sum /mnt/${loaderdisk}1/boot/grub/grub.cfg | awk '{print $1}')" ] && echo "OK !!!"
    echo "Creating tinycore entry"
    tinyentry | sudo tee --append /mnt/${loaderdisk}1/boot/grub/grub.cfg

    echo "Do you want to overwrite your custom.gz as well ? [yY/nN] : "
    read answer

    if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
        echo "Copying custom.gz"
        cp -f /home/tc/redpill-load/localdiskp1/custom.gz /mnt/${loaderdisk}1/custom.gz
        [ "$(sha256sum /home/tc/redpill-load/localdiskp1/custom.gz | awk '{print $1}')" == "$(sha256sum /mnt/${loaderdisk}1/custom.gz | awk '{print $1}')" ] && echo "OK !!!"
    else
        echo "OK, you should be fine keeping your existing custom.gz"
    fi

    echo "Cleaning up... "
    echo -n "Unmounting loaderdisk ${loaderdisk} -> "
    sudo umount /dev/${loaderdisk}1 && sudo umount /dev/${loaderdisk}2
    [ -z $(mount | grep -i ${loaderdisk}1) ] && [ -z $(mount | grep -i ${loaderdisk}2) ] && echo "OK !!!"

    echo -n "Unmounting loader image ${loopdev} -> "
    sudo umount ${loopdev}p1 && sudo umount ${loopdev}p2
    [ -z $(mount | grep -i ${loopdev}p1) ] && [ -z $(mount | grep -i ${loopdev}p2) ] && echo "OK !!!"
    echo -n "Detaching loop loader image -> "
    sudo losetup -d ${loopdev}
    [ -z $(losetup | grep -i loader.img) ] && echo "OK !!!"

    if [ -f /home/tc/redpill-load/loader.img ]; then
        echo -n "Removing loader.img -> "
        sudo rm -rf /home/tc/redpill-load/loader.img
        [ ! -f /home/tc/redpill-load/loader.img ] && echo "OK !!!"
    fi

    echo "Unmounting dsmroot -> "
    [ ! -z "$(mount | grep -i dsmroot)" ] && sudo umount /mnt/dsmroot
    [ -z "$(mount | grep -i dsmroot)" ] && echo "OK !!! "

    echo "Done, closing"

}

function removebundledexts() {

    echo "Entering redpill-load directory"
    cd /home/tc/redpill-load/

    echo "Removing bundled exts directories"
    for bundledext in $(grep ":" bundled-exts.json | awk '{print $2}' | sed -e 's/"//g' | sed -e 's/,/\n/g'); do
        bundledextdir=$(curl --location -s "$bundledext" | jq -r -e '.id')
        if [ -d /home/tc/redpill-load/custom/extensions/${bundledextdir} ]; then
            echo "Removing : ${bundledextdir}"
            sudo rm -rf /home/tc/redpill-load/custom/extensions/${bundledextdir}
        fi

    done

}

function downloadextractorv2() {

    [ ! -d /home/tc/patch-extractor/ ] && mkdir /home/tc/patch-extractor/

    cd /home/tc/patch-extractor/

    [ -f /home/tc/oldpat.tar.gz ] || curl --insecure --location https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3622xs%2B_42218.pat --output /home/tc/oldpat.tar.gz

    tar xf ../oldpat.tar.gz hda1.tgz
    tar xf hda1.tgz usr/lib
    tar xf hda1.tgz usr/syno/sbin

    [ ! -d /home/tc/patch-extractor/lib/ ] && mkdir /home/tc/patch-extractor/lib/

    cp usr/lib/libicudata.so* /home/tc/patch-extractor/lib
    cp usr/lib/libicui18n.so* /home/tc/patch-extractor/lib
    cp usr/lib/libicuuc.so* /home/tc/patch-extractor/lib
    cp usr/lib/libjson.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_program_options.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_locale.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_filesystem.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_thread.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_coroutine.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_regex.so* /home/tc/patch-extractor/lib
    cp usr/lib/libapparmor.so* /home/tc/patch-extractor/lib
    cp usr/lib/libjson-c.so* /home/tc/patch-extractor/lib
    cp usr/lib/libsodium.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_context.so* /home/tc/patch-extractor/lib
    cp usr/lib/libsynocrypto.so* /home/tc/patch-extractor/lib
    cp usr/lib/libsynocredentials.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_iostreams.so* /home/tc/patch-extractor/lib
    cp usr/lib/libsynocore.so* /home/tc/patch-extractor/lib
    cp usr/lib/libicuio.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_chrono.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_date_time.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_system.so* /home/tc/patch-extractor/lib
    cp usr/lib/libsynocodesign.so.7* /home/tc/patch-extractor/lib
    cp usr/lib/libsynocredential.so* /home/tc/patch-extractor/lib
    cp usr/lib/libjson-glib-1.0.so* /home/tc/patch-extractor/lib
    cp usr/lib/libboost_serialization.so* /home/tc/patch-extractor/lib
    cp usr/lib/libmsgpackc.so* /home/tc/patch-extractor/lib

    cp -r usr/syno/sbin/synoarchive /home/tc/patch-extractor/

    sudo rm -rf usr
    sudo rm -rf ../oldpat.tar.gz
    sudo rm -rf hda1.tgz

    curl --silent --location https://github.com/pocopico/tinycore-redpill/blob/main/tools/xxd?raw=true --output xxd

    chmod +x xxd

    ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0100/' | ./xxd -r >synoarchive.nano
    ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0a00/' | ./xxd -r >synoarchive.smallpatch
    ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0000/' | ./xxd -r >synoarchive.system

    chmod +x synoarchive.*

    [ ! -d /mnt/${tcrppart}/auxfiles/patch-extractor ] && mkdir /mnt/${tcrppart}/auxfiles/patch-extractor

    cp -rf /home/tc/patch-extractor/lib /mnt/${tcrppart}/auxfiles/patch-extractor/
    cp -rf /home/tc/patch-extractor/synoarchive* /mnt/${tcrppart}/auxfiles/patch-extractor/

    sudo cp -rf /home/tc/patch-extractor/lib /lib
    sudo cp -rf /home/tc/patch-extractor/synoarchive.* /bin

}

function downloadupgradepat() {

    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"
    tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"

    if [ ! -d /mnt/${tcrppart}/auxfiles/patch-extractor ] || [ ! -f /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.nano ]; then
        downloadextractorv2
    else
        echo "Found locally cached extractor"
        [ ! -h /lib64 ] && sudo ln -s /lib /lib64
        sudo cp -f /mnt/${tcrppart}/auxfiles/patch-extractor/lib/* /lib/
        sudo cp -f /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive* /bin
    fi

    cd /home/tc

    PS3="Select Model : "

    select model in $(ls /home/tc/redpill-load/config | grep -v common); do

        echo "Selected model : ${model} "

        PS3="Select update version : "
        select version in $(curl --insecure --silent https://archive.synology.com/download/Os/DSM/ | grep "/download/Os/DSM/7" | awk '{print $2}' | awk -F\/ '{print $5}' | sed -s 's/"//g'); do
            echo "Selected version : $version"
            selectedmodel=$(echo $model | sed -e 's/DS//g' | sed -e 's/RS//g' | sed -e 's/DVA//g' | sed -e 's/+//g')
            PS3="Select pat file URL : "
            select patfile in $(curl --insecure --silent "https://archive.synology.com/download/Os/DSM/${version}" | grep href | grep -i $selectedmodel | awk '{print $2}' | sed -e 's/href=//g'); do

                patfile="$(echo $patfile | sed -e 's/"//g')"
                echo "Selected patfile :  $patfile "
                patfilever="$(echo $patfile | awk -F\/ '{print $8}')"
                updatepat="/home/tc/${model}_${patfilever}.pat"

                echo "Downloading PAT file "
                curl --insecure --progress-bar -L "$patfile" -o $updatepat

                [ -f $updatepat ] && echo "Downloaded Patfile $updatepat "

                extractdownloadpat "$version" && return

            done

        done

    done

}

function extractdownloadpat() {

    upgradepatdir="/home/tc/upgradepat"
    temppat="/home/tc/temppat"

    rm -rf $upgradepatdir
    rm -rf $temppat

    echo "Extracting pat file to find your files..."
    [ ! -d $temppat ] && mkdir $temppat
    cd $temppat

    echo "Upgrade patfile $updatepat will be extracted to $temppat"

    issystempat="$(echo $version | grep -i nano | wc -l)"

    if [ $issystempat -eq 1 ]; then
        echo "PAT file is a system nanopacked file "
        synoarchive.system -xf ${updatepat}
    else
        echo "PAT file is a smallupdate file "
        synoarchive.nano -xf ${updatepat}
        tarfile="$(ls flash*update* | head -1 2>/dev/null)"
        if [ ! -z $tarfile ]; then
            tar xf $tarfile
            tar xf content.txz
        else
            echo "update does not contain a flashupdate"
        fi

    fi

    [ ! -d $upgradepatdir ] && mkdir $upgradepatdir

    [ -f rd.gz ] && echo "Copying rd.gz to $upgradepatdir" && cp rd.gz $upgradepatdir
    [ -f zImage ] && echo "Copying zImage to $upgradepatdir" && cp zImage $upgradepatdir

    if [ -f $upgradepatdir/rd.gz ] && [ -f $upgradepatdir/zImage ]; then
        cd /home/tc
        echo "Cleaning up "
        rm -rf $temppat
        rm -rf $updatepat
        echo "The initrd you need is -> $(ls $upgradepatdir/rd.gz) "
    else
        echo "Something went wrong or the update file does not contain rd.gz or zImage"
    fi

}

function fullupgrade() {

    backupdate="$(date +%Y-%b-%d-%H-%M)"

    echo "Performing a full TCRP upgrade"
    echo "Warning some of your local files will be moved to /home/tc/old/xxxx.${backupdate}"

    mkdir -p /home/tc/old

    for updatefile in ${fullupdatefiles}; do

        echo "Updating ${updatefile}"

        [ -f ${updatefile} ] && sudo mv $updatefile old/${updatefile}.${backupdate}
        sudo curl --insecure --silent --location "${rploaderrepo}/${updatefile}" -O
        [ ! -f ${updatefile}] && mv old/${updatefile}.${backupdate} $updatefile

    done

    sudo chown tc:staff $fullupdatefiles
    gunzip -f modules.alias.*.gz
    sudo chmod 700 rploader.sh

    backup

}

function backuploader() {

    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"
    tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
    homesize=$(du -sh /home/tc | awk '{print $1}')
    backupdate="$(date +%Y-%b-%d-%H-%M)"

    if [ ! -n "$loaderdisk" ] || [ ! -n "$tcrppart" ]; then
        echo "No Loader disk or no TCRP partition found, return"
        return
    fi

    if [ $(df -h /mnt/${tcrppart} | grep mnt | awk '{print $4}' | cut -c 1-3) -le 50 ]; then
        echo "No adequate space on TCRP loader partition  /mnt/${tcrppart} "
        return
    fi

    echo "Backing up current loader"
    echo "Checking backup folder existence"
    [ ! -d /mnt/${tcrppart}/backup ] && mkdir /mnt/${tcrppart}/backup
    echo "The backup folder holds the following backups"
    ls -ltr /mnt/${tcrppart}/backup
    echo "Creating backup folder $backupdate"
    [ ! -d /mnt/${tcrppart}/backup/${backupdate} ] && mkdir /mnt/${tcrppart}/backup/${backupdate}
    echo "Mounting partition 1"
    mount /dev/${loaderdisk}1
    cd /mnt/${loaderdisk}1
    tar cfz /mnt/${tcrppart}/backup/${backupdate}/partition1.tgz *

    echo "Mounting partition 2"
    mount /dev/${loaderdisk}2
    cd /mnt/${loaderdisk}2
    tar cfz /mnt/${tcrppart}/backup/${backupdate}/partition2.tgz *

    cd
    echo "Listing backup files : "

    ls -ltr /mnt/${tcrppart}/backup/${backupdate}/

    echo "Partition 1 : $(tar tfz /mnt/${tcrppart}/backup/${backupdate}/partition1.tgz | wc -l) files and directories "
    echo "Partition 2 : $(tar tfz /mnt/${tcrppart}/backup/${backupdate}/partition2.tgz | wc -l) files and directories "

    echo "DONE"

}

function restoreloader() {

    loaderdisk="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)"
    tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
    homesize=$(du -sh /home/tc | awk '{print $1}')
    PS3="Select backup folder to restore : "
    options=""

    if [ ! -n "$loaderdisk" ] || [ ! -n "$tcrppart" ]; then
        echo "No Loader disk or no TCRP partition found, return"
        return
    fi

    echo "Restoring loader from backup"
    echo "The backup folder holds the following backups"

    for folder in $(ls /mnt/${tcrppart}/backup | sed -e 's/\///g'); do
        options=" $options ${folder}"
        echo -n $folder
        echo -n "Partition 1 : $(tar tfz /mnt/${tcrppart}/backup/${folder}/partition1.tgz | wc -l) files and directories "
        echo "Partition 2 : $(tar tfz /mnt/${tcrppart}/backup/${folder}/partition2.tgz | wc -l) files and directories "
    done

    select restorefolder in ${options[@]}; do
        if [ "$REPLY" == "quit" ]; then
            return
        fi
        if [ -f "/mnt/${tcrppart}/backup/$restorefolder/partition1.tgz" ]; then
            echo " Restore folder : $restorefolder"
            echo -n "You have chosen ${restorefolder} : "
            echo "Folder contains : "
            ls -ltr /mnt/${tcrppart}/backup/$restorefolder

            echo -n "Do you want to restore [yY/nN] : "
            read answer

            if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                echo restoring $restorefolder
                echo "Mounting partition 1"
                mount /dev/${loaderdisk}1
                echo "Restoring partition1 "
                cd /mnt/${loaderdisk}1
                tar xfz /mnt/${tcrppart}/backup/${restorefolder}/partition1.tgz *
                ls -ltr /mnt/${loaderdisk}1
                echo "Mounting partition 2"
                mount /dev/${loaderdisk}2
                echo "Restoring partition2 "
                cd /mnt/${loaderdisk}2
                tar xfz /mnt/${tcrppart}/backup/${restorefolder}/partition2.tgz *
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

function checkforscsi() {

    # Make sure we load SCSI modules if SCSI/RAID/SAS HBAs exist on the system
    #
    if [ $(lspci -nn | grep -ie "\[0100\]" -ie "\[0104\]" -ie "\[0107\]" | wc -l) -gt 0 ]; then
        echo "Found SCSI HBAs, We need to install the SCSI modules"
        tce-load -iw scsi-5.10.3-tinycore64.tcz
        [ $(losetup | grep -i "scsi-" | wc -l) -gt 0 ] && echo "Succesfully installed SCSI modules"
    fi

}

function mountdsmroot() {

    # DSM Disks will be linux_raid_member and will  have the
    # same DSM PARTUUID with the addition of the partition number e.g :
    #/dev/sdb1: UUID="629ae3df-7eef-54e3-05d9-49f7b0bbaec7" TYPE="linux_raid_member" PARTUUID="d5ff7cea-01"
    #/dev/sdb2: UUID="260b3a01-ff65-a527-05d9-49f7b0bbaec7" TYPE="linux_raid_member" PARTUUID="d5ff7cea-02"
    # So a command like the below will list the first partition of a DSM disk
    #blkid /dev/sd* |grep -i raid  | awk '{print $1 " " $4}' |grep UUID | grep "\-01" | awk -F ":" '{print $1}'

    checkforscsi

    dsmrootdisk="$(blkid /dev/sd* | grep -i raid | awk '{print $1 " " $4}' | grep UUID | grep sd[a-z]1 | head -1 | awk -F ":" '{print $1}')"
    # OLD DSM
    #dsmrootdisk="$(blkid /dev/sd* | grep -i raid | awk '{print $1 " " $4}' | grep UUID | grep "\-01" | awk -F ":" '{print $1}' | head -1)"

    [[ ! -d /mnt/dsmroot ]] && mkdir /mnt/dsmroot

    [ ! $(mount | grep -i dsmroot | wc -l) -gt 0 ] && sudo mount -t ext4 $dsmrootdisk /mnt/dsmroot

    if [ $(mount | grep -i dsmroot | wc -l) -gt 0 ]; then
        echo "Succesfully mounted under /mnt/dsmroot"
    else
        echo "Failed to mount"
        return
    fi

    echo "Checking if patch version exists"

    if [ -d /mnt/dsmroot/.syno/patch ]; then
        echo "Patch directory exists"
        sudo cp /mnt/dsmroot/.syno/patch/VERSION /tmp/VERSION
        sudo chmod 666 /tmp/VERSION
        . /tmp/VERSION
        echo "DSM Root holds a patch version $productversion-$base-$nano "
    else
        echo "No DSM patch directory exists"
        return
    fi

}

function mountdatadisk() {

    echo "Assembling MD ..."
    sudo mdadm -Asf

    for mdarray in "$(ls /dev/md* | awk -F "\/" '{print $3}')"; do
        echo "Mounting $mdarray"
        echo "Getting md devices for array $mdarray"

        # Keep for LVM root disks recovery in future release
        if [ "$(fstype /dev/${mdarray})" == "LVM2_member" ]; then
            echo "Found LVM array, downloading LVM"
            tce-load -iw lvm2
            sudo vgchange -a y
            for volume in $(sudo lvs | grep -i vol | awk '{print $2"-"$1}'); do

                if [ "$(fstype /dev/mapper/$volume)" == "btrfs" ]; then
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

function patchdtc() {

    checkmachine
    loaderdisk=$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)
    localdisks=$(lsblk | grep -i disk | grep -i sd | awk '{print $1}' | grep -v $loaderdisk)
    localnvme=$(lsblk | grep -i nvme | awk '{print $1}')
    usbpid=$(cat user_config.json | jq '.extra_cmdline .pid' | sed -e 's/"//g' | sed -e 's/0x//g')
    usbvid=$(cat user_config.json | jq '.extra_cmdline .vid' | sed -e 's/"//g' | sed -e 's/0x//g')
    loaderusb=$(lsusb | grep "${usbvid}:${usbpid}" | awk '{print $2 "-"  $4 }' | sed -e 's/://g' | sed -s 's/00//g')

    if [ "${TARGET_PLATFORM}" = "v1000" ]; then
        dtbfile="ds1621p"
    elif [ "${TARGET_PLATFORM}" = "geminilake" ]; then
        dtbfile="ds920p"
    elif [ "${TARGET_PLATFORM}" = "dva1622" ]; then
        dtbfile="dva1622"

    else
        echo "${TARGET_PLATFORM} does not require model.dtc patching "
        return
    fi

    if [ ! -d /lib64 ]; then
        [ ! -h /lib64 ] && sudo ln -s /lib /lib64
    fi

    echo "Downloading dtc binary"
    curl --location --progress-bar "$dtcbin" -O
    chmod 700 dtc

    if [ -f /home/tc/custom-module/${dtbfile}.dts ] && [ ! -f /home/tc/custom-module/${dtbfile}.dtb ]; then
        echo "Found locally cached dts file ${dtbfile}.dts and dtb file does not exist in cache, converting dts to dtb"
        ./dtc -q -I dts -O dtb /home/tc/custom-module/${dtbfile}.dts >/home/tc/custom-module/${dtbfile}.dtb
    fi

    if [ -f /home/tc/custom-module/${dtbfile}.dtb ]; then

        echo "Fould locally cached dtb file"
        read -p "Should i use that file ? [Yy/Nn]" answer
        if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
            echo "OK copying over the cached dtb file"

            dtbextfile="$(find /home/tc/redpill-load/custom -name model_${dtbfile}.dtb)"
            if [ ! -z ${dtbextfile} ] && [ -f ${dtbextfile} ]; then
                echo -n "Copying patched dtb file ${dtbfile}.dtb to ${dtbextfile} -> "
                sudo cp /home/tc/custom-module/${dtbfile}.dtb ${dtbextfile}
                if [ $(sha256sum /home/tc/custom-module/${dtbfile}.dtb | awk '{print $1}') = $(sha256sum ${dtbextfile} | awk '{print $1}') ]; then
                    echo -e "OK ! File copied and verified !"
                    return
                else
                    echo -e "ERROR !\nFile has not been copied succesfully, you will need to copy it yourself"
                    return
                fi
            else
                [ -z ${dtbextfile} ] && echo "dtb extension is not loaded and its required for DSM to find disks on ${SYNOMODEL}"
                echo "Copy of the DTB file ${dtbfile}.dtb to ${dtbextfile} was not succesfull."
                echo "Please remember to replace the dtb extension model file ..."
                echo "execute manually : cp ${dtbfile}.dtb ${dtbextfile} and re-run"
                exit 99
            fi
        else
            echo "OK lets continue patching"
        fi
    else
        echo "No cached dtb file found in /home/tc/custom-module/${dtbfile}.dtb"
    fi

    if [ ! -f ${dtbfile}.dts ]; then
        echo "dts file for ${dtbfile} not found, trying to download"
        curl --location --progress-bar -O "${dtsfiles}/${dtbfile}.dts"
    fi

    echo "Found $(echo $localdisks | wc -w) disks and $(echo $localnvme | wc -w) nvme"
    let diskslot=1
    echo "Collecting disk paths"

    for disk in $localdisks; do
        diskdepth=$(udevadm info --query path --name $disk | awk -F"/" '{print NF-1}')
        if [[ $diskdepth = 9 ]]; then
            diskpath=$(udevadm info --query path --name $disk | awk -F "/" '{print $4 ":" $5 }' | awk -F ":" '{print $2 ":" $3 }')
        elif [[ $diskdepth = 11 ]]; then
            diskpath=$(udevadm info --query path --name $disk | awk -F "/" '{print $4 ":" $5 ":" $6 }' | awk -F ":" '{print $2 ":" $3 "," $6 "," $9 }')
        else
            diskpath=$(udevadm info --query path --name $disk | awk -F "/" '{print $4 ":" $5 }' | awk -F ":" '{print $2 ":" $3 "," $6}')
        fi
        #diskpath=$(udevadm info --query path --name $disk | awk -F "\/" '{print $4 ":" $5 }' | awk -F ":" '{print $2 ":" $3 "," $6}' | sed 's/,*$//')
        if [ "$HYPERVISOR" == "VMware" ]; then
            diskport=$(udevadm info --query path --name $disk | sed -n '/target/{s/.*target//;p;}' | awk -F: '{print $1}')
            diskport=$(($diskport - 30)) && diskport=$(printf "%x" $diskport)
        else
            diskport=$(udevadm info --query path --name $disk | sed -n '/target/{s/.*target//;p;}' | awk -F: '{print $1}')
            diskport=$(printf "%x" $diskport)
        fi

        echo "Found local disk $disk with path $diskpath, adding into internal_slot $diskslot with portnumber $diskport"
        if [ "${dtbfile}" == "ds920p" ] || [ "${dtbfile}" == "dva1622" ]; then
            sed -i "/internal_slot\@${diskslot} {/!b;n;n;n;n;n;n;n;cpcie_root = \"$diskpath\";" ${dtbfile}.dts
            sed -i "/internal_slot\@${diskslot} {/!b;n;n;n;n;n;n;n;n;cata_port = <0x$diskport>;" ${dtbfile}.dts
            let diskslot=$diskslot+1
        else
            sed -i "/internal_slot\@${diskslot} {/!b;n;n;n;n;n;cpcie_root = \"$diskpath\";" ${dtbfile}.dts
            sed -i "/internal_slot\@${diskslot} {/!b;n;n;n;n;n;n;cata_port = <0x$diskport>;" ${dtbfile}.dts
            let diskslot=$diskslot+1
        fi

    done

    if [ $(echo $localnvme | wc -w) -gt 0 ]; then
        let nvmeslot=1
        echo "Collecting nvme paths"

        for nvme in $localnvme; do
            nvmepath=$(udevadm info --query path --name $nvme | awk -F "\/" '{print $4 ":" $5 }' | awk -F ":" '{print $2 ":" $3 "," $6}' | sed 's/,*$//')
            echo "Found local nvme $nvme with path $nvmepath, adding into m2_card $nvmeslot"
            if [ "${dtbfile}" == "ds920p" ]; then
                sed -i "/nvme_slot\@${nvmeslot} {/!b;n;cpcie_root = \"$nvmepath\";" ${dtbfile}.dts
                let diskslot=$diskslot+1
            else
                sed -i "/m2_card\@${nvmeslot} {/!b;n;n;n;cpcie_root = \"$nvmepath\";" ${dtbfile}.dts
                let nvmeslot=$diskslot+1
            fi
        done

    else
        echo "NO NVME disks found, returning"
    fi

    if
        [ ! -z $loaderusb ] && [ -n $loaderusb ]
    then
        echo "Patching USB to include your loader. Loader found in ${loaderusb} port"
        sed -i "/usb_slot\@1 {/!b;n;n;n;n;n;n;n;cusb_port = \"${loaderusb}\";" ${dtbfile}.dts
    else
        echo "Your loader is not in USB, i will not try to patch dtb for USB"
    fi

    echo "Converting dts file : ${dtbfile}.dts to dtb file : >${dtbfile}.dtb "
    ./dtc -q -I dts -O dtb ${dtbfile}.dts >${dtbfile}.dtb

    dtbextfile="$(find /home/tc/redpill-load/custom -name model_${dtbfile}.dtb)"
    if [ ! -z ${dtbextfile} ] && [ -f ${dtbextfile} ]; then
        echo -n "Copying patched dtb file ${dtbfile}.dtb to ${dtbextfile} -> "
        sudo cp ${dtbfile}.dtb ${dtbextfile}
        if [ $(sha256sum ${dtbfile}.dtb | awk '{print $1}') = $(sha256sum ${dtbextfile} | awk '{print $1}') ]; then
            echo -e "OK ! File copied and verified !"
        else
            echo -e "ERROR !\nFile has not been copied succesfully, you will need to copy it yourself"
        fi
    else
        [ -z ${dtbextfile} ] && echo "dtb extension is not loaded and its required for DSM to find disks on ${SYNOMODEL}"
        echo "Copy of the DTB file ${dtbfile}.dtb to ${dtbextfile} was not succesfull."
        echo "Please remember to replace the dtb extension model file ..."
        echo "execute manually : cp ${dtbfile}.dtb ${dtbextfile} and re-run"
        exit 99
    fi
}

function mountshare() {

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

    if [ -z "$mountpoint" ]; then
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

    if grep -q ^flags.*\ hypervisor\  /proc/cpuinfo; then
        MACHINE="VIRTUAL"
        HYPERVISOR=$(dmesg | grep -i "Hypervisor detected" | awk '{print $5}')
        echo "Machine is $MACHINE Hypervisor=$HYPERVISOR"
    fi

}

function backup() {

    loaderdisk=$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)
    homesize=$(du -sh /home/tc | awk '{print $1}')

    echo "Please make sure you are using the latest 1GB img before using backup option"
    echo "Current /home/tc size is $homesize , try to keep it less than 1GB as it might not fit into your image"

    echo "Should i update the $loaderdisk with your current files [Yy/Nn]"
    read answer
    if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
        echo -n "Backing up home files to $loaderdisk : "
        if filetool.sh -b ${loaderdisk}3; then
            echo ""
        else
            echo "Error: Couldn't backup files"
        fi
    else
        echo "OK, keeping last status"
    fi

}

function satamap() {

    # This function identifies all SATA controllers and create a plausible sataportmap and diskidxmap.
    #
    # In the case of SATABOOT: While TinyCore suppresses the /dev/sd device servicing synoboot, the
    # controller still takes up a sataportmap entry. ThorGroup advised not to map the controller ports
    # beyond the MaxDisks limit, but there is no harm in doing so - unless additional devices are
    # connected along with SATABOOT. This will create a gap/empty first slot.
    #
    # By mapping the SATABOOT controller ports beyond MaxDisks like Jun loader, it forces data disks
    # onto a secondary controller, and it's clear what the SATABOOT controller and device are being
    # used for. The KVM q35 bogus controller is mapped in the same manner.
    #
    # DUMMY ports (flagged by kernel as empty/non-functional, usually because hotplug is supported and
    # not enabled, and no disk is attached are detected and alerted. Any DUMMY port visible to the
    # DSM installer will result in a "SATA port disabled" message.
    #
    # SCSI/SAS and non-AHCI compliant SATA are unaffected by sataportmap and diskidxmap but a summary
    # controller and drive report is provided in order to avoid user distress.
    #
    # This code was written with the intention of reusing the detection strategy for device tree
    # creation, and the two functions could easily be integrated if desired.

    checkmachine
    checkforscsi

    let diskidxmapidx=0
    badportfail=false
    sataportmap=""
    diskidxmap=""

    maxdisks=$(jq -r ".synoinfo.maxdisks" user_config.json)

    # look for dummy SATA flagged by kernel (bad ports)
    dmys=$(dmesg | grep ": DUMMY$" | awk -F"] ata" '{print $2}' | awk -F: '{print $1}' | sort -n)

    # if we cannot find usb disk, the boot disk must be intended for SATABOOT
    if [ $(ls -la /sys/block/sd* | fgrep "/usb" | wc -l) -eq 0 ]; then
        loaderdisk=$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)
        sbpci=$(ls -la /sys/block/$loaderdisk | awk -F"/ata" '{print $1}' | awk -F"/" '{print $NF}' | cut --complement -f1 -d:)
    fi

    # get all SATA controllers PCI class 106
    # 100 = SCSI, 104 = RAIDHBA, 107 = SAS - none of these appear to honor sataportmap/diskidxmap
    pcis=$(lspci -d ::106 | awk '{print $1}')

    # loop through controllers in correct order
    for pci in $pcis; do
        # get attached block devices (exclude CD-ROMs)
        ports=$(ls -la /sys/class/ata_device | fgrep "$pci" | wc -l)
        drives=$(ls -la /sys/block | fgrep "$pci" | grep -v "sr.$" | wc -l)
        echo -e "\nFound \"$(lspci -s $pci | sed "s/\ .*://")\""
        echo -n "Detected $ports ports/$drives drives. "

        # look for bad ports on this controller
        badports=""
        for dmy in $dmys; do
            badpci=$(ls -la /sys/class/ata_port/ata$dmy | awk -F"/ata$dmy/ata_port/" '{print $1}' | awk -F"/" '{print $NF}' | cut --complement -f1 -d:)
            [ "$pci" = "$badpci" ] && badports=$(echo $badports$dmy" ")
        done
        # display the bad ports, referenced to controller port numbering
        if [ ! -z "$badports" ]; then
            # minmap is invalid with bad ports!
            [ "$1" = "minmap" ] && badportfail=true
            # get first port of PCI adapter with bad ports
            badportbase=$(ls -la /sys/class/ata_port | fgrep "$badpci" | awk -F"/ata_port/ata" '{print $2}' | sort -n | head -1)
            echo -n "Bad ports:"
            for badport in $badports; do
                let badport=$badport-$badportbase+1
                echo -n " "$badport
            done
            echo -n ". "
        fi
        # SATABOOT controller? (if so, it has to be mapped as first controller, we think)
        if [ "$pci" = "$sbpci" ]; then
            echo "Mapping SATABOOT drive after maxdisks"
            [ ${drives} -gt 1 ] && echo "WARNING: Other drives are connected that will not be accessible!"
            sataportmap=$sataportmap"1"
            diskidxmap=$diskidxmap$(printf "%02X" $maxdisks)
        else
            if [ "$pci" = "00:1f.2" ] && [ "$HYPERVISOR" = "KVM" ]; then
                # KVM q35 bogus controller?
                echo "Mapping KVM q35 bogus controller after maxdisks"
                sataportmap=$sataportmap"1"
                diskidxmap=$diskidxmap$(printf "%02X" $maxdisks)
            else
                # handle VMware virtual SATA controller insane port count
                if [ "$HYPERVISOR" = "VMware" ] && [ $ports -eq 30 ]; then
                    echo "Defaulting 8 virtual ports for typical system compatibility"
                    ports=8
                else
                    # if minmap and not vmware virtual sata, don't update sataportmap/diskidxmap
                    if [ "$1" = "minmap" ]; then
                        echo
                        continue
                    fi
                fi
                # ask interactively if not minmap
                if [ "$1" != "minmap" ]; then
                    echo -n "Override # of ports or ENTER to accept <$ports> "
                    read newports
                    if [ ! -z "$newports" ]; then
                        ports=$newports
                        if ! [ "$ports" -eq "$ports" ] 2>/dev/null; then
                            echo "Non-numeric, overridden to 0"
                            ports=0
                        fi
                    fi
                else
                    echo
                fi
                # if badports are in the port range, set the fail flag
                if [ ! -z "$badports" ]; then
                    for badport in $badports; do
                        let badport=$badport-$badportbase+1
                        [ $ports -ge $badport ] && badportfail=true
                    done
                fi
                if [ $ports -gt 9 ]; then
                    echo "WARNING: SataPortMap values >9 are experimental and may affect stability"
                    let ports=$ports+48
                    portchar=$(printf \\$(printf "%o" $ports))
                else
                    portchar=$ports
                fi
                sataportmap=$sataportmap$portchar
                diskidxmap=$diskidxmap$(printf "%02x" $diskidxmapidx)
                let diskidxmapidx=$diskidxmapidx+$ports
            fi
        fi
    done

    # ports > maxdisks?
    [ $diskidxmapidx -gt $maxdisks ] && echo "WARNING: mapped SATA port count exceeds maxdisks"

    # fix kernel panic if 1st position is set to 0 ports (from no SATA mappings or deliberate user selection)
    [ -z "$sataportmap" -o "${sataportmap:0:1}" = "0" ] && sataportmap=1${sataportmap:1}

    # handle no assigned SATA ports affecting SCSI mapping problem
    [ -z "$diskidxmap" ] && diskidxmap="00"

    # now advise on SCSI drives for user peace of mind
    # 100 = SCSI, 104 = RAIDHBA, 107 = SAS - none of these honor sataportmap/diskidxmap
    pcis=$(
        lspci -d ::100
        lspci -d ::104
        lspci -d ::107 | awk '{print $1}'
    )
    [ ! -z "$pcis" ] && echo
    # loop through non-SATA controllers
    for pci in $pcis; do
        # get attached block devices (exclude CD-ROMs)
        drives=$(ls -la /sys/block | fgrep "$pci" | grep -v "sr.$" | wc -l)
        echo "Found SCSI/HBA \""$(lspci -s $pci | sed "s/\ .*://")"\" ($drives drives)"
    done

    echo -e "\nComputed settings:"
    echo "SataPortMap=$sataportmap"
    echo "DiskIdxMap=$diskidxmap"
    [ "$badportfail" = true ] && echo -e "\nWARNING: Bad ports are mapped. The DSM installation will fail!"

    echo -en "\nShould i update the user_config.json with these values ? [Yy/Nn] "
    read answer
    if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
        json="$(jq --arg var "$sataportmap" '.extra_cmdline.SataPortMap = $var' user_config.json)" && echo -E "${json}" | jq . >user_config.json
        json="$(jq --arg var "$diskidxmap" '.extra_cmdline.DiskIdxMap = $var' user_config.json)" && echo -E "${json}" | jq . >user_config.json
        echo "Done."
    else
        echo "OK remember to update manually by editing user_config.json file"
    fi
}

function usbidentify() {

    checkmachine

    if [ "$MACHINE" = "VIRTUAL" ] && [ "$HYPERVISOR" = "VMware" ]; then
        echo "Running on VMware, no need to set USB VID and PID, you should SATA shim instead"
        exit 0
    fi

    if [ "$MACHINE" = "VIRTUAL" ] && [ "$HYPERVISOR" = "QEMU" ]; then
        echo "Running on QEMU, If you are using USB shim, VID 0x46f4 and PID 0x0001 should work for you"
        vendorid="0x46f4"
        productid="0x0001"
        echo "Vendor ID : $vendorid Product ID : $productid"

        echo "Should i update the user_config.json with these values ? [Yy/Nn]"
        read answer
        if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
            sed -i "/\"pid\": \"/c\    \"pid\": \"$productid\"," user_config.json
            sed -i "/\"vid\": \"/c\    \"vid\": \"$vendorid\"," user_config.json
        else
            echo "OK remember to update manually by editing user_config.json file"
        fi
        exit 0
    fi

    loaderdisk=$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)

    lsusb -v 2>&1 | grep -B 33 -A 1 SCSI >/tmp/lsusb.out

    usblist=$(grep -B 33 -A 1 SCSI /tmp/lsusb.out)
    vendorid=$(grep -B 33 -A 1 SCSI /tmp/lsusb.out | grep -i idVendor | awk '{print $2}')
    productid=$(grep -B 33 -A 1 SCSI /tmp/lsusb.out | grep -i idProduct | awk '{print $2}')

    if [ $(echo $vendorid | wc -w) -gt 1 ]; then
        echo "Found more than one USB disk devices, please select which one is your loader on"
        usbvendor=$(for item in $vendorid; do grep $item /tmp/lsusb.out | awk '{print $3}'; done)
        select usbdev in $usbvendor; do
            vendorid=$(grep -B 10 -A 10 $usbdev /tmp/lsusb.out | grep idVendor | grep $usbdev | awk '{print $2}')
            productid=$(grep -B 10 -A 10 $usbdev /tmp/lsusb.out | grep -A 1 idVendor | grep idProduct | awk '{print $2}')
            echo "Selected Device : $usbdev , with VendorID: $vendorid and ProductID: $productid"
            break
        done
    else
        usbdevice="$(grep iManufacturer /tmp/lsusb.out | awk '{print $3}') $(grep iProduct /tmp/lsusb.out | awk '{print $3}') SerialNumber: $(grep iSerial /tmp/lsusb.out | awk '{print $3}')"
    fi

    if [ -n "$usbdevice" ] && [ -n "$vendorid" ] && [ -n "$productid" ]; then
        echo "Found $usbdevice"
        echo "Vendor ID : $vendorid Product ID : $productid"

        echo "Should i update the user_config.json with these values ? [Yy/Nn]"
        read answer
        if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
            #  sed -i "/\"pid\": \"/c\    \"pid\": \"$productid\"," user_config.json
            json="$(jq --arg var "$productid" '.extra_cmdline.pid = $var' user_config.json)" && echo -E "${json}" | jq . >user_config.json
            #  sed -i "/\"vid\": \"/c\    \"vid\": \"$vendorid\"," user_config.json
            json="$(jq --arg var "$vendorid" '.extra_cmdline.vid = $var' user_config.json)" && echo -E "${json}" | jq . >user_config.json
        else
            echo "OK remember to update manually by editing user_config.json file"
        fi
    else
        echo "Sorry, no usb disk could be identified"
        rm /tmp/lsusb.out
    fi
}

function serialgen() {

    [ ! -z "$GATEWAY_INTERFACE" ] && shift 0 || shift 1

    [ "$2" == "realmac" ] && let keepmac=1 || let keepmac=0

    if [ "$1" = "DS3615xs" ] || [ "$1" = "DS3617xs" ] || [ "$1" = "DS916+" ] || [ "$1" = "DS918+" ] || [ "$1" = "DS920+" ] || [ "$1" = "DS3622xs+" ] || [ "$1" = "FS6400" ] || [ "$1" = "DVA3219" ] || [ "$1" = "DVA3221" ] || [ "$1" = "DS1621+" ] || [ "$1" = "DVA1622" ] || [ "$1" = "DS2422+" ] || [ "$1" = "RS4021xs+" ]; then
        serial="$(generateSerial $1)"
        mac="$(generateMacAddress $1)"
        realmac=$(ifconfig eth0 | head -1 | awk '{print $NF}')
        echo "Serial Number for Model = $serial"
        echo "Mac Address for Model $1 = $mac "
        [ $keepmac -eq 1 ] && echo "Real Mac Address : $realmac"
        [ $keepmac -eq 1 ] && echo "Notice : realmac option is requested, real mac will be used"

        if [ -z "$GATEWAY_INTERFACE" ]; then

            echo "Should i update the user_config.json with these values ? [Yy/Nn]"
            read answer
        else
            answer="y"
        fi

        if [ -n "$answer" ] && [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
            # sed -i "/\"sn\": \"/c\    \"sn\": \"$serial\"," user_config.json
            json="$(jq --arg var "$serial" '.extra_cmdline.sn = $var' user_config.json)" && echo -E "${json}" | jq . >user_config.json

            if [ $keepmac -eq 1 ]; then
                macaddress=$(echo $realmac | sed -s 's/://g')
            else
                macaddress=$(echo $mac | sed -s 's/://g')
            fi

            json="$(jq --arg var "$macaddress" '.extra_cmdline.mac1 = $var' user_config.json)" && echo -E "${json}" | jq . >user_config.json
            # sed -i "/\"mac1\": \"/c\    \"mac1\": \"$macaddress\"," user_config.json
        else
            echo "OK remember to update manually by editing user_config.json file"
        fi
    else
        echo "Error : $1 is not an available model for serial number generation. "
        echo "Available Models : DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xs+ FS6400 DVA3219 DVA3221 DS1621+ DVA1622 DS2422+ RS4021xs+"
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
    DVA1622)
        permanent="SJR"
        serialstart="2030 2040 20C0 2150"
        ;;
    DS2422+)
        permanent="S7R"
        serialstart="2080"
        ;;
    RS4021xs+)
        permanent="SQR"
        serialstart="2030 2040 20C0 2150"
        ;;
    esac

}

function random() {

    printf "%06d" $(($RANDOM % 30000 + 1))

}
function randomhex() {
    val=$(($RANDOM % 255 + 1))
    echo "obase=16; $val" | bc
}

function generateRandomLetter() {
    for i in a b c d e f g h j k l m n p q r s t v w x y z; do
        echo $i
    done | sort -R | tail -1
}

function generateRandomValue() {
    for i in 0 1 2 3 4 5 6 7 8 9 a b c d e f g h j k l m n p q r s t v w x y z; do
        echo $i
    done | sort -R | tail -1
}

function toupper() {
    echo $1 | tr '[:lower:]' '[:upper:]'
}

function generateMacAddress() {
    #toupper "Mac Address: 00:11:32:$(randomhex):$(randomhex):$(randomhex)"
    printf '00:11:32:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))

}

function generateSerial() {

    beginArray $1

    case $1 in

    DS3615xs)
        serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
        ;;
    DS3617xs)
        serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
        ;;
    DS916+)
        serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
        ;;
    DS918+)
        serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
        ;;
    FS6400)
        serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
        ;;
    DS920+)
        serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
        ;;
    DS3622xs+)
        serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
        ;;
    DS1621+)
        serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
        ;;
    DVA3219)
        serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
        ;;
    DVA3221)
        serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
        ;;
    DVA1622)
        serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
        ;;
    DS2422+)
        serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
        ;;
    RS4021xs+)
        serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
        ;;
    esac

    echo $serialnum

}

function prepareforcompile() {

    echo "Downloading required build software "
    tce-load -wi git compiletc coreutils bc perl5 openssl-1.1.1-dev

    if [ ! -d /lib64 ]; then
        [ ! -h /lib64 ] && sudo ln -s /lib /lib64
    fi
    if [ ! -f /lib64/libbz2.so.1 ]; then
        [ ! -h /lib64/libbz2.so.1 ] && sudo ln -s /usr/local/lib/libbz2.so.1.0.8 /lib64/libbz2.so.1
    fi

}

function gettoolchain() {

    if [ -d /usr/local/x86_64-pc-linux-gnu/ ]; then
        echo "Toolchain already cached"
        return
    fi

    cd /home/tc

    if [ -f dsm-toolchain.7.0.txz ]; then
        echo "File already cached"
    else
        echo "Downloading and caching toolchain"
        curl --progress-bar --location "${TOOLKIT_URL}" --output dsm-toolchain.7.0.txz
    fi

    echo -n "Checking file -> "
    checkfilechecksum dsm-toolchain.7.0.txz ${TOOLKIT_SHA}
    echo "OK, file matches sha256sum, extracting"
    cd / && sudo tar -xf /home/tc/dsm-toolchain.7.0.txz usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build
    if [ $? = 0 ]; then
        return
    else
        echo "Failed to extract toolchain"
    fi

}

function getPlatforms() {

    platform_versions=$(jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' custom_config_jun.json custom_config.json | jq -r '.build_configs[].id')
    echo "$platform_versions"

}

function selectPlatform() {

    platform_selected=$(jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' custom_config_jun.json custom_config.json | jq ".build_configs[] | select(.id==\"${1}\")")

}
function getValueByJsonPath() {

    local JSONPATH=${1}
    local CONFIG=${2}
    jq -c -r "${JSONPATH}" <<<${CONFIG}

}

function readConfig() {

    if [ ! -e custom_config.json ]; then
        cat global_config.json
    else
        jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' custom_config_jun.json custom_config.json
    fi

}

function getsynokernel() {

    if [ -d /home/tc/linux-kernel ]; then
        if [ -f /home/tc/linux-kernel/synoconfigs/${TARGET_PLATFORM} ]; then
            echo "Synokernel already cached"
            return
        else
            echo "Synokernel is cached but does not match the required sources"
            rm -rf /home/tc/linux-kernel
            rm -rf synokernel.txz
        fi
    fi

    cd /home/tc

    if [ -f synokernel.txz ]; then
        echo -n "File already cached, checking file -> "
        checkfilechecksum synokernel.txz ${SYNOKERNEL_SHA}
        echo "OK, file matches sha256sum, extracting"
        tar xf /home/tc/synokernel.txz
        mv $(tar --exclude="*/*/*" -tf synokernel.txz | head -1) linux-kernel
        rm -rf synokernel.txz
    else
        echo "Downloading and caching synokernel"
        cd /home/tc && curl --progress-bar --location ${SYNOKERNEL_URL} --output synokernel.txz
        checkfilechecksum synokernel.txz ${SYNOKERNEL_SHA}
        echo "OK, file matches sha256sum, extracting"
        echo "Extracting synokernel"
        tar xf /home/tc/synokernel.txz
        mv $(tar --exclude="*/*/*" -tf synokernel.txz | head -1) linux-kernel
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
    if [ "$COMPILE_METHOD" = "toolkit_dev" ]; then
        export LINUX_SRC=/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build

    else
        export LINUX_SRC=/home/tc/linux-kernel
    fi

    cd redpill-lkm && make ${REDPILL_LKM_MAKE_TARGET}
    strip --strip-debug /home/tc/redpill-lkm/redpill.ko
    modinfo /home/tc/redpill-lkm/redpill.ko
    REDPILL_MOD_NAME="redpill-linux-v$(modinfo redpill.ko | grep vermagic | awk '{print $2}').ko"
    cp /home/tc/redpill-lkm/redpill.ko /home/tc/redpill-load/ext/rp-lkm/${REDPILL_MOD_NAME}

}

function checkfilechecksum() {

    local FILE="${1}"
    local EXPECTED_SHA256="${2}"
    local SHA256_RESULT=$(sha256sum ${FILE})
    if [ "${SHA256_RESULT%% *}" != "${EXPECTED_SHA256}" ]; then
        echo "The ${FILE} is corrupted, expected sha256 checksum ${EXPECTED_SHA256}, got ${SHA256_RESULT%% *}"
        #rm -f "${FILE}"
        #echo "Deleted corrupted file ${FILE}. Please re-run your action!"
        echo "Please delete the file ${FILE} manualy and re-run your command!"
        exit 99
    fi

}

function tinyentry() {

    cat <<EOF
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

function tcrpfriendentry() {

    cat <<EOF
menuentry 'Tiny Core Friend' {
        savedefault
        set root=(hd0,msdos3)
        echo Loading Linux...
        linux /bzImage-friend loglevel=3 waitusb=5 vga=791 net.ifnames=0 biosdevname=0 
        echo Loading initramfs...
        initrd /initrd-friend
        echo Booting TinyCore Friend
}
EOF

}

function showsyntax() {
    cat <<EOF
$(basename ${0})

Version : $rploaderver
----------------------------------------------------------------------------------------

Usage: ${0} <action> <platform version> <static or compile module> [extension manager arguments]

Actions: build, ext, download, clean, update, fullupgrade, listmod, serialgen, identifyusb, patchdtc, 
satamap, backup, backuploader, restoreloader, restoresession, mountdsmroot, postupdate,
mountshare, version, monitor, getgrubconf, help

----------------------------------------------------------------------------------------
Available platform versions:
----------------------------------------------------------------------------------------
$(getPlatforms)
----------------------------------------------------------------------------------------
Check custom_config.json for platform settings.
EOF
}

function showhelp() {
    cat <<EOF
$(basename ${0})

Version : $rploaderver
----------------------------------------------------------------------------------------
Usage: ${0} <action> <platform version> <static or compile module> [extension manager arguments]

Actions: build, ext, download, clean, update, listmod, serialgen, identifyusb, patchdtc, 
satamap, backup, backuploader, restoreloader, restoresession, mountdsmroot, postupdate, 
mountshare, version, monitor, bringfriend, downloadupgradepat, help 

- build <platform> <option> : 
  Build the 💊 RedPill LKM and update the loader image for the specified platform version and update
  current loader.

  Valid Options:     static/compile/manual/junmod/withfriend

  ** withfriend add the TCRP friend and a boot option for auto patching 
  
- ext <platform> <option> <URL> 
  Manage extensions using redpill extension manager. 

  Valid Options:  add/force_add/info/remove/update/cleanup/auto . Options after platform 
  
  Example: 
  rploader.sh ext apollolake-7.0.1-42218 add https://raw.githubusercontent.com/pocopico/rp-ext/master/e1000/rpext-index.json
  or for auto detect use 
  rploader.sh ext apollolake-7.0.1-42218 auto 
  
- download <platform> :
  Download redpill sources only
  
- clean :
  Removes all cached and downloaded files and starts over clean
  
- update : 
  Checks github repo for latest version of rploader, and prompts you download and overwrite

- fullupgrade : 
  Performs a full upgrade of the local files to the latest available on the repo. It will
  backup the current filed under /home/tc/old
  
- listmods <platform>:
  Tries to figure out any required extensions. This usually are device modules
  
- serialgen <synomodel> <option> :
  Generates a serial number and mac address for the following platforms 
  DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xs+ FS6400 DVA3219 DVA3221 DS1621+ DVA1622 DS2422+ RS4021xs+
  
  Valid Options :  realmac , keeps the real mac of interface eth0
  
- identifyusb :    
  Tries to identify your loader usb stick VID:PID and updates the user_config.json file 
  
- patchdtc :       
  Tries to identify and patch your dtc model for your disk and nvme devices. If you want to have 
  your manually edited dts file used convert it to dtb and place it under /home/tc/custom-modules
  
- satamap :
  Tries to identify your SataPortMap and DiskIdxMap values and updates the user_config.json file 
  
- backup :
  Backup and make changes /home/tc changed permanent to your loader disk. Next time you boot,
  your /home will be restored to the current state.
  
- backuploader :
  Backup current loader partitions to your TCRP partition
  
- restoreloader :
  Restore current loader partitions from your TCRP partition
  
- restoresession :
  Restore last user session files. (extensions and user_config.json)
  
- mountdsmroot :
  Mount DSM root for manual intervention on DSM root partition
  
- postupdate :
  Runs a postupdate process to recreate your rd.gz, zImage and custom.gz for junior to match root
  
- mountshare :
  Mounts a remote CIFS working directory

- version <option>:
  Prints rploader version and if the history option is passed then the version history is listed.

  Valid Options : history, shows rploader release history.

- monitor :
  Prints system statistics related to TCRP loader 

- getgrubconf :
  Checks your user_config.json file variables against current grub.cfg variables and updates your
  user_config.json accordingly

- bringfriend
  Downloads TCRP friend and makes it the default boot option. TCRP Friend is here to assist with
  automated patching after an upgrade. No postupgrade actions will be required anymore, if TCRP
  friend is left as the default boot option.

- downloadupgradepat
  Downloads a specific upgade pat that can be used for various troubleshooting purposes

- removefriend
  Reverse bringfriend actions and remove TCRP from your loader 

- help:           Show this page

----------------------------------------------------------------------------------------
Version : $rploaderver
EOF

}

function checkinternet() {

    echo -n "Checking Internet Access -> "
    nslookup github.com 2>&1 >/dev/null
    if [ $? -eq 0 ]; then
        echo "OK"
    else
        echo "Error: No internet found, or github is not accessible"
        exit 99
    fi

}

function gitdownload() {

    cd /home/tc

    if [ -d redpill-lkm ]; then
        echo "Redpill sources already downloaded, pulling latest"
        cd redpill-lkm
        git pull
        cd /home/tc
    else
        git clone -b $LKM_BRANCH "$LKM_SOURCE_URL"
    fi

    if [ -d redpill-load ]; then
        echo "Loader sources already downloaded, pulling latest"
        cd redpill-load
        git pull
        cd /home/tc
    else
        git clone -b $LD_BRANCH "$LD_SOURCE_URL"
    fi

}

function getstaticmodule() {

    cd /home/tc

    if [ -d /home/tc/custom-module ] && [ -f /home/tc/custom-module/redpill.ko ]; then
        echo "Found custom redpill module, do you want to use this instead ? [yY/nN] : "
        read answer

        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
            REDPILL_MOD_NAME="redpill-linux-v$(modinfo /home/tc/custom-module/redpill.ko | grep vermagic | awk '{print $2}').ko"
            cp /home/tc/custom-module/redpill.ko /home/tc/redpill-load/ext/rp-lkm/${REDPILL_MOD_NAME}
            strip --strip-debug /home/tc/redpill-load/ext/rp-lkm/${REDPILL_MOD_NAME}
            return
        fi

    fi

    echo "Removing any old redpill.ko modules"
    [ -f /home/tc/redpill.ko ] && rm -f /home/tc/redpill.ko

    extension=$(curl -s --location "$redpillextension")

    if [ "${TARGET_PLATFORM}" = "apollolake" ]; then
        SYNOMODEL="ds918p_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "bromolow" ]; then
        SYNOMODEL="ds3615xs_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "broadwell" ]; then
        SYNOMODEL="ds3617xs_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "broadwellnk" ]; then
        SYNOMODEL="ds3622xsp_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "v1000" ]; then
        SYNOMODEL="ds1621p_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "denverton" ]; then
        SYNOMODEL="dva3221_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "geminilake" ]; then
        SYNOMODEL="ds920p_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "dva1622" ]; then
        SYNOMODEL="dva1622_$TARGET_REVISION"
    elif [ "${TARGET_PLATFORM}" = "ds2422p" ]; then
        SYNOMODEL="ds2422p_$TARGET_REVISION" && MODEL="DS2422+"
    elif [ "${TARGET_PLATFORM}" = "rs4021xsp" ]; then
        SYNOMODEL="rs4021xsp_$TARGET_REVISION" && MODEL="RS4021xs+"
    fi

    echo "Looking for redpill for : $SYNOMODEL "

    #release=`echo $extension |  jq -r '.releases .${SYNOMODEL}_{$TARGET_REVISION}'`
    release=$(echo $extension | jq -r -e --arg SYNOMODEL $SYNOMODEL '.releases[$SYNOMODEL]')
    files=$(curl -s --location "$release" | jq -r '.files[] .url')

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

    if [ -f redpill.ko ] && [ -n $(strings redpill.ko | grep $SYNOMODEL) ]; then
        REDPILL_MOD_NAME="redpill-linux-v$(modinfo redpill.ko | grep vermagic | awk '{print $2}').ko"
        mv /home/tc/redpill.ko /home/tc/redpill-load/ext/rp-lkm/${REDPILL_MOD_NAME}
    else
        echo "Module does not contain platorm information for ${SYNOMODEL}"
        exit 99
    fi

}

function buildloader() {

    tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
    local_cache="/mnt/${tcrppart}/auxfiles"

    [ "$1" == "junmod" ] && JUNLOADER="YES"

    [ -d $local_cache ] && echo "Found tinycore cache folder, linking to home/tc/custom-module" && [ ! -d /home/tc/custom-module ] && ln -s $local_cache /home/tc/custom-module

    cd /home/tc

    echo -n "Checking user_config.json : "
    if jq -s . user_config.json >/dev/null; then
        echo "Done"
    else
        echo "Error : Problem found in user_config.json"
        exit 99
    fi

    removebundledexts

    if [ ! -d /lib64 ]; then
        sudo ln -s /lib /lib64
    fi
    if [ ! -f /lib64/libbz2.so.1 ]; then
        sudo ln -s /usr/local/lib/libbz2.so.1.0.8 /lib64/libbz2.so.1
    fi

    if [ ! -f /home/tc/redpill-load/user_config.json ]; then
        ln -s /home/tc/user_config.json /home/tc/redpill-load/user_config.json
    fi

    cd /home/tc/redpill-load

    if [ -d cache ]; then
        echo "Cache directory OK "
    else
        mkdir cache
    fi

    if [ ${TARGET_REVISION} -gt 42218 ]; then

        echo "Found build request for revision greater than 42218"
        downloadextractor
        processpat

    else

        if [ -d /home/tc/custom-module ]; then
            #echo "Want to use firmware files from /home/tc/custom-module/*.pat ? [yY/nN] : "
            #read answer

            #if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
            sudo cp -adp /home/tc/custom-module/*${TARGET_REVISION}*.pat /home/tc/redpill-load/cache/
            #fi
        fi

    fi

    [ -d /home/tc/redpill-load ] && cd /home/tc/redpill-load

    addrequiredexts

    if [ "$JUNLOADER" == "YES" ]; then
        echo "jun build option has been specified, so JUN MOD loader will be created"
        sudo BRP_JUN_MOD=1 BRP_DEBUG=0 BRP_USER_CFG=user_config.json ./build-loader.sh $MODEL $TARGET_VERSION-$TARGET_REVISION loader.img
    else
        sudo ./build-loader.sh $MODEL $TARGET_VERSION-$TARGET_REVISION loader.img
    fi

    if [ $? -ne 0 ]; then
        echo "FAILED : Loader creation failed check the output for any errors"
        exit 99
    fi

    sudo losetup -fP ./loader.img
    loopdev=$(losetup -j loader.img | awk '{print $1}' | sed -e 's/://')

    if [ -d part1 ]; then
        sudo mount ${loopdev}p1 part1
    else
        mkdir part1
        sudo mount ${loopdev}p1 part1
    fi

    if [ -d part2 ]; then
        sudo mount ${loopdev}p2 part2
    else
        mkdir part2
        sudo mount ${loopdev}p2 part2
    fi

    loaderdisk=$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)

    # Unmount to make sure you are able to mount properly

    sudo umount /dev/${loaderdisk}1
    sudo umount /dev/${loaderdisk}2

    if [ -d localdiskp1 ]; then
        sudo mount /dev/${loaderdisk}1 localdiskp1
        echo "Mounting /dev/${loaderdisk}1 to localdiskp1 "
    else
        mkdir localdiskp1
        sudo mount /dev/${loaderdisk}1 localdiskp1
        echo "Mounting /dev/${loaderdisk}1 to localdiskp1 "
    fi

    if [ -d localdiskp2 ]; then
        sudo mount /dev/${loaderdisk}2 localdiskp2
        echo "Mounting /dev/${loaderdisk}2 to localdiskp2 "
    else
        mkdir localdiskp2
        sudo mount /dev/${loaderdisk}2 localdiskp2
        echo /dev/${loaderdisk}2 localdiskp2
    fi

    if [ $(mount | grep -i part1 | wc -l) -eq 1 ] && [ $(mount | grep -i part2 | wc -l) -eq 1 ] && [ $(mount | grep -i localdiskp1 | wc -l) -eq 1 ] && [ $(mount | grep -i localdiskp2 | wc -l) -eq 1 ]; then
        sudo cp -rf part1/* localdiskp1/
        sudo cp -rf part2/* localdiskp2/
        echo "Creating tinycore entry"
        tinyentry | sudo tee --append localdiskp1/boot/grub/grub.cfg

        if [ "$WITHFRIEND" = "YES" ]; then

            [ ! -f /home/tc/friend/initrd-friend ] && [ ! -f /home/tc/friend/bzImage-friend ] && bringoverfriend

            if [ -f /home/tc/friend/initrd-friend ] && [ -f /home/tc/friend/bzImage-friend ]; then

                cp /home/tc/friend/initrd-friend /mnt/${loaderdisk}3/
                cp /home/tc/friend/bzImage-friend /mnt/${loaderdisk}3/

                tcrpfriendentry | sudo tee --append /home/tc/redpill-load/localdiskp1/boot/grub/grub.cfg
            fi
        fi

    else
        echo "ERROR: Failed to mount correctly all required partitions"
    fi

    cd /home/tc/redpill-load

    echo "Entries in Localdisk bootloader : "
    echo "======================================================================="
    grep menuentry localdiskp1/boot/grub/grub.cfg

    ### Updating user_config.json

    updateuserconfigfield "general" "model" "$MODEL"
    updateuserconfigfield "general" "version" "${TARGET_VERSION}-${TARGET_REVISION}"
    updateuserconfigfield "general" "redpillmake" "${redpillmake}"
    zimghash=$(sha256sum /home/tc/redpill-load/localdiskp2/zImage | awk '{print $1}')
    updateuserconfigfield "general" "zimghash" "$zimghash"
    rdhash=$(sha256sum /home/tc/redpill-load/localdiskp2/rd.gz | awk '{print $1}')
    updateuserconfigfield "general" "rdhash" "$rdhash"

    USB_LINE="$(grep -A 5 "USB," /home/tc/redpill-load/localdiskp1/boot/grub/grub.cfg | grep linux | cut -c 16-999)"
    SATA_LINE="$(grep -A 5 "SATA," /home/tc/redpill-load/localdiskp1/boot/grub/grub.cfg | grep linux | cut -c 16-999)"

    echo "Updated user_config with USB Command Line : $USB_LINE"
    json=$(jq --arg var "${USB_LINE}" '.general.usb_line = $var' $userconfigfile) && echo -E "${json}" | jq . >$userconfigfile
    echo "Updated user_config with SATA Command Line : $SATA_LINE"
    json=$(jq --arg var "${SATA_LINE}" '.general.sata_line = $var' $userconfigfile) && echo -E "${json}" | jq . >$userconfigfile

    cp $userconfigfile /mnt/${loaderdisk}3/

    if [ "$WITHFRIEND" = "YES" ]; then

        cp localdiskp1/zImage /mnt/${loaderdisk}3/zImage-dsm

        # Compining rd.gz and custom.gz

        [ ! -d /home/tc/rd.temp ] && mkdir /home/tc/rd.temp
        [ -d /home/tc/rd.temp ] && cd /home/tc/rd.temp
        RD_COMPRESSED=$(cat /home/tc/redpill-load/config/$MODEL/${TARGET_VERSION}-${TARGET_REVISION}/config.json | jq -r -e ' .extra .compress_rd')

        if [ "$RD_COMPRESSED" = "false" ]; then
            echo "Ramdisk in not compressed "
            cat /home/tc/redpill-load/localdiskp1/rd.gz | sudo cpio -idm
            cat /home/tc/redpill-load/localdiskp1/custom.gz | sudo cpio -idm
            sudo chmod +x /home/tc/rd.temp/usr/sbin/modprobe
            (cd /home/tc/rd.temp && sudo find . | sudo cpio -o -H newc -R root:root >/mnt/${loaderdisk}3/initrd-dsm) >/dev/null
        else
            unlzma -dc /home/tc/redpill-load/localdiskp1/rd.gz | sudo cpio -idm
            cat /home/tc/redpill-load/localdiskp1/custom.gz | sudo cpio -idm
            sudo chmod +x /home/tc/rd.temp/usr/sbin/modprobe
            (cd /home/tc/rd.temp && sudo find . | sudo cpio -o -H newc -R root:root | xz -9 --format=lzma >/mnt/${loaderdisk}3/initrd-dsm) >/dev/null
        fi

        echo "Setting default boot entry to TCRP Friend"
        cd /home/tc/redpill-load/ && sudo sed -i "/set default=\"*\"/cset default=\"3\"" localdiskp1/boot/grub/grub.cfg

    else

        if [ "$MACHINE" = "VIRTUAL" ]; then
            echo "Setting default boot entry to SATA"
            cd /home/tc/redpill-load/ && sudo sed -i "/set default=\"*\"/cset default=\"1\"" localdiskp1/boot/grub/grub.cfg
        fi

    fi

    cd /home/tc/redpill-load/

    ####

    checkmachine

    sudo umount part1
    sudo umount part2
    sudo umount localdiskp1
    sudo umount localdiskp2
    sudo losetup -D

    echo "Cleaning up files"
    sudo rm -rf /home/tc/rd.temp /home/tc/friend /home/tc/redpill-load/loader.img

    echo "Caching files for future use"
    [ ! -d ${local_cache} ] && mkdir ${local_cache}

    if [ $(df -h /mnt/${tcrppart} | grep mnt | awk '{print $4}' | cut -c 1-3 | sed -e 's/M//g') -le 400 ]; then
        echo "No adequate space on TCRP loader partition /mnt/${tcrppart} to cache pat file"
        echo "Found $(ls /mnt/${tcrppart}/auxfiles/*pat) file"
        echo "Removing older cached pat files to cache current"
        rm -f /mnt/${tcrppart}/auxfiles/*.pat
        patfile=$(ls /home/tc/redpill-load/cache/*${TARGET_REVISION}*.pat | head -1)
        echo "Found ${patfile}, copying to cache directory : ${local_cache} "
        cp -f ${patfile} ${local_cache} && rm /home/tc/redpill-load/cache/*.pat
    else
        if [ -f "$(ls /home/tc/redpill-load/cache/*${TARGET_REVISION}*.pat | head -1)" ]; then
            patfile=$(ls /home/tc/redpill-load/cache/*${TARGET_REVISION}*.pat | head -1)
            echo "Found ${patfile}, copying to cache directory : ${local_cache} "
            cp -f ${patfile} ${local_cache}
        fi
    fi

}

function bringoverfriend() {

    echo "Bringing over my friend"
    [ ! -d /home/tc/friend ] && mkdir /home/tc/friend/ && cd /home/tc/friend

    #URLS=$(curl --insecure -s https://api.github.com/repos/pocopico/tcrpfriend/releases/latest | jq -r ".assets[] | select(.name | contains(\"${initrd-friend}\")) | .browser_download_url")
    URLS=$(curl --insecure -s https://api.github.com/repos/pocopico/tcrpfriend/releases/latest | jq -r ".assets[].browser_download_url")
    for file in $URLS; do curl --insecure --location --progress-bar "$file" -O; done

    if [ -f bzImage-friend ] && [ -f initrd-friend ] && [ -f chksum ]; then
        FRIENDVERSION="$(grep VERSION chksum | awk -F= '{print $2}')"
        BZIMAGESHA256="$(grep bzImage-friend chksum | awk '{print $1}')"
        INITRDSHA256="$(grep initrd-friend chksum | awk '{print $1}')"
        [ "$(sha256sum bzImage-friend | awk '{print $1}')" == "$BZIMAGESHA256" ] && echo "bzImage-friend checksum OK !" || echo "bzImage-friend checksum ERROR !" || exit 99
        [ "$(sha256sum initrd-friend | awk '{print $1}')" == "$INITRDSHA256" ] && echo "initrd-friend checksum OK !" || echo "initrd-friend checksum ERROR !" || exit 99
    else
        echo "Could not find friend files, exiting" && exit 0
    fi

}

function kernelprepare() {

    export ARCH=x86_64

    cd /home/tc/linux-kernel
    cp synoconfigs/${TARGET_PLATFORM} .config
    if [ ${TARGET_PLATFORM} = "apollolake" ]; then
        echo '+' >.scmversion
    fi

    if [ ${TARGET_PLATFORM} = "bromolow" ]; then

        cat <<EOF >patch-reloc
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

    echo -n "Checking if a newer version exists on the $build repo -> "

    curl -s --location "$rploaderfile" --output latestrploader.sh
    curl -s --location "$modalias3" --output modules.alias.3.json.gz
    [ -f modules.alias.3.json.gz ] && gunzip -f modules.alias.3.json.gz
    curl -s --location "$modalias4" --output modules.alias.4.json.gz
    [ -f modules.alias.4.json.gz ] && gunzip -f modules.alias.4.json.gz

    CURRENTSHA="$(sha256sum rploader.sh | awk '{print $1}')"
    REPOSHA="$(sha256sum latestrploader.sh | awk '{print $1}')"

    if [ -f latestrploader.sh ] && [ "${CURRENTSHA}" != "${REPOSHA}" ]; then
        echo "Found newversion : $(bash ./latestrploader.sh version now)"
        echo "Current version : $(bash ./rploader.sh version now)"
        echo -n "There is a newer version of the script on the repo should we use that ? [yY/nN]"
        read confirmation
        if [ "$confirmation" = "y" ] || [ "$confirmation" = "Y" ]; then
            echo "OK, updating, please re-run after updating"
            cp -f /home/tc/latestrploader.sh /home/tc/rploader.sh
            rm -f /home/tc/latestrploader.sh
            loaderdisk=$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)
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

    CONFIG=$(readConfig)
    selectPlatform $1

    GETTIME=$(curl -v --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
    INTERNETDATE=$(date +"%d%m%Y" -d "$GETTIME")
    LOCALDATE=$(date +"%d%m%Y")

    LD_SOURCE_URL="$(echo $platform_selected | jq -r -e '.redpill_load .source_url')"
    LD_BRANCH="$(echo $platform_selected | jq -r -e '.redpill_load .branch')"
    LKM_SOURCE_URL="$(echo $platform_selected | jq -r -e '.redpill_lkm .source_url')"
    LKM_BRANCH="$(echo $platform_selected | jq -r -e '.redpill_lkm .branch')"
    #EXTENSIONS="$(echo $platform_selected | jq -r -e '.add_extensions[]')"
    EXTENSIONS="$(echo $platform_selected | jq -r -e '.add_extensions[]' | grep json | awk -F: '{print $1}' | sed -s 's/"//g')"
    #EXTENSIONS_SOURCE_URL="$(echo $platform_selected | jq '.add_extensions[] .url')"
    EXTENSIONS_SOURCE_URL="$(echo $platform_selected | jq '.add_extensions[]' | grep json | awk '{print $2}')"
    TOOLKIT_URL="$(echo $platform_selected | jq -r -e '.downloads .toolkit_dev .url')"
    TOOLKIT_SHA="$(echo $platform_selected | jq -r -e '.downloads .toolkit_dev .sha256')"
    SYNOKERNEL_URL="$(echo $platform_selected | jq -r -e '.downloads .kernel .url')"
    SYNOKERNEL_SHA="$(echo $platform_selected | jq -r -e '.downloads .kernel .sha256')"
    COMPILE_METHOD="$(echo $platform_selected | jq -r -e '.compile_with')"
    TARGET_PLATFORM="$(echo $platform_selected | jq -r -e '.platform_version | split("-")' | jq -r -e .[0])"
    TARGET_VERSION="$(echo $platform_selected | jq -r -e '.platform_version | split("-")' | jq -r -e .[1])"
    TARGET_REVISION="$(echo $platform_selected | jq -r -e '.platform_version | split("-")' | jq -r -e .[2])"
    REDPILL_LKM_MAKE_TARGET="$(echo $platform_selected | jq -r -e '.redpill_lkm_make_target')"
    tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
    local_cache="/mnt/${tcrppart}/auxfiles"

    [ ! -h /lib64 ] && sudo ln -s /lib /lib64

    sudo chown -R tc:staff /home/tc

    if [ ! -n "$(which bspatch)" ]; then

        echo "bspatch does not exist, bringing over from repo"

        curl --location "https://raw.githubusercontent.com/pocopico/tinycore-redpill/$build/tools/bspatch" -O

        chmod 777 bspatch
        sudo mv bspatch /usr/local/bin/

    fi

    [ ! -d ${local_cache} ] && sudo mkdir -p ${local_cache}
    [ -h /home/tc/custom-module ] && unlink /home/tc/custom-module
    [ ! -h /home/tc/custom-module ] && sudo ln -s $local_cache /home/tc/custom-module

    if [ -z "$TARGET_PLATFORM" ] || [ -z "$TARGET_VERSION" ] || [ -z "$TARGET_REVISION" ]; then
        echo "Error : Platform not found "
        showhelp
        exit 99
    fi

    case $TARGET_PLATFORM in

    bromolow)
        KERNEL_MAJOR="3"
        MODULE_ALIAS_FILE="modules.alias.3.json"
        ;;
    apollolake | broadwell | broadwellnk | v1000 | denverton | geminilake | dva1622 | ds2422p | rs4021xsp)
        KERNEL_MAJOR="4"
        MODULE_ALIAS_FILE="modules.alias.4.json"
        ;;
    esac

    if [ "${TARGET_PLATFORM}" = "apollolake" ]; then
        SYNOMODEL="ds918p_$TARGET_REVISION" && MODEL="DS918+"
    elif [ "${TARGET_PLATFORM}" = "bromolow" ]; then
        SYNOMODEL="ds3615xs_$TARGET_REVISION" && MODEL="DS3615xs"
    elif [ "${TARGET_PLATFORM}" = "broadwell" ]; then
        SYNOMODEL="ds3617xs_$TARGET_REVISION" && MODEL="DS3617xs"
    elif [ "${TARGET_PLATFORM}" = "broadwellnk" ]; then
        SYNOMODEL="ds3622xsp_$TARGET_REVISION" && MODEL="DS3622xs+"
    elif [ "${TARGET_PLATFORM}" = "v1000" ]; then
        SYNOMODEL="ds1621p_$TARGET_REVISION" && MODEL="DS1621+"
    elif [ "${TARGET_PLATFORM}" = "denverton" ]; then
        SYNOMODEL="dva3221_$TARGET_REVISION" && MODEL="DVA3221"
    elif [ "${TARGET_PLATFORM}" = "geminilake" ]; then
        SYNOMODEL="ds920p_$TARGET_REVISION" && MODEL="DS920+"
    elif [ "${TARGET_PLATFORM}" = "dva1622" ]; then
        SYNOMODEL="dva1622_$TARGET_REVISION" && MODEL="DVA1622"
    elif [ "${TARGET_PLATFORM}" = "ds2422p" ]; then
        SYNOMODEL="ds2422p_$TARGET_REVISION" && MODEL="DS2422+"
    elif [ "${TARGET_PLATFORM}" = "rs4021xsp" ]; then
        SYNOMODEL="rs4021xsp_$TARGET_REVISION" && MODEL="RS4021xs+"
    fi

    #echo "Platform : $platform_selected"
    echo "Rploader Version : ${rploaderver}"
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
    echo "MODULE_ALIAS_FILE :  $MODULE_ALIAS_FILE"
    echo "SYNOMODEL : $SYNOMODEL "
    echo "MODEL : $MODEL "
    echo "Local Cache Folder : $local_cache"
    echo "DATE Internet : $INTERNETDATE Local : $LOCALDATE"

    if [ "$INTERNETDATE" != "$LOCALDATE" ]; then
        echo "ERROR ! System DATE is not correct"
        echo "Downloading ntpclient to assist"
        tce-load -iw ntpclient 2>&1 >/dev/null
        export TZ="${timezone}"
        sudo ntpclient -s -h ${ntpserver} 2>&1 >/dev/null
        echo "Current time after communicating with NTP server ${ntpserver} :  $(date) "
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

function getmodulealiasjson() {

    echo "{"
    echo "\"modules\" : ["

    for module in $(ls *.ko); do
        if [ $(modinfo ./$module --field alias | grep -ie pci -ie usb | wc -l) -ge 1 ]; then
            for alias in $(modinfo ./$module --field alias | grep -ie pci -ie usb); do
                echo "{"
                echo "\"name\" :  \"${module}\"",
                echo "\"alias\" :  \"${alias}\""
                echo "}",
            done
        fi
        #       echo "},"
    done | sed '$ s/,//'

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

    grep -ie pci -ie usb /lib/modules/$(uname -r)/modules.alias | while read line; do

        read alias pciid module <<<"$line"
        echo "{"
        echo "\"name\" :  \"${module}\"",
        echo "\"alias\" :  \"${pciid}\""
        echo "}",
        #       echo "},"

    done | sed '$ s/,//'

    echo "]"
    echo "}"

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

function listextension() {

    if [ ! -f rpext-index.json ]; then
        curl --progress-bar --location "${modextention}" --output rpext-index.json
    fi

    ## Get extension author rpext-index.json and then parse for extension download with :
    #       jq '. | select(.id | contains("vxge")) .url  ' rpext-index.json

    if [ ! -z $1 ]; then
        echo "Searching for matching extension for $1"
        matchingextension=($(jq ". | select(.id | endswith(\"${1}\")) .url  " rpext-index.json))

        if [ ! -z $matchingextension ]; then
            echo "Found matching extension : "
            echo $matchingextension
            ./redpill-load/ext-manager.sh add "${matchingextension//\"/}"
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

if [ $# -lt 2 ]; then
    syntaxcheck $@
fi

if [ -z "$GATEWAY_INTERFACE" ]; then

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

        [ "$3" = "withfriend" ] && echo "withfriend option set, My friend will be added" && WITHFRIEND="YES"

        case $3 in

        compile)
            prepareforcompile
            if [ "$COMPILE_METHOD" = "toolkit_dev" ]; then
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
        manual)

            echo "Using static compiled redpill extension"
            getstaticmodule
            echo "Got $REDPILL_MOD_NAME "
            echo "Manual extension handling,skipping extension auto detection "
            echo "Starting loader creation "
            buildloader
            [ $? -eq 0 ] && savesession
            ;;

        jun)
            echo "Using static compiled redpill extension"
            getstaticmodule
            echo "Got $REDPILL_MOD_NAME "
            listmodules
            echo "Starting loader creation "
            buildloader junmod
            [ $? -eq 0 ] && savesession
            ;;

        static | *)
            echo "No extra build option or static specified, using default <static> "
            echo "Using static compiled redpill extension"
            getstaticmodule
            echo "Got $REDPILL_MOD_NAME "
            listmodules
            echo "Starting loader creation "
            buildloader
            [ $? -eq 0 ] && savesession
            ;;

        esac

        ;;

    \
        ext)
        getvars $2
        checkinternet
        gitdownload

        if [ "$3" = "auto" ]; then
            listmodules
        else
            ext_manager $@ # instead of listmodules
        fi
        ;;

    restoresession)
        getvars $2
        checkinternet
        gitdownload
        restoresession
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
        serialgen $@
        ;;

    interactive)
        if [ -f interactive.sh ]; then
            . ./interactive.sh
        else
            curl --location --progress-bar "https://github.com/pocopico/tinycore-redpill/raw/$build/interactive.sh" --output interactive.sh
            . ./interactive.sh
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
        satamap $2
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
        [ $? -eq 0 ] && savesession
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
    installapache)
        installapache
        ;;
    version)
        version $@
        ;;
    help)
        showhelp
        exit 99
        ;;
    monitor)
        monitor
        exit 0
        ;;
    getgrubconf)
        getgrubconf
        exit 0
        ;;
    bringfriend)
        bringfriend
        exit 0
        ;;
    removefriend)
        removefriend
        exit 0
        ;;
    downloadupgradepat)
        downloadupgradepat
        exit 0
        ;;
    *)
        showsyntax
        exit 99
        ;;

    esac

else

    htmlstart

fi
