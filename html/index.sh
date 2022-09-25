#!/bin/bash

#. ./rploader.sh

function pagehead() {

  cat <<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Bootstrap, from Twitter</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="">
    <meta name="author" content="">

    <!-- Le styles -->
    <link href="assets/css/bootstrap.css" rel="stylesheet">
    <style>
      body {
        padding-top: 60px; /* 60px to make the container go all the way to the bottom of the topbar */
      }
    </style>
    <link href="assets/css/bootstrap-responsive.css" rel="stylesheet">

    <!-- HTML5 shim, for IE6-8 support of HTML5 elements -->
    <!--[if lt IE 9]>
      <script src="assets/js/html5shiv.js"></script>
    <![endif]-->

    <!-- Fav and touch icons -->
    <link rel="apple-touch-icon-precomposed" sizes="144x144" href="assets/ico/apple-touch-icon-144-precomposed.png">
    <link rel="apple-touch-icon-precomposed" sizes="114x114" href="assets/ico/apple-touch-icon-114-precomposed.png">
      <link rel="apple-touch-icon-precomposed" sizes="72x72" href="assets/ico/apple-touch-icon-72-precomposed.png">
                    <link rel="apple-touch-icon-precomposed" href="assets/ico/apple-touch-icon-57-precomposed.png">
                                   <link rel="shortcut icon" href="assets/ico/favicon.png">
  </head>

  <body>

EOF
}

function selectmodel() {

  cat <<EOF
<form id="myform" method=POST action="/rploader/">
<select id="mymodel" name="mymodel">
EOF
  echo "<option value=\"'Please Select Model\">Select Model</option>"
  #for model in `getPlatforms`
  for model in $(ls redpill-load/config | grep -v comm | sed -e 's/\///'); do
    echo "<option value=\"'$model\">$model</option>"
  done
  cat <<EOF
 </select>
</form>
<div id="output"></div>
EOF

}

function selectversion() {

  cat <<EOF
<form id="myversion" method=POST action="/rploader/?mymodel=$MODEL&myversion=$VERSION">
<select id="myversion" name="myversion">
EOF
  echo "<option value=\"'Please Select OS Version\">Select version</option>"
  for version in $(ls redpill-load/config/$MODEL/ | grep -v comm | sed -e 's/\///'); do
    echo "<option value=\"'$version\">$version</option>"
  done
  cat <<EOF
 </select>
  <input id="mymodel" name="mymodel" value="$MODEL" hidden required />
  
</form>
<div id="output"></div>
EOF

}

