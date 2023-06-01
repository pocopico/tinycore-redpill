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
	   "docker_base_image": "debian:8-slim",
      "compile_with": "toolkit_dev",
      "redpill_lkm_make_target": "dev-v7",
      "downloads": {
        "kernel": {
          "url": "https://sourceforge.net/projects/dsgpl/files/Synology%20NAS%20GPL%20Source/25426branch/bromolow-source/linux-3.10.x.txz/download",
          "sha256": "18aecead760526d652a731121d5b8eae5d6e45087efede0da057413af0b489ed"
        },
        "toolkit_dev": {
          "url": "https://sourceforge.net/projects/dsgpl/files/toolkit/DSM7.0/ds.bromolow-7.0.dev.txz/download",
          "sha256": "a5fbc3019ae8787988c2e64191549bfc665a5a9a4cdddb5ee44c10a48ff96cdd"
        }
      },
      "redpill_lkm": {
        "source_url": "https://github.com/pocopico/redpill-lkm.git",
        "branch": "master"
      },
      "redpill_load": {
        "source_url": "https://github.com/pocopico/redpill-load.git",
        "branch": "develop"
      },
      "add_extensions": [
        {
          "all-modules": "https://github.com/pocopico/tcrp-addons/raw/main/all-modules/rpext-index.json",
          "eudev": "https://github.com/pocopico/tcrp-addons/raw/main/eudev/rpext-index.json",
          "disks": "https://github.com/pocopico/tcrp-addons/raw/main/disks/rpext-index.json",
          "misc": "https://github.com/pocopico/tcrp-addons/raw/main/misc/rpext-index.json",
	  "boot-wait": "https://github.com/pocopico/tcrp-addons/raw/main/boot-wait/rpext-index.json"
        }
      ]
    },

EOF
}

function footer() {
	cat <<EOF
 {
      "id": "endofids",
      "platform_version": "endofplatforms",
      "user_config_json": "endofuserconfig",
      "add_extensions": [
        {
          "extensions": "endofextensions"
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
	ds1621xsp | ds3622xs | rs4021xsp)
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
