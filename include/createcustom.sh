#!/bin/bash

function header() {
	cat <<EOF
{
  "docker": {},
  "build_configs": [

EOF

}

function build_config() {

	model="$1"
	version="$2"
	platforms $model
	cat <<EOF
    {
      "id": "${model}-${version}",
      "platform_version": "${model}-${version}",
      "user_config_json": "${platform}_user_config.json",
      "add_extensions": [
        {
          "all-modules": "https://github.com/pocopico/tcrp-addons/raw/main/all-modules/rpext-index.json",
          "eudev": "https://github.com/pocopico/tcrp-addons/raw/main/eudev/rpext-index.json",
          "disks": "https://github.com/pocopico/tcrp-addons/raw/main/disks/rpext-index.json",
          "misc": "https://github.com/pocopico/tcrp-addons/raw/main/misc/rpext-index.json"
        }
      ]
    },

EOF
}

function footer() {
	cat <<EOF
 {
      "id": "",
      "platform_version": "",
      "user_config_json": "",
      "add_extensions": [
        {
          "extensions": ""
        }
      ]
    }
  ]
}
EOF
}

function platforms() {

	case $1 in

	ds1019p | ds918)
		platform="apollolake"
		;;
	ds1520p | ds920p | dva1622)
		platform="geminilake"
		;;
	ds1621p | ds2422p | fs2500)
		platform="v1000"
		;;
	ds1621xs | ds3622xs | rs4021xsp)
		platform="broadwellnk"
		;;
	ds3615xs | rs3413xsp)
		platform="bromolow"
		;;
	ds3617xs | rs3618xs)
		platform="broadwell"
		;;
	ds723p | ds923p)
		platform="r1000"
		;;
	dva3219 | dva3221)
		platform="denverton"
		;;
	fs6400)
		platform="purley"
		;;
	sa6400)
		platform="epyc7002"
		;;
	esac
}

header

for model in $(cat supportedmodels); do
	for version in $(cat versions); do
		build_config $model $version
	done
done

footer