function urldecode {
  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

function pagebody() {
  cat <<EOF

    <div class="navbar navbar-inverse navbar-fixed-top">
      <div class="navbar-inner">
        <div class="container">
          <button type="button" class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="brand" href=""/rploader/">TinyCore RedPill</a>
          <div class="nav-collapse collapse">
            <ul class="nav">
              <li class="active"><a href="/rploader/">Home</a></li>
              <li><a href="https://github.com/pocopico/tinycore-redpill">Tinycore Redpill Repo</a></li>
              <li><a href="https://xpenology.com/forum/topic/53817-redpill-tinycore-loader/">Contact</a></li>
            </ul>
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>

    <div class="container">
 
      <h1>TinyCore Redpill, Version $(version)</h1>
	  
EOF
}

function pagefooter() {
  cat <<EOF
    </div> <!-- /container -->

    <!-- Le javascript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/xcash/bootstrap-autocomplete@v2.3.7/dist/latest/bootstrap-autocomplete.min.js"></script>

    <script src="assets/js/bootstrap-transition.js"></script>
    <script src="assets/js/bootstrap-alert.js"></script>
    <script src="assets/js/bootstrap-modal.js"></script>
    <script src="assets/js/bootstrap-dropdown.js"></script>
    <script src="assets/js/bootstrap-scrollspy.js"></script>
    <script src="assets/js/bootstrap-tab.js"></script>
    <script src="assets/js/bootstrap-tooltip.js"></script>
    <script src="assets/js/bootstrap-popover.js"></script>
    <script src="assets/js/bootstrap-button.js"></script>
    <script src="assets/js/bootstrap-collapse.js"></script>
    <script src="assets/js/bootstrap-carousel.js"></script>
    <script src="assets/js/bootstrap-typeahead.js"></script>


<script>
\$(document).ready(function() {
  \$('#myform').val("$MODEL");
   \$('#mymodel').change( function() {
     \$('#myform').submit();
       \$.ajax({ // create an AJAX call...
           data: \$(this).serialize(), // get the form data
           type: \$(this).attr('method'), // GET or POST
           url: \$(this).attr('action'), // the file to call
           success: function(response) { // on success..
               \$('#output').html(response); // update the DIV
           }
       });
       return false; // cancel original event to prevent form submitting
    });
     \$('#myversion').val("$VERSION");
   \$('#myversion').change( function() {
     \$('#myversion').submit();
       \$.ajax({ // create an AJAX call...
           data: \$(this).serialize(), // get the form data
           type: \$(this).attr('method'), // GET or POST
           url: \$(this).attr('action'), // the file to call
           success: function(response) { // on success..
               \$('#output').html(response); // update the DIV
           }
       });
       return false; // cancel original event to prevent form submitting
    });
});

function onModelChange() {
  var x = document.getElementById("myModel").value;
  document.getElementById("model").innerHTML = "You selected: " + x;
}

\$('#mybuild input[id=model]').val(input.model).prop('readonly', true);

</script>

<p id="model"></p>

  </body>
</html>
EOF

}

function serialgen() {

  [ ! -z "$GATEWAY_INTERFACE" ] && shift 0 || shift 1

  [ "$2" == "realmac" ] && let keepmac=1 || let keepmac=0

  if [ "$1" = "DS3615xs" ] || [ "$1" = "DS3617xs" ] || [ "$1" = "DS916+" ] || [ "$1" = "DS918+" ] || [ "$1" = "DS920+" ] || [ "$1" = "DS3622xs+" ] || [ "$1" = "FS6400" ] || [ "$1" = "DVA3219" ] || [ "$1" = "DVA3221" ] || [ "$1" = "DS1621+" ] || [ "$1" = "DVA1622" ]; then
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
    echo "Available Models : DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xs+ FS6400 DVA3219 DVA3221 DS1621+ DVA1622"
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
  esac

  echo $serialnum

}

function buildform() {

  json=$(jq --arg var "$MODEL" '.general.model = $var' user_config.json) && echo -E "${json}" | jq . >user_config.json
  json=$(jq --arg var "$VERSION" '.general.version = $var' user_config.json) && echo -E "${json}" | jq . >user_config.json

  serialgen "$MODEL" | awk -F= '{print $2}' | sed -e 'N;s/\n/ /' | read serial macaddress
  serialgen "$MODEL" >/dev/null

  cat <<EOF
<form id="mybuild" action="/rploader/" method="POST">
  <label for="mymodel">Model</label>
  <input id="mymodel" name="mymodel" value="$MODEL" required readonly/>
  <label for="myversion">Version</label>
  <input id="myversion" name="myversion" value="$VERSION" required readonly />
  <label for="serial">Serial</label>
  <input id="serial" name="serial" value="$serial" required />
  <label for="macaddress">Macaddress</label>
  <input id="macaddress" name="macaddress" value="$macaddress" required />
  <label class="form-check-label" for="addexts">Automatically add extensions)</label>
  <input class="form-check-input" type="checkbox" name="addexts" id="addexts" value="auto" checked>
  <input id="buildit" name="buildit" value="yes" hidden required />
  <label for="extracmdline">Extra Command Line Options (e.g SataPortMap, DiskIdxMap etc</label>
  <textarea id="extracmdline" name="extracmdline" value=" "> </textarea>
  
  <br><br><button type="submit">Build</button>

</form>
EOF

}

function getpost() {
  echo ""
}

function startover() {

  echo "<button type=\"button\" class=\"btn btn-primary btn-lg btn-block\" onclick="window.location.href='/rploader/'">START OVER</button>"

}

function getcontent() {

  echo "<details>"
  echo "<summary>$1</summary>"
  echo "<pre>$($@)"
  echo "</pre></details>"

}

function wecho() {
  echo "<br>$@"
}

function getvars() {
  tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
  local_cache="/mnt/${tcrppart}/auxfiles"
  GETTIME=$(curl -v --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
  INTERNETDATE=$(date +"%d%m%Y" -d "$GETTIME")
  LOCALDATE=$(date +"%d%m%Y")

  OS_ID=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e ' .os .id')
  PAT_URL=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e ' .os .pat_url')
  PAT_SHA=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e ' .os .sha256')
  ZIMAGE_SHA=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e '.files .zlinux .sha256')
  RD_SHA=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e '.files .ramdisk .sha256')
  RAMDISK_PATCH=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e ' .patches .ramdisk')
  SYNOINFO_PATCH=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e ' .synoinfo')
  RAMDISK_COPY=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e ' .extra .ramdisk_copy')
  SYNOINFO_USER=$(cat /home/tc/user_config.json | jq -r -e ' .synoinfo')
  RD_COMPRESSED=$(cat /home/tc/redpill-load/config/$MODEL/$VERSION/config.json | jq -r -e ' .extra .compress_rd')
  redpillextension="https://github.com/pocopico/rp-ext/raw/main/redpill/rpext-index.json"
  FILENAME="${OS_ID}.pat"

  mount ${tcrppart}

}

function checkextractor() {

  if [ -d /mnt/${tcrppart}/auxfiles/patch-extractor ] && [ -f /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.nano ]; then
    extractorcached="yes"
  else
    extractorcached="yes"
  fi

}

