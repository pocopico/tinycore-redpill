#!/usr/bin/env bash
set -u

##### BASIC RUNTIME VALIDATION #########################################################################################
# shellcheck disable=SC2128
if [ -z "${BASH_SOURCE}" ] ; then
    echo "You need to execute this script using bash v4+ without using pipes"
    exit 1
fi

cd "${BASH_SOURCE%/*}/" || exit 1

########################################################################################################################

##### CONFIGURATION YOU CAN OVERRIDE USING ENVIRONMENT #################################################################
BRP_DEBUG=${BRP_DEBUG:-0} # whether you want to see debug messages
BRP_BUILD_DIR=${BRP_BUILD_DIR:-''} # makes sure attempts are unique; do not override this unless you're using repack
# you can also set RPT_EXTS_DIR as it's used by ext-manager
RPT_BUNDLED_EXTS_CFG=${RPT_BUNDLED_EXTS_CFG:-"$PWD/bundled-exts.json"} # file with list of bundled extensions
# The options below are meant for debugging only. Setting them will create an image which is not normally usable
BRP_DEV_DISABLE_EXTS=${BRP_DEV_DISABLE_EXTS:-0} # when set 1 all extensions will be disabled (and not included in image)
BRP_DEV_DISABLE_RP=${BRP_DEV_DISABLE_RP:-0} # when set to 1 the rp.ko will be renamed to rp-dis.ko
BRP_USER_CFG=${BRP_USER_CFG:-"$PWD/user_config.json"}
BRP_CACHE_DIR=${BRP_CACHE_DIR:-"$PWD/cache"} # cache directory where stuff is downloaded & unpacked
BRP_KEEP_BUILD=${BRP_KEEP_BUILD:-''} # will be set to 1 for repack method or 0 for direct
BRP_LINUX_PATCH_METHOD=${BRP_LINUX_PATCH_METHOD:-"direct"} # how to generate kernel image (direct bsp patch vs repack)
BRP_LINUX_SRC=${BRP_LINUX_SRC:-''} # used for repack method
BRP_BOOT_IMAGE=${BRP_BOOT_IMAGE:-"$PWD/ext/boot-image-template.img.gz"} # gz-ed "template" image to base final image on


########################################################################################################################

### CUSTOM VARIABLES FOR TINYCORE 


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


##### INCLUDES #########################################################################################################
. include/log.sh # logging helpers
. include/text.sh # text manipulation
. include/runtime.sh # need to include this early so we can used date and such
. include/json.sh # json parsing routines
. include/config-manipulators.sh
. include/file.sh # file-related operations (copying/moving/unpacking etc)
. include/patch.sh # helpers for patching files using patch(1) and bspatch(1)
. include/boot-image.sh # helper functions for dealing with the boot image
. include/ext-bridge.sh # helper to interact with extensions manager
########################################################################################################################

##### CONFIGURATION VALIDATION##########################################################################################

### Command line params handling
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "Usage: $0 platform version <output-file>"
  exit 1
fi
BRP_HW_PLATFORM="$1"
BRP_SW_VERSION="$2"
pr_warn "HW PLATFORM :  ${BRP_HW_PLATFORM} SW VERSION : ${BRP_SW_VERSION}"
BRP_OUTPUT_FILE="${3:-"$PWD/images/redpill-${BRP_HW_PLATFORM}_${BRP_SW_VERSION}_b$(date '+%s').img"}"

BRP_REL_CONFIG_BASE="$PWD/config/${BRP_HW_PLATFORM}/${BRP_SW_VERSION}"
BRP_REL_CONFIG_JSON="${BRP_REL_CONFIG_BASE}/config.json"


BRP_REL_CONFIG_BASE="$PWD/config/${BRP_HW_PLATFORM}/${BRP_SW_VERSION}"
BRP_REL_CONFIG_JSON="${BRP_REL_CONFIG_BASE}/config.json"

if [ ! -f "${BRP_REL_CONFIG_JSON}" ]; then
  pr_crit "There doesn't seem to be a config for %s platform running %s (checked %s)" \
          "${BRP_HW_PLATFORM}" "${BRP_SW_VERSION}" "${BRP_REL_CONFIG_JSON}"
fi
brp_json_validate "${BRP_REL_CONFIG_JSON}"

