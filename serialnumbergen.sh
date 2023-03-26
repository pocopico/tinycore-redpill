#!/bin/bash

function beginArray() {

	case $1 in

	\
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
	DS3622xsp)
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
	FS3017)
		permanent="08N"
		serialstart="1650"
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
	RS4021xs+)
		permanent="T2R"
		serialstart="2250"
		;;
	DS1522+)
		permanent="TRR"
		serialstart="2270"
		;;
	DS923+)
		permanent="TQR"
		serialstart="2270"
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
	if [ "$1" = "DS923+" ] || [ "$1" = "DS1522+" ] || [ "$1" = "RS4021xs+" ]; then
		# DS1522+ and DS923+ Mac starts with 90:09:d0
		printf '90:09:d0:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
	else
		printf '00:11:32:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
	fi

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
	FS3017)
		serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
		;;
	DS920+)
		serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
		;;
	DS3622xsp)
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
	RS4021xs+)
		serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
		;;
	DS923+)
		serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
		;;
	DS1522+)
		serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
		;;
	esac

	echo $serialnum

}

function showhelp() {

	cat <<EOF
$(basename ${0})

----------------------------------------------------------------------------------------
Usage: ${0} <platform>

Available platforms :
----------------------------------------------------------------------------------------
DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xsp FS6400 FS3017 DVA3219 DVA3221 DS1621+ DVA1622 RS4021xs+ DS923+ DS1522+

e.g. $(basename ${0}) DS3615xs
----------------------------------------------------------------------------------------
EOF

}

if [ -z "$1" ]; then
	showhelp
else
	if [ "$1" = "DS3615xs" ] || [ "$1" = "DS3617xs" ] || [ "$1" = "DS916+" ] || [ "$1" = "DS918+" ] || [ "$1" = "DS920+" ] || [ "$1" = "DS3622xsp" ] || [ "$1" = "FS6400" ] || [ "$1" = "FS3017" ] || [ "$1" = "DVA3219" ] || [ "$1" = "DVA3221" ] || [ "$1" = "DS1621+" ] || [ "$1" = "DVA1622" ] || [ "$1" = "RS4021xs+" ] || [ "$1" = "DS923+" ] || [ "$1" = "DS1522+" ]; then
		echo "Generating a random mac address : " $(generateMacAddress $1)
		echo "Generating a Serial Number for Model $1: " $(generateSerial $1)
	else
		echo "Error : $1 is not an available model for serial number generation. "
		echo "Available Models : DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xsp DVA3219 DVA3221 DS1621+ DVA1622 FS3017 FS6400"
	fi
fi