function downloadextractor() {

  mkdir /home/tc/patch-extractor/

  cd /home/tc/patch-extractor/

  curl --insecure --location https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3622xs%2B_42218.pat --output /home/tc/oldpat.tar.gz
  #[ -f /home/tc/oldpat.tar.gz ] && tar -C${temp_folder} -xf /home/tc/oldpat.tar.gz rd.gz

  tar xvf ../oldpat.tar.gz hda1.tgz
  tar xf hda1.tgz usr/lib
  tar xf hda1.tgz usr/syno/sbin

  mkdir /home/tc/patch-extractor/lib/

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

  curl --silent --location https://github.com/pocopico/tinycore-redpill/blob/develop/tools/xxd?raw=true --output xxd

  chmod +x xxd

  ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0100/' | ./xxd -r >synoarchive.nano
  ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0a00/' | ./xxd -r >synoarchive.smallpatch
  ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0000/' | ./xxd -r >synoarchive.system

  chmod +x synoarchive.*

  [ ! -d /mnt/${tcrppart}/auxfiles/patch-extractor ] && mkdir /mnt/${tcrppart}/auxfiles/patch-extractor

  cp -rf /home/tc/patch-extractor/lib /mnt/${tcrppart}/auxfiles/patch-extractor/
  cp -rf /home/tc/patch-extractor/synoarchive.* /mnt/${tcrppart}/auxfiles/patch-extractor/

  ## get list of available pat versions from
  #curl --silent https://archive.synology.com/download/Os/DSM/ | grep "/download/Os/DSM/7" | awk '{print $2}' | awk -F\/ '{print $5}' | sed -s 's/"//g'
  ## Get the selected update pats for your platform/version
  #curl --silent https://archive.synology.com/download/Os/DSM/7.1-42661-3 | grep href | grep apollolake | awk '{print $2}'
  ## Select URL
  #curl --silent https://archive.synology.com/download/Os/DSM/7.1-42661-2 | grep href | grep apollolake | awk '{print $2}' | awk -F= '{print $2}'
  ## URL
  #url=$(curl --silent https://archive.synology.com/download/Os/DSM/7.1-42661-3 | grep href | grep geminilake | awk '{print $2}' | awk -F= '{print $2}' | sed -s 's/"//g')

  #curl --location $url -O

  #patfile=$(echo $url | awk -F/ '{print $9}')

  mkdir temp && cd temp

  if [ -d /mnt/${tcrppart}/auxfiles/patch-extractor ] && [ -f /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.nano ]; then
    LD_LIBRARY_PATH=/mnt/${tcrppart}/auxfiles/patch-extractor/lib /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.nano -xvf /home/tc/patch-extractor/$patfile
  else
    wecho "Extractor not found"
  fi
  ## Extract ramdisk

  flashfile=$(ls flashupdate*s2*)

  tar xvf $flashfile && tar xvf content.txz

  mkdir rd.temp
  cd rd.temp && unlzma -c ../rd.gz | cpio -idm
  etc/VERSION

}

function getstaticmodule() {

  #SYNOMODEL="$(echo $MODEL | sed -s 's/+/p/g' | tr '[:upper:]' '[:lower:]')_${REVISION}"
  SYNOMODEL="$(echo $MODEL | sed -s 's/+/p/g' | tr '[:upper:]' '[:lower:]')_42218"

  cd /home/tc

  wecho "Removing any old redpill.ko modules"
  [ -f /home/tc/redpill.ko ] && rm -f /home/tc/redpill.ko

  extension=$(curl --insecure --silent --location "$redpillextension")

  wecho "Looking for redpill for : $SYNOMODEL"

  #release=`echo $extension |  jq -r '.releases .${SYNOMODEL}_{$TARGET_REVISION}'`
  release=$(echo $extension | jq -r -e --arg SYNOMODEL $SYNOMODEL '.releases[$SYNOMODEL]')
  files=$(curl --insecure --silent --location "$release" | jq -r '.files[] .url')

  for file in $files; do
    wecho "Getting file $file"
    curl --insecure --silent -O $file
    if [ -f redpill*.tgz ]; then
      wecho "Extracting module"
      tar xf redpill*.tgz
      rm redpill*.tgz
      strip --strip-debug redpill.ko
    fi
  done

  if [ -f /home/tc/redpill.ko ] && [ -n $(strings /home/tc/redpill.ko | grep -i $MODEL) ]; then
    wecho "Copying redpill.ko module to ramdisk"
    cp /home/tc/redpill.ko /home/tc/temppat/rd.temp/usr/lib/modules/rp.ko
  else
    wecho "Module does not contain platorm information for ${MODEL}"
  fi

  [ -f /home/tc/temppat/rd.temp/usr/lib/modules/rp.ko ] && wecho "Redpill module is in place"

}