### Here we define some common/well-known paths used later, as well as the map for resolving path variables in configs
readonly BRP_REL_OS_ID=$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.id")
readonly BRP_UPAT_DIR="${BRP_BUILD_DIR}/pat-${BRP_REL_OS_ID}-unpacked" # unpacked pat directory
readonly BRP_EXT_DIR="$PWD/ext" # a directory with external tools/files/modules
readonly BRP_COMMON_CFG_BASE="$PWD/config/_common" # a directory with common configs & patches sable for many platforms
readonly BRP_USER_DIR="$PWD/custom"
# vars map for copying files from release configs. If you're changing this please add to docs!
typeset -r -A BRP_RELEASE_PATHS=(
  [@@@_DEF_@@@]="${BRP_REL_CONFIG_BASE}"
  [@@@PAT@@@]="${BRP_UPAT_DIR}"
  [@@@COMMON@@@]="${BRP_COMMON_CFG_BASE}"
  [@@@EXT@@@]="${BRP_EXT_DIR}"
)
# vars map for copying files from user config. If you're changing this please add to docs!
typeset -r -A BRP_USER_PATHS=(
  [@@@_DEF_@@@]="${BRP_USER_DIR}"
)

### Load metadata about extensions
typeset -a RPT_BUNDLED_EXTS_IDS # ordered IDs of bundled extensions
typeset -A RPT_BUNDLED_EXTS # k=>v extensions to their index urls
RPT_BUILD_EXTS='' # by default it's empty == all
RPT_USER_EXTS=''
if [[ "${BRP_DEV_DISABLE_EXTS}" -ne 1 ]]; then
  RPT_USER_EXTS=$(rpt_load_user_extensions "${BRP_USER_CFG}") || exit 1
  rpt_load_bundled_extensions "${RPT_BUNDLED_EXTS_CFG}" RPT_BUNDLED_EXTS_IDS RPT_BUNDLED_EXTS
  if [[ ! -z "${RPT_USER_EXTS}" ]]; then # if user defined some extensions we need to whitelist bundled + user picked
    for ext_id in ${RPT_BUNDLED_EXTS_IDS[@]+"${RPT_BUNDLED_EXTS_IDS[@]}"}; do
      if [[ ! -z "${RPT_BUILD_EXTS}" ]]; then
        RPT_BUILD_EXTS+=','
      fi
      RPT_BUILD_EXTS+="${ext_id}"
    done
    RPT_BUILD_EXTS+=",${RPT_USER_EXTS}"
  fi
fi

pr_dbg "******** Printing config variables ********"
pr_dbg "Cache dir: %s" "$BRP_CACHE_DIR"
pr_dbg "Build dir: %s" "$BRP_BUILD_DIR"
pr_dbg "Ext dir: %s" "$BRP_EXT_DIR"
pr_dbg "User custom dir: %s" "$BRP_USER_DIR"
pr_dbg "User config: %s" "$BRP_USER_CFG"
pr_dbg "Keep build dir? %s" "$BRP_KEEP_BUILD"
pr_dbg "Linux patch method: %s" "$BRP_LINUX_PATCH_METHOD"
pr_dbg "Linux repack src: %s" "$BRP_LINUX_SRC"
pr_dbg "Hardware platform: %s" "$BRP_HW_PLATFORM"
pr_dbg "Software version: %s" "$BRP_SW_VERSION"
pr_dbg "Image template: %s" "$BRP_BOOT_IMAGE"
pr_dbg "Image destination: %s" "$BRP_OUTPUT_FILE"
pr_dbg "Common cfg base: %s" "$BRP_COMMON_CFG_BASE"
pr_dbg "Release cfg base: %s" "$BRP_REL_CONFIG_BASE"
pr_dbg "Release cfg JSON: %s" "$BRP_REL_CONFIG_JSON"
pr_dbg "Release id: %s" "$BRP_REL_OS_ID"
if [[ "${BRP_DEV_DISABLE_EXTS}" -ne 1 ]]; then
  pr_dbg "User extensions [empty means all]: %s" "$RPT_USER_EXTS"
  pr_dbg "Selected extensions [empty means all]: %s" "$RPT_BUILD_EXTS"
else
  pr_warn "User extensions: <disabled>"
  pr_warn "Selected extensions: <all disabled>"
fi
pr_dbg "*******************************************"


##### ADDTL RAMDISK LAYERS #############################################################################################
readonly BRP_CUSTOM_DIR="${BRP_BUILD_DIR}/custom-initrd" # directory with custom initrd layer
readonly BRP_CUSTOM_RD_NAME="custom.gz" # filename of custom initramfs file (it will be loaded by GRUB with this name)
readonly BRP_CUSTOM_RD_PATH="${BRP_BUILD_DIR}/${BRP_CUSTOM_RD_NAME}" # custom layer path for build
readonly RPT_IMG_EXTS_DIR="${BRP_CUSTOM_DIR}/exts" # this is hardcoded as patches have this path hardcoded
readonly BRP_REL_OS_ID=$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.id")


