#!/bin/bash

HOMEPATH="/home/tc"

. ${HOMEPATH}/include/config.sh

function generate() {
    echo "Generating default grub.cfg for model $1"
    cat ${HOMEPATH}/include/grub-template.conf >grub.cfg
}

function modifydefault() {
    shift 1
    echo "Modify default boot entry on grub.cfg for model $2"

    if [ -f grub.cfg ]; then

        case $1 in

        usb)
            sed -i "/set default=\"*\"/cset default=\"0\"" grub.cfg
            ;;
        sata)
            sed -i "/set default=\"*\"/cset default=\"1\"" grub.cfg
            ;;
        tcrp)
            sed -i "/set default=\"*\"/cset default=\"2\"" grub.cfg
            ;;
        tcrpfriend)
            sed -i "/set default=\"*\"/cset default=\"3\"" grub.cfg
            ;;
        *)
            sed -i "/set default=\"*\"/cset default=\"3\"" grub.cfg
            ;;
        esac

    else
        echo "Error generate grub first"

    fi

}

function addentry() {

    if [ -f grub.cfg ]; then
        shift 1
        model=$(cat $USERCONFIGFILE | jq -r -e ' .general .model')
        version=$(cat $USERCONFIGFILE | jq -r -e ' .general .version')
        usb_line=$(cat $USERCONFIGFILE | jq -r -e ' .general .usb_line')
        sata_line=$(cat $USERCONFIGFILE | jq -r -e ' .general .sata_line')
        $1
    else
        echo "No grub.cfg found generate first"
    fi

}

function modifyentry() {
    echo "Modifying boot entry on grub.cfg for model $1"
}

function usb() {
    if [ $(grep menuentry grub.cfg | grep -i usb | wc -l) -eq 0 ]; then
        cat >>grub.cfg <<EOF
menuentry 'RedPill $model $version (USB, Verbose)' {
	savedefault
	search --set=root --fs-uuid 6234-C863 --hint hd0,msdos3
	echo Loading Linux...
    linux /zImage-dsm $usb_line
	echo Loading initramfs...
	initrd /initrd-dsm
	echo Starting kernel with USB boot
}
EOF
    fi
}

function sata() {
    if [ $(grep menuentry grub.cfg | grep -i sata | wc -l) -eq 0 ]; then
        cat >>grub.cfg <<EOF
menuentry 'RedPill $model $version (SATA, Verbose)' {
	savedefault
	search --set=root --fs-uuid 6234-C863 --hint hd0,msdos3
	echo Loading Linux...
	linux /zImage-dsm $sata_line
	echo Loading initramfs...
	initrd /initrd-dsm
	echo Starting kernel with SATA boot
}
EOF
    fi
}

function tcrp() {
    if [ $(grep menuentry grub.cfg | grep -i "Tiny Core Image Build" | wc -l) -eq 0 ]; then
        cat >>grub.cfg <<EOF
menuentry 'Tiny Core Image Build' {
        savedefault
        search --set=root --fs-uuid 6234-C863 --hint hd0,msdos3
        echo Loading Linux...
        linux /vmlinuz64 loglevel=3 cde waitusb=5 vga=791
        echo Loading initramfs...
        initrd /corepure64.gz
        echo Booting TinyCore for loader creation
}
EOF
    fi
}

function tcrpfriend() {
    if [ $(grep menuentry grub.cfg | grep -i "Tiny Core Friend" | wc -l) -eq 0 ]; then
        cat >>grub.cfg <<EOF
menuentry 'Tiny Core Friend' {
        savedefault
        search --set=root --fs-uuid 6234-C863 --hint hd0,msdos3
        echo Loading Linux...
        linux /bzImage-friend loglevel=3 waitusb=5 vga=791 net.ifnames=0 biosdevname=0 
        echo Loading initramfs...
        initrd /initrd-friend
        echo Booting TinyCore Friend
}
EOF
    fi
}

function syntaxcheck() {

    if [ "$1" == "generate" ] || [ "$1" == "modifydefault" ] || [ "$1" == "addentry" ] || [ "$1" == "modifyentry" ]; then

        echo "Error : $0 Insufficient number of arguments : $#, command $1, option $2"

        case $1 in
        generate)
            echo "example : $0 generate  ds3622xsp_42962"
            ;;
        modifydefault)
            echo "example : $0 modifydefault parameter"
            ;;
        addentry)
            echo "example : $0, usb/sata/trcp/tcrpfriend/ ds3622xsp_42962"
            ;;
        modifyentry)
            echo "example : $0 "
            ;;
        esac
    else
        echo "Error $0, $1 is an invalid command. Valid commands are : generate, modifydefault, addentry, modifyentry"

    fi

    exit 1

}

case $1 in

generate)
    [ $# -lt 2 ] && syntaxcheck $@
    generate $@
    ;;

modifydefault)
    [ $# -lt 2 ] && syntaxcheck $@
    modifydefault $@
    ;;

addentry)
    [ $# -lt 2 ] && syntaxcheck $@
    addentry $@
    ;;

modifyentry)
    [ $# -lt 2 ] && syntaxcheck $@
    modifyentry $@
    ;;
*)
    syntaxcheck $@
    ;;
esac