function testarchive() {

  archive="$1"
  archiveheader="$(od -bc ${archive} | head -1 | awk '{print $3}')"

  case ${archiveheader} in
  105)
    wecho "${archive}, is a Tar file"
    isencrypted="no"
    return 0
    ;;
  255)
    wecho "File ${archive}, is  encrypted"
    isencrypted="yes"
    return 1
    ;;
  213)
    wecho "File ${archive}, is a compressed tar"
    isencrypted="no"
    ;;
  *)
    wecho "Could not determine if file ${archive} is encrypted or not, maybe corrupted"
    ls -ltr ${archive}
    wecho ${archiveheader}
    exit 99
    ;;
  esac

}

function _set_conf_kv() {
  # Delete
  if [ -z "$2" ]; then
    sed -i "$3" -e "s/^$1=.*$//"
    return 0
  fi

  # Replace
  if grep -q "^$1=" "$3"; then
    sed -i "$3" -e "s\"^$1=.*\"$1=\\\"$2\\\"\""
    return 0
  fi

  # Add if doesn't exist
  echo "$1=\"$2\"" >>$3
}

function downloadpat() {

  if [ ! -f $FILENAME ]; then
    wecho "Downloading PAT file $FILENAME for MODEL=$MODEL, Version=$VERSION, SHA256=$PAT_SHA"
    curl --insecure --silent "$PAT_URL" --output $FILENAME 2>&1 >curlstatus.out
    [ "$(sha256sum $FILENAME | awk '{print $1}')" = "$PAT_SHA" ] && wecho "File downloaded and matches expected sha256sum" || wecho "Error downloaded file is corrupted"
  else
    wecho "$(sha256sum $FILENAME | awk '{print $1}')" = "$PAT_SHA"
    wecho "File is already downloaded"

    if [ "$(sha256sum $FILENAME | awk '{print $1}')" = "$PAT_SHA" ]; then
      wecho "File downloaded and matches expected sha256sum"
    else
      wecho "Error downloaded file is corrupted"
      #rm -f $FILENAME
    fi
  fi

}

function downloadtools() {

  wecho "Downloading tools"

  [ ! -d /home/tc/tools ] && mkdir /home/tc/tools
  cd /home/tc/tools
  for FILE in bspatch bzImage-to-vmlinux.sh calc_run_size.sh crc32 dtc kexec ramdisk-patch.sh vmlinux-to-bzImage.sh xxd zimage-patch.sh kpatch zImage_template.gz; do
    [ ! -f /home/tc/tools/$FILE ] && curl --silent --insecure --location "https://raw.githubusercontent.com/pocopico/tinycore-redpill/develop/tools/${FILE}" -O
    chmod +x $FILE
  done

  cd /home/tc

}

function extractencryptedpat() {

  FILENAME="$1"

  checkextractor && [ "$extractorcached" = "yes" ] && wecho "Extractor Cached, proceeding..."
  wecho "Extracting PAT file $FILENAME"
  [ ! -d /home/tc/temppat ] && mkdir /home/tc/temppat

  LD_LIBRARY_PATH=/mnt/${tcrppart}/auxfiles/patch-extractor/lib /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.system -C /home/tc/temppat -xf /home/tc/$FILENAME

  [ -f /home/tc/temppat/VERSION ] && . /home/tc/temppat/VERSION && wecho "Extracted PAT file, VERSION Found : ${major}.${minor}.${micro}_${buildnumber}"
  extractedzImagesha="$(sha256sum /home/tc/temppat/zImage | awk '{print $1}')"
  extractedrdsha="$(sha256sum /home/tc/temppat/rd.gz | awk '{print $1}')"
  wecho "zImage sha256sum : $extractedzImagesha" && json=$(jq --arg var "${extractedzImagesha}" '.general.zimghash = $var' user_config.json) && echo -E "${json}" | jq . >user_config.json
  wecho "rd sha256sum : $extractedrdsha" && json=$(jq --arg var "${extractedrdsha}" '.general.rdhash = $var' user_config.json) && echo -E "${json}" | jq . >user_config.json

}

function patchkernel() {

  wecho "Patching Kernel"
  /home/tc/tools/bzImage-to-vmlinux.sh /home/tc/temppat/zImage /home/tc/temppat/vmlinux >log 2>&1 >/dev/null
  /home/tc/tools/kpatch /home/tc/temppat/vmlinux /home/tc/temppat/vmlinux-mod >log 2>&1 >/dev/null
  /home/tc/tools/vmlinux-to-bzImage.sh /home/tc/temppat/vmlinux-mod /home/tc/temppat/zImage-dsm >/dev/null

  [ -f /home/tc/temppat/zImage-dsm ] && wecho "Kernel Patched, sha256sum : $(sha256sum /home/tc/temppat/zImage-dsm)"

}

function cleanbuild() {

  wecho "Cleaning build directory"

  rm -rf /home/tc/temppat

}