# Handle debug flags for custom ramdisk
if [ "${BRP_DEV_DISABLE_RP}" -eq 1 ]; then
  pr_warn "<DEV> Disabling RedPill LKM"
  "${MV_PATH}" "${BRP_CUSTOM_DIR}/usr/lib/modules/rp.ko" "${BRP_CUSTOM_DIR}/usr/lib/modules/rp-dis.ko" \
    || pr_crit "Failed to move RedPill LKM - did you forget to copy it in platform config?"
fi


if [ ! -f "ext/rp-lkm/redpill-linux-v4.4.180+.ko" ] ; then
pr_crit "Redpill found, copying to custom folder"
fi 



# Copy any extra files to the ramdisk
brp_cp_from_list "${BRP_REL_CONFIG_JSON}" "extra.ramdisk_copy" BRP_RELEASE_PATHS "${BRP_CUSTOM_DIR}"
if [[ "$(brp_json_has_field "${BRP_USER_CFG}" 'ramdisk_copy')" -eq 1 ]]; then
  brp_cp_from_list "${BRP_USER_CFG}" "ramdisk_copy" BRP_USER_PATHS "${BRP_CUSTOM_DIR}"
fi



if [ ! -f "${BRP_CUSTOM_DIR}/usr/lib/modules/rp.ko" ] ; then
pr_warn "Failed to find rp.ko, make sure you copy rp.ko"
exit 99
fi


############ EXTS SPECIFIC VARIABLES

RPT_BUILD_EXTS='' # by default it's empty == all


##### MODULES PREPARATION ##############################################################################################
# We handle the extensions update early on to give the user early error if the image cannot even build due to exts issue
if [[ "${BRP_DEV_DISABLE_EXTS}" -ne 1 ]]; then
  pr_process "Updating extensions"
  pr_empty_nl

  pr_dbg "Verifying bundled extensions"
  for bext_id in "${!RPT_BUNDLED_EXTS[@]}"; do # we can iterate through unordered k=>v as we use all anyway
    pr_dbg "Checking %s bundled extension" "${bext_id}"
    ( ./ext-manager.sh force_add "${bext_id}" "${RPT_BUNDLED_EXTS[$bext_id]}")
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to install %s bundled extension - see errors above" "${bext_id}"
    fi
  done
  rpt_update_ext_indexes

  if [[ -z "${RPT_BUILD_EXTS}" ]]; then
    pr_dbg "Updating & downloading all extensions for %s" "${BRP_REL_OS_ID}"
    ( ./ext-manager.sh _update_platform_exts "${BRP_REL_OS_ID}")
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to update all extensions for %s platform - see errors above" "${BRP_REL_OS_ID}"
    fi
  else
    pr_dbg "Updating & downloading selected extensions (%s) for %s" "${RPT_BUILD_EXTS}" "${BRP_REL_OS_ID}"
    ( ./ext-manager.sh _update_platform_exts "${BRP_REL_OS_ID}" "${RPT_BUILD_EXTS}")
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to update extensions selected (%s) for %s platform - see errors above" \
              "${RPT_BUILD_EXTS}" "${BRP_REL_OS_ID}"
    fi
  fi
  pr_process_ok
fi


# We deliberately copy extensions as the last thing as the dumper will error-out if someone tried to mess with its
# directory (circumventing the extensions system)
if [[ "${BRP_DEV_DISABLE_EXTS}" -ne 1 ]]; then
  pr_process "Bundling extensions"
  brp_mkdir "${RPT_IMG_EXTS_DIR}"
  if [[ -z "${RPT_BUILD_EXTS}" ]]; then
    pr_dbg "Dumping all extensions for %s to %s" "${BRP_REL_OS_ID}" "${RPT_IMG_EXTS_DIR}"
    ( ./ext-manager.sh _dump_exts "${BRP_REL_OS_ID}" "${RPT_IMG_EXTS_DIR}")
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to dump all extensions for %s platform to %s - see errors above" "${BRP_REL_OS_ID}" "${RPT_IMG_EXTS_DIR}"
    fi
  else
    pr_dbg "Dumping selected extensions (%s) for %s to %s" "${RPT_BUILD_EXTS}" "${BRP_REL_OS_ID}" "${RPT_IMG_EXTS_DIR}"
    ( ./ext-manager.sh _dump_exts "${BRP_REL_OS_ID}" "${RPT_IMG_EXTS_DIR}" "${RPT_BUILD_EXTS}")
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to dump extensions selected (%s) for %s platform to %s - see errors above" \
              "${RPT_BUILD_EXTS}" "${BRP_REL_OS_ID}" "${RPT_IMG_EXTS_DIR}"
    fi
  fi
  pr_process_ok
fi


brp_pack_cpiord "${BRP_CUSTOM_RD_PATH}" "${BRP_CUSTOM_DIR}"

rm -rf /${BRP_CUSTOM_DIR}