function patchramdisk() {

  temprd="/home/tc/temppat/rd.temp/"
  wecho "Patching RamDisk"
  wecho "Extracting ramdisk to $temprd"

  [ ! -d $temprd ] && mkdir $temprd && cd $temprd && xz -dc <"/home/tc/temppat/rd.gz" | cpio -idm >/dev/null 2>&1
  [ -f /home/tc/temppat/rd.temp/VERSION ] && /home/tc/temppat/rd.temp/VERSION
  wecho "Extracted ramdisk VERSION : ${major}.${minor}.${micro}_${buildnumber}"
  PATCHES="$(echo $RAMDISK_PATCH | jq . | sed -s 's/@@@COMMON@@@/\/home\/tc\/redpill-load\/config\/_common/' | grep config | sed -s 's/"//g' | sed -s 's/,//g')"

  wecho "Patches to be applied : $PATCHES"

  cd $temprd
  for patch in $PATCHES; do
    wecho "Applying patch $patch in dir $PWD"
    patch -p1 <$patch
  done

  wecho "Applying model synoinfo patches"

  while IFS=":" read KEY VALUE; do
    echo "Key :$KEY Value: $VALUE"
    _set_conf_kv $KEY $VALUE $temprd/etc/synoinfo.conf
  done <<<$(echo $SYNOINFO_PATCH | jq . | grep ":" | sed -s 's/"//g' | sed -s 's/,//g')

  wecho "Applying user synoinfo settings"

  while IFS=":" read KEY VALUE; do
    echo "Key :$KEY Value: $VALUE"
    _set_conf_kv $KEY $VALUE $temprd/etc/synoinfo.conf
  done <<<$(echo $SYNOINFO_USER | jq . | grep ":" | sed -s 's/"//g' | sed -s 's/,//g')

  wecho "Copying extra ramdisk files "

  while IFS=":" read SRC DST; do
    echo "Source :$SRC Destination : $DST"
    cp -f $SRC $DST
  done <<<$(echo $RAMDISK_COPY | jq . | grep "COMMON" | sed -s 's/"//g' | sed -s 's/,//g' | sed -s 's/@@@COMMON@@@/\/home\/tc\/redpill-load\/config\/_common/')

  wecho "Adding precompiled redpill module"
  getstaticmodule

  # Reassembly ramdisk
  wecho "Reassempling ramdisk"
  if [ "${RD_COMPRESSED}" == "true" ]; then
    (cd "${temprd}" && find . | cpio -o -H newc -R root:root | xz -9 --format=lzma >"/home/tc/temppat/initrd-dsm") >/dev/null 2>&1 >/dev/null
  else
    (cd "${temprd}" && find . | cpio -o -H newc -R root:root >"/home/tc/temppat/initrd-dsm") >/dev/null 2>&1
  fi
  [ -f /home/tc/temppat/initrd-dsm ] && wecho "Patched ramdisk created $(ls -l /home/tc/temppat/initrd-dsm)"

  wecho "Copying file to ${tcrppart}"

  cp -f /home/tc/temppat/zImage-dsm /mnt/${tcrppart}/
  cp -f /home/tc/temppat/initrd-dsm /mnt/${tcrppart}/

}

json_get_keys() {
  local -n __json_return=$3

  local out
  out=$(/usr/local/bin/jq -r -e ".${2}|keys_unsorted|.[]" "${1}" 2>&1)
  if [ $? -ne 0 ]; then
    wecho "Failed extract K=>V pairs from %s:.%s\n\n%s" "${1}" "${2}" "${out}"
  fi

  readarray -t __json_return <<<"${out}"
}

read_kv_to_array() {
  # kv_pair used dynamically in kv_extractor
  # shellcheck disable=SC2034
  local -n __json_kv_pairs=$3
  local kv_extractor='.'"${2}"'|to_entries|map("[\(.key|@sh)]=\(.value|@sh) ")|"__json_kv_pairs=(" + add + ")"'

  local out
  out=$(/usr/local/bin/jq -r -e "${kv_extractor}" "${1}" 2>&1)
  if [ $? -ne 0 ]; then
    wecho "Failed extract K=>V pairs from %s:.%s\n\n%s" "${1}" "${2}" "${out}"
  fi

  # if you get a useless BASH error "invalid arithmetic operator" here check the variable you've passed (it must be -A)
  eval "$out"
}

read_ordered_kv() {
  local -n __json_keys=$3
  local -n __json_values=$4
  json_get_keys "${1}" "${2}" __json_keys
  read_kv_to_array "${1}" "${2}" __json_values # we can reuse code to read k=>v pairs as we need them anyway
}
# Finds the token in file and replaces it with an arbitrary string
#
# This is slightly stupid because it uses a temporary file, but even our senior sed magician gave up. PRs welcomed.
#
# Args: $1 file to modify | $2 token | $3 text to insert

replace_token_with_text() {
  local temp_file="${1}.tmp_ins_frag"
  wecho "Replacing \"%s\" with text from %s in %s" "${2}" "${temp_file}" "${1}"

  echo "${3}" >"${temp_file}"
  if [ $? -ne 0 ]; then
    wecho "Failed to create temp file %s" "${temp_file}"
  fi

  local out
  out=$(sed -e "/${2}/ {" -e "r ${temp_file}" -e 'd' -e '}' -i "${1}" 2>&1)
  if [ $? -ne 0 ]; then
    wecho "Failed to replace %s in file %s with contents of %s\n\n%s" "${2}" "${1}" "${temp_file}" "${out}"
  fi
  rm -f "${temp_file}" || wecho "Failed to remove temp file %s" "${temp_file}"
}

json_noe() {
  if [ "$1" == "null" ] || [ -z "$1" ]; then
    return 0
  else
    return 1
  fi
}

json_get_field() {
  local field_val
  field_val=$(/usr/local/bin/jq -e -r ".$2" "$1")
  # "1 if the last output value was either false or null"
  if [ $? -le 1 ]; then
    echo $field_val
    return 0
  fi

  if [ "${3:-'0'}" != 1 ]; then
    wecho "Field \"$2\" doesn't existing in $1"
  fi
}

json_get_array_values() {
  local field_val
  field_val=$(/usr/local/bin/jq -e -r ".${2} | .[]" "${1}")
  local jq_exit=$?

  # "1 if the last output value was either false or null", 4 if it was empty... we hate it
  if [[ jq_exit -le 1 ]] || [[ jq_exit -eq 4 ]]; then
    echo "${field_val}"
    return 0
  fi

  if [ "${3:-'0'}" != 1 ]; then
    wecho "Field \"$2\" doesn't existing in $1"
  fi
}

expand_var_path() {
  local -n __vars_map=$2
  local file_path="${1}"

  if [[ "${1}" == /* ]]; then
    : #noop, absolute paths don't need any modifications
  elif [[ "${1}" != @@@* ]]; then
    # since path doesn't begin with a variable we just assume the default
    file_path="${__vars_map["@@@_DEF_@@@"]}/${file_path}"
  else
    local var_value
    for var_name in "${!__vars_map[@]}"; do
      var_value="${__vars_map[$var_name]}"
      file_path="${file_path/${var_name}/${var_value}}"
    done
  fi

  wecho "Resolved path '${1}' to '${file_path}'"
  echo "${file_path}"
}

function getcmdline() {

  # Generates GRUB config file from a config structure
  #
  # - The main config file is expected to have .grub root key
  # - The user config is expected to have extra_cmdline key
  #
  # Args:
  #   $1 main JSON config
  #   $2 user config
  #   $3 reference to a map of K=>V pairs with variables, see expand_var_path()
  #   $4 GRUB config destination file path

  local menu_entries_txt
  local -n _path_map=$3

  # First get user cmdline overrides
  wecho "Reading user extra_cmdline entries"
  local -A extra_cmdline
  read_kv_to_array "${2}" 'extra_cmdline' extra_cmdline
  if [[ -v ${extra_cmdline['sn']} ]]; then wecho "User configuration (%s) doesn't contain unique extra_cmdline.sn" "${2}"; fi
  if [[ -v ${extra_cmdline['vid']} ]]; then wecho "User configuration (%s) doesn't contain extra_cmdline.vid" "${2}"; fi
  if [[ -v ${extra_cmdline['pid']} ]]; then wecho "User configuration (%s) doesn't contain extra_cmdline.pid" "${2}"; fi
  if [[ -v ${extra_cmdline['mac1']} ]]; then wecho "User configuration (%s) doesn't contain at least one MAC (extra_cmdline.mac1)" "${2}"; fi

  # First generate menu entries
  wecho "Generating GRUB menu entries"
  local entries_names
  json_get_keys "${1}" 'grub.menu_entries' entries_names

  # Cmdline is constructed by applying, in order, options from the follownig sources
  #  - platform config.json => .grub.base_cmdline
  #  - platform config.json => .grub.menu_entries.<entry name>.cmdline
  #  - user_config.json => .grub.menu_entries.<entry name>.extra_cmdline

  local -A base_cmdline
  wecho "Reading base cmdline"
  read_kv_to_array "${1}" "grub.base_cmdline" base_cmdline

  local -A entry_cmdline
  local -A final_cmdline
  local -a menu_entries_arr
  local entry_cmdline_txt
  for entry_name in "${entries_names[@]}"; do
    wecho "Processing entry \"%s\"" "${entry_name}"

    final_cmdline=()
    # Bash doesn't have any sensible way of merging or even copying associative arrays... FML
    # See https://stackoverflow.com/a/8881121
    for base_cmdl_key in "${!base_cmdline[@]}"; do final_cmdline[$base_cmdl_key]=${base_cmdline[$base_cmdl_key]}; done

    wecho "Applying entry cmdline"
    read_kv_to_array "${1}" "grub.menu_entries[\"${entry_name}\"].cmdline" entry_cmdline # read entry CMDLINE
    for entry_cmdl_key in "${!entry_cmdline[@]}"; do
      wecho "Replacing base cmdline \"%s\" value \"%s\" with entry value \"%s\"" \
        "${entry_cmdl_key}" "${final_cmdline[entry_cmdl_key]:-<not set>}" "${entry_cmdline[$entry_cmdl_key]}"
      final_cmdline[$entry_cmdl_key]=${entry_cmdline[$entry_cmdl_key]}
    done

    wecho "Applying user extra_cmdline"
    for user_cmdl_key in "${!extra_cmdline[@]}"; do
      wecho "Replacing previous cmdline \"%s\" value \"%s\" with user value \"%s\"" \
        "${user_cmdl_key}" "${final_cmdline[$user_cmdl_key]:-<not set>}" "${extra_cmdline[$user_cmdl_key]}"
      final_cmdline[$user_cmdl_key]=${extra_cmdline[$user_cmdl_key]}
    done

    # Build the final cmdline for the entry
    # There are more tricks in BASH 5.1 for printing but not on v4.3 which is standard on Debian 8 (needed for old GCC)
    entry_cmdline_txt=''
    for cmdline_key in "${!final_cmdline[@]}"; do
      if json_noe "${final_cmdline[$cmdline_key]}"; then
        entry_cmdline_txt+="${cmdline_key} "
      else
        entry_cmdline_txt+="${cmdline_key}=${final_cmdline[$cmdline_key]} "
      fi
    done
    wecho "Generated cmdline for entry: %s" "${entry_cmdline_txt}"

    # Now we can actually assemble the entry
    menu_entries_txt+="menuentry '${entry_name}' {"$'\n'
    read_ordered_kv "${1}" "grub.menu_entries[\"${entry_name}\"].options" entry_options_keys entry_options_vals

    readarray -t menu_entries_arr <<<"$(json_get_array_values "${1}" "grub.menu_entries[\"${entry_name}\"].options")"
    for entry in "${menu_entries_arr[@]}"; do
      menu_entries_txt+=$'\t'"${entry/@@@CMDLINE@@@/${entry_cmdline_txt}}"$'\n'
    done
    menu_entries_txt+='}'$'\n'$'\n'
  done

  wecho "Generated all menu entries:\n%s" "${menu_entries_txt}"

  wecho "Assembling final grub config in %s" "${4}"
  local template
  template=$(json_get_field "${1}" 'grub.template')
  wecho "$(expand_var_path "${template}" _path_map)" "${4}"
  replace_token_with_text "${4}" '@@@MENU_ENTRIES@@@' "${menu_entries_txt}"

}

function build() {

  cleanbuild
  testarchive $FILENAME
  checkextractor
  [ "$isencrypted" = "yes" ] && [ "$extractorcached" = "no" ] && downloadextractor
  [ "$isencrypted" = "yes" ] && [ "$extractorcached" = "yes" ] && extractencryptedpat $FILENAME

  [ "$extractedzImagesha" = "$ZIMAGE_SHA" ] && wecho "zImage sha256sum matches expected sha256sum, patching kernel" && patchkernel
  [ "$extractedrdsha" = "$RD_SHA" ] && wecho "ramdisk sha256sum matches expected sha256sum, patching kernel" && patchramdisk

  [ -n "${extracmdline}" ] && wecho "Extra User built defined command line parameters ${extracmdline}"

  while IFS="=" read KEY VALUE; do
    #wecho "User cmdline Key :$KEY Value: $VALUE"
    #_set_conf_kv $KEY $VALUE user_config.json
    #wecho "Debug : ${KEY} : $(json_has_field '/home/tc/user_config.json' '.extra_cmdline.$KEY')"
    if [ ! -z $KEY ] && [ ! -z $VALUE ]; then
      /usr/local/bin/jq -e -r ".extra_cmdline.${KEY}|select(0)" "/home/tc/user_config.json" >/dev/null 2>&1 >/dev/null
      rtncode=$?
      if [ $rtncode -eq 0 ]; then
        #wecho "Field exists, updating"
        json=$(jq --arg var "${VALUE}" ".extra_cmdline.${KEY}"' = $var' user_config.json) && echo -E "${json}" | jq . >user_config.json
      else
        #wecho "Field does not exist, adding "
        json=$(jq ".extra_cmdline +={\"${KEY}\":\"$VALUE\"}" user_config.json) && echo -E "${json}" | jq . >user_config.json
      fi
    fi
  done <<<$(echo $extracmdline | sed -s 's/ /\n/g')

  wecho "Clearing and testing user_config.json"
  json=$(cat /home/tc/user_config.json | sed -s 's/\\r//g' | jq .) && echo -E "${json}" | jq . >user_config.json

  wecho "Building CMD Line"

  USB_LINE=$(getcmdline /home/tc/redpill-load/config/$MODEL/$VERSION/config.json /home/tc/user_config.json 2>&1 | grep linux | head -1 | cut -c 16-999)
  SATA_LINE=$(getcmdline /home/tc/redpill-load/config/$MODEL/$VERSION/config.json /home/tc/user_config.json 2>&1 | grep linux | tail -1 | cut -c 16-999)

  wecho "Updated user_config with USB Command Line : $USB_LINE"
  json=$(jq --arg var "${USB_LINE}" '.general.usb_line = $var' user_config.json) && echo -E "${json}" | jq . >user_config.json
  wecho "Updated user_config with SATA Command Line : $SATA_LINE"
  json=$(jq --arg var "${SATA_LINE}" '.general.sata_line = $var' user_config.json) && echo -E "${json}" | jq . >user_config.json

  wecho "Copying user_config.json to boot partition"
  cp -f /home/tc/user_config.json /mnt/${tcrppart}/
  [ "$(sha256sum /home/tc/user_config.json | awk '{print $1}')" = "$(sha256sum /mnt/${tcrppart}/user_config.json | awk '{print $1}')" ] && wecho "File copied succesfully" || wecho "User config file is corrupted "

}

[ -z "$POST_STRING" -a "$REQUEST_METHOD" = "POST" -a ! -z "$CONTENT_LENGTH" ] && read -n $CONTENT_LENGTH POST_STRING

OIFS=$IFS
IFS='=&'
parm_get=($QUERY_STRING)
parm_post=($POST_STRING)
IFS=$OIFS

declare -A get
declare -A post

for ((i = 0; i < ${#parm_get[@]}; i += 2)); do
  get[${parm_get[i]}]=$(urldecode ${parm_get[i + 1]})
done

for ((i = 0; i < ${#parm_post[@]}; i += 2)); do
  post[${parm_post[i]}]=$(urldecode ${parm_post[i + 1]})
done

if [ -z "$GATEWAY_INTERFACE" ]; then
  echo "This is meant to run under CGI or to include functions in other scripts"
else

  echo "Gateway is : $GATEWAY_INTERFACE"
  pagehead
  pagebody

  #echo "QUERY : $QUERY_STRING"
  #echo "POST : $POST_STRING"
  #echo "<br>INITIAL PAGE, REQUEST : $REQUEST_METHOD"

  if [ "$REQUEST_METHOD" = "GET" ]; then
    MODEL="$(echo ${get[mymodel]} | sed -s "s/'//g")"
    VERSION="$(echo ${get[myversion]} | sed -s "s/'//g")"
  elif [ "$REQUEST_METHOD" = "POST" ]; then
    if [ -z "$(echo ${post[mymodel]} | sed -s "s/'//g")" ]; then
      MODEL="$(echo "${get[mymodel]}" | sed -s "s/'//g")"
    else
      MODEL="$(echo "${post[mymodel]}" | sed -s "s/'//g")"
    fi
    VERSION="$(echo "${post[myversion]}" | sed -s "s/'//g")"
    REVISION="$(echo "${VERSION}" | awk -F- '{print $2}')"
    serial="$(echo "${post[serial]}" | sed -s "s/'//g")"
    macaddress="$(echo "${post[macaddress]}" | sed -s "s/'//g")"
    buildit="$(echo "${post[buildit]}" | sed -s "s/'//g")"
    extracmdline="$(
      echo "${post[extracmdline]}" | sed -s "s/'//g" | sed -s 's/ /\n/g' | sed -s 's/%3D/=/g'
    )"

  fi

  echo "POST STRING : $POST_STRING"
  #echo "<br>REQUEST METHOD $REQUEST_METHOD , MODEL : $MODEL , VERSION : $VERSION"
  #echo "<br>Serial : $serial , MAC : $macaddress , Buildit : $buildit"

  if [ ! -z "$MODEL" ] && [ ! -z "$VERSION" ] && [ ! -z "$serial" ] && [ ! -z "$macaddress" ] && [ ! -z "$buildit" ]; then
    echo "<br>Building loader for model, $MODEL and software version, $VERSION<br>"
    downloadtools

    getvars
    downloadpat
    build
    startover

  fi

  if [ -z "$MODEL" ]; then

    selectmodel

  elif [ -z "$VERSION" ]; then
    selectversion
  fi

  if [ ! -z "$MODEL" ] && [ ! -z "$VERSION" ] && [ -z "$serial" ] && [ -z "$macaddress" ] && [ -z "$buildit" ]; then

    #selectversion
    #echo "<br></h1>Selected Model = $MODEL <br> Selected Version = $VERSION</h1><br>"

    buildform
    startover
  fi

  pagefooter
fi
