#!/usr/bin/sudo bash

###### VARIABLES

HOMEPATH="/home/tc"
TEMPPAT="${HOMEPATH}/temppat"
CONFIGFILES="${HOMEPATH}/config"
CUSTOMCONFIG="${HOMEPATH}/custom_config2.json"
PATCHEXTRACTOR="${HOMEPATH}/patch-extractor"
THISURL="index.sh"
BUILDLOG="/home/tc/html/buildlog.txt"
USERCONFIGFILE="/home/tc/user_config.json"
TOOLSPATH="https://raw.githubusercontent.com/pocopico/tinycore-redpill/main/tools/"
SCRIPTREPO="https://github.com/pocopico/tinycore-redpill/raw/main/html/index.sh"
#extensionrepofile="https://github.com/pocopico/rp-ext/raw/main/redpill/rpext-index.json"
#extensionfile="rpext-index.json"
extensionrepofile="https://github.com/pocopico/tcrp-addons/raw/main/addons.json"
extensionfile="addons.json"
TOOLS="bspatch bzImage-to-vmlinux.sh calc_run_size.sh crc32 dtc kexec ramdisk-patch.sh vmlinux-to-bzImage.sh xxd zimage-patch.sh kpatch zImage_template.gz grub-editenv"
SCRIPTVERSION="0.10.2"

#. ${HOMEPATH}/include/config.sh
############################################

function versionhistory() {

  cat <<EOF
<h3> TCRP HTML, Version History : </h3>
<br> 0.10.0, Initial release, most models tested and booted.
<br> 0.10.1, Added file download functions to the web interface, fixed some bugs.
<br> 0.10.2, Fixed some bugs, added more models.
<br>
<br>
<br>

EOF

  latestscript

}

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
    <link href="assets/css/tcrp.css" rel="stylesheet">
    

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
function checkmachine() {

  if grep -q ^flags.*\ hypervisor\  /proc/cpuinfo; then
    MACHINE="VIRTUAL"
    HYPERVISOR=$(dmesg | grep -i "Hypervisor detected" | awk '{print $5}')
    echo "Machine is $MACHINE Hypervisor=$HYPERVISOR" | tee -a $BUILDLOG >/dev/null
  fi

}

function usbidentify() {

  checkmachine

  if [ "$MACHINE" = "VIRTUAL" ]; then
    vendorid="0x46f4"
    productid="0x0001"
    echo "Running on $HYPERVISOR, setting USB VID and PID,to $productid:$vendorid" | tee -a $BUILDLOG >/dev/null
    return
  fi

  loaderdisk=$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)

  lsusb -v 2>&1 | grep -B 33 -A 1 SCSI >/tmp/lsusb.out

  usblist=$(grep -B 33 -A 1 SCSI /tmp/lsusb.out)
  vendorid=$(grep -B 33 -A 1 SCSI /tmp/lsusb.out | grep -i idVendor | awk '{print $2}')
  productid=$(grep -B 33 -A 1 SCSI /tmp/lsusb.out | grep -i idProduct | awk '{print $2}')

  if [ $(echo $vendorid | wc -w) -gt 1 ]; then
    echo "Found more than one USB disk devices, please select which one is your loader on" | tee -a $BUILDLOG >/dev/null
    usbvendor=$(for item in $vendorid; do grep $item /tmp/lsusb.out | awk '{print $3}'; done)
    select usbdev in $usbvendor; do
      vendorid=$(grep -B 10 -A 10 $usbdev /tmp/lsusb.out | grep idVendor | grep $usbdev | awk '{print $2}')
      productid=$(grep -B 10 -A 10 $usbdev /tmp/lsusb.out | grep -A 1 idVendor | grep idProduct | awk '{print $2}')
      echo "Selected Device : $usbdev , with VendorID: $vendorid and ProductID: $productid" | tee -a $BUILDLOG >/dev/null
      break
    done
  else
    usbdevice="$(grep iManufacturer /tmp/lsusb.out | awk '{print $3}') $(grep iProduct /tmp/lsusb.out | awk '{print $3}') SerialNumber: $(grep iSerial /tmp/lsusb.out | awk '{print $3}')"
  fi

  if [ -n "$usbdevice" ] && [ -n "$vendorid" ] && [ -n "$productid" ]; then
    echo "Found $usbdevice" | tee -a $BUILDLOG >/dev/null
    echo "Vendor ID : $vendorid Product ID : $productid" | tee -a $BUILDLOG >/dev/null
  else
    echo "Sorry, no usb disk could be identified" | tee -a $BUILDLOG >/dev/null
    rm /tmp/lsusb.out
  fi
}

function staticip() {

  ipset=$(cat $USERCONFIGFILE | jq -r -e ' .ipsettings .ipset')
  ipaddr=$(cat $USERCONFIGFILE | jq -r -e ' .ipsettings .ipaddr')
  ipgw=$(cat $USERCONFIGFILE | jq -r -e ' .ipsettings .ipgw')
  ipdns=$(cat $USERCONFIGFILE | jq -r -e ' .ipsettings .ipdns')
  ipproxy=$(cat $USERCONFIGFILE | jq -r -e ' .ipsettings .ipproxy')

  cat <<EOF
   <div class="staticip">
      <div class="title-bar">
        <h3>Static IP Form</h3>  
     </div>
   <div class="content">

<form id="staticip" action="/${THISURL}?action=staticipset"  class="form-horizontal" align="left" method="POST">
  <div class="control-group">
  <label class="control-label" for="ipset">IP Setting</label>
  <div class="controls">
  <input id="ipset" name="ipset" value="$ipset" placeholder='static/dhcp' required />
   </div>
  </div>
  <div class="control-group">
  <label class="control-label" for="ipaddr">IP Address</label>
  <div class="controls">
  <input id="ipaddr" name="ipaddr" value="$ipaddr" placeholder='xxx.xxx.xxx.xxx'  required pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}$"  />
   </div>
  </div>
  <div class="control-group">
  <label class="control-label" for="ipgw">Gateway</label>
  <div class="controls">
  <input id="ipgw" name="ipgw" value="$ipgw" placeholder='xxx.xxx.xxx.xxx' required pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}$" />
   </div>
  </div>
  <div class="control-group">
  <label  class="control-label" for="ipdns">DNS</label>
  <div class="controls">
  <input id="ipdns" name="ipdns" value="$ipdns" placeholder='xxx.xxx.xxx.xxx' requrequired pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}$"ired />
   </div>
  </div>
    <div class="control-group">
  <label  class="control-label" for="ipproxy">HTTP proxy</label>
  <div class="controls">
  <input id="ipproxy" name="ipproxy" value="$ipproxy" placeholder='xxx.xxx.xxx.xxx' pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}$" />
   </div>
  </div>
<br><br><button id="staticipset" class="btn btn-lg btn-success btn-left">Save Settings</button>
</form>

     </div>
    </div>

EOF

}

function staticipset() {

  echo "$POST"

  updateuserconfigfield "ipsettings" "ipset" "$ipset"
  updateuserconfigfield "ipsettings" "ipaddr" "$ipaddr"
  updateuserconfigfield "ipsettings" "ipgw" "$ipgw"
  updateuserconfigfield "ipsettings" "ipdns" "$ipdns"
  updateuserconfigfield "ipsettings" "ipproxy" "$ipproxy"

}

function mountshare() {

  cat <<EOF
   <div class="mountshare">
      <div class="title-bar">
        <h3>Mount Share</h3>  
     </div>
   <div class="content">

<form id="mountshare" action="/${THISURL}?action=mountshare&share=$share&mountpoint=$mountpoint&cifsuser=$cifsuser&cifspass=$cifspass"  class="form-horizontal" align="left" method="POST">
  <div class="control-group">
  <label class="control-label" for="share">Share</label>
  <div class="controls">
  <input id="share" name="share" value="$share" placeholder='Share url e.g //192.168.1.100/tcrpshare' required />
   </div>
  </div>
  <div class="control-group">
  <label class="control-label" for="mountpoint">Mount Point</label>
  <div class="controls">
  <input id="mountpoint" name="mountpoint" value="$mountpoint" placeholder='/home/tc/mountpoint'  required  />
   </div>
  </div>
  <div class="control-group">
  <label class="control-label" for="cifsuser">User Name</label>
  <div class="controls">
  <input id="cifsuser" name="cifsuser" value="$cifsuser" placeholder='usename'  required  />
   </div>
  </div>
<div class="control-group">
  <label class="control-label" for="cifspass">Password</label>
  <div class="controls">
  <input id="cifspass" name="cifspass" value="$cifspass" placeholder='password'  required  />
   </div>
  </div>
EOF

  if [ ! -z $share ] && [ ! -z $mountpoint ] && [ ! -z $cifsuser ] && [ ! -z $cifspass ]; then
    mkdir -p $mountpoint
    echo -e "username=$cifsuser\npassword=$cifspass" >/home/tc/credentials
    chmod 600 /home/tc/credentials
    sudo /usr/local/sbin/mount.cifs "$share" "$mountpoint" -o credentials=/home/tc/credentials --verbose
    if [ $(mount | grep "$mountpoint" | wc -l) -gt 0 ]; then
      echo "<button id='mounted' class='btn btn-lg btn-success btn-left'>mounted</button>"
    else
      echo "<button id='mounted' class='btn btn-lg btn-danger btn-left'>Not mounted</button>"
    fi
  else
    echo ""
  fi

  cat <<EOF
  
<button id="mountthisshare" class="btn btn-lg btn-success btn-left">Mountshare</button>
</form>
     </div>
    </div>

EOF

  rm -rf /home/tc/credentials

}

function filemanagement() {

  getvars

  SYNOMODEL="$(echo $MODEL | sed -s 's/+/p/g' | tr '[:upper:]' '[:lower:]')"
  REVISION="$(echo "${VERSION}" | awk -F- '{print $2}')"
  patfile="${SYNOMODEL}_${REVISION}.pat"
  unencpatfile="${SYNOMODEL}_${REVISION}.pat-unenc"
  cat <<EOF
   <div class="filemanagement">
      <div class="title-bar">
        <h3>Files Download</h3>  
     </div>
<table class="table table-dark">
<thead><tr><th title="Field #1">Filename</th>
<th title="Field #2">Description</th>
<th title="Field #3">Link</th>
</tr></thead>
<tbody><tr>
EOF

  testarchive /tmp/$patfile >/dev/null 2>&1

  if [ "$isencrypted" == "yes" ]; then
    echo "    <td>Original downloaded PAT for $MODEL version $VERSION</td>"
    echo "    <td>Use that for the installation</td>"
    echo "    <td><a href=/assets/$patfile>$patfile</a></td>"
    echo "    </tr>"

  fi

  cat <<EOF
    <td>Unencrypted PAT file for $MODEL version $VERSION</td>
    <td>Keep that as a backup</td>
    <td><a href=/assets/$unencpatfile>$unencpatfile</a></td>
    </tr>
    <td>User Config file for $MODEL version $VERSION</td>
    <td>Keep that as a backup</td>
    <td><a href=/assets/user_config.json>user_config.json</a></td>
    </tr>

</tr></tbody></table>

      </div>
    
EOF

}

function selectmodel() {

  cat <<EOF
<form id="myform" method=POST action="/${THISURL}?action=build">
<select id="mymodel" name="mymodel">
EOF
  echo "<option value=\"'Please Select Model\">Select Model</option>"
  #for model in `getPlatforms`
  for model in $(ls ${CONFIGFILES} | grep -v comm | sed -e 's/\///'); do
    echo "<option value=\"'$model\">$model</option>"
  done
  cat <<EOF
 </select>
</form>
<div id="output"></div>
EOF

}

function selectversion() {

  getvars

  cat <<EOF
<form id="myversion" method=POST action="/${THISURL}?action=build&mymodel=$MODEL&myversion=$VERSION">
<label for="mymodel">Model</label>
<input id="mymodel" name="mymodel" value="$MODEL" required readonly/>
<label for="myversion">Version</label>
<select id="myversion" name="myversion">
EOF
  echo "<option value=\"'Please Select OS Version\">Select version</option>"
  for version in $(ls ${CONFIGFILES}/$MODEL/ | grep -v comm | sed -e 's/\///'); do
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

function backuploader() {

  getvars

  [ -z "$1" ] && echo "Backing up loader and making current home dir persistent" || status "setstatus" "backuploader" "warn" "Backing up loader and making current home dir persistent"

  HOMESIZE="$(du -sk . /home/tc/)"
  TCRPFREESPACE="$(df -k | grep $tcrppart | awk '{print $4}')"
  REMAINSPACE="$($TCRPFREESPACE-$HOMESIZE)"

  if [ $remainspace -le 150000 ]; then
    [ -z "$1" ] && wecho "Not enough space to backup" || status "backuploader" "warn" "Not enough space to backup"

  else
    [ -z "$1" ] && wecho "There is enough space to backup" || status "setstatus" "backuploader" "true" "There is enough space to backup"
    [ -z "$1" ] && echo y | backup >/dev/null
    [ -z "$1" ] && wecho "Backup File Date : $(ls -l /mnt/$tcrppart/mydata.tgz | awk '{print $6 " " $7 " " $8}')" || status "setstatus" "backuploader" "true" "Backup File Date : $(ls -l /mnt/$tcrppart/mydata.tgz | awk '{print $6 " " $7 " " $8}')"
    [ -z "$1" ] && wecho "Backup File size is : $(ls -lh /mnt/$tcrppart/mydata.tgz | awk '{print $5}')" || status "setstatus" "backuploader" "true" "Backup File size is : $(ls -lh /mnt/$tcrppart/mydata.tgz | awk '{print $5}')"
  fi

}

function pagebody() {
  cat <<EOF

    <div class="navbar navbar-inverse bg-dark navbar-fixed-top">
      <div class="navbar-inner">
        <div class="container">
          <button type="button" class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
             <span class="icon-bar"></span>
          </button>
          <a class="brand" href="${THISURL}?action=none">TinyCore RedPill</a>
         <div class="nav-collapse collapse">
            <ul class="nav">
              <li><a href="/${THISURL}?action=build">Build</a></li>
              <li class="nav-item dropdown">
              <a class="nav-link dropdown-toggle" href="#" id="navbarDropdownMenuLink" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
              Additional Actions
              </a>
              <ul class="dropdown-menu">
                <li><a class=" dropdown-item" href="${THISURL}?action=filemanagement">Down/Upload Files</a></li>
                <li><a class=" dropdown-item" href="${THISURL}?action=backuploader">Backup Loader</a></li>
                <li><a class=" dropdown-item" href="${THISURL}?action=fullupgrade">Full upgrade loader</a></li>
                <li><a class=" dropdown-item" href="${THISURL}?action=cleanloader">Clean Loader </a></li>
                <li><a class=" dropdown-item" href="${THISURL}?action=listplatforms">List Platforms</a><li>
                <li><a class=" dropdown-item" href="${THISURL}?action=extensions">Extension Management</a><li>
                <li><a class=" dropdown-item" href="${THISURL}?action=staticip">Static IP Setting</a><li>
                <li><a class=" dropdown-item" href="${THISURL}?action=mountshare">Mount share</a><li>
                <li><a class=" dropdown-item" href="${THISURL}?action=buildstatus">Last build status</a><li>
                <hr class="dropdown-divider">
                <li><a class="dropdown-item" href="${THISURL}?action=resetmodel" onclick="return confirm('About to reset the model are you sure?, this will permanently remove model info from /home/tc/user_config.json')" data-toggle="confirmation" data-title="Reset Model ?">Reset Model</a></li>
                <hr class="dropdown-divider">
                <li><a class="dropdown-item" href="${THISURL}?action=sysreboot" onclick="return confirm('About to reboot tinycore are you sure?')" data-toggle="confirmation" data-title="Reboot Tinycore ?">Reboot Tinycore</a></li>
              </ul>
              </li>
              <li><a href="https://github.com/pocopico/tinycore-redpill">Tinycore Redpill Repo</a></li>
              <li><a href="https://xpenology.com/forum/topic/53817-redpill-tinycore-loader/">Contact</a></li>
              <li><a href="${THISURL}?action=versionhistory">Version ${SCRIPTVERSION}</a></li>           
            </ul>
             
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>
    <div class="container">
EOF

  [ ! -z "$MODEL" ] && [ ! -z "$VERSION" ] && breadcrumb

}

function pagefooter() {
  cat <<EOF
    </div> <!-- /container -->

    <!-- Le javascript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/xcash/bootstrap-autocomplete@v2.3.7/dist/latest/bootstrap-autocomplete.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.9.1/chart.min.js"></script>



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
    <script src="assets/js/bootstrap-confirmation.js"></script>
    
<script>

\$(document).ready(function () {
  console.log("document loaded");
 
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
        console.log("form myform changed");
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
             console.log("form myversion changed");
       return false; // cancel original event to prevent form submitting
   });
  
  \$('#addextbutton').click(function(){

         \$.ajax({
          data: \$(this).serialize(), // get the form data
           data:  { "exturl" : \$('#extensionlist').val(), "action" : "extadd", "platform" : \$('#myplatform').val()},
           type: 'POST',
           url: "/actions.sh?action=extadd&ext=" + \$('#extensionlist').val() + "&url=\$exturl&platform=\$MODEL", // the file to call
             success: function(data) {
             console.log("Button addextbutton pressed loading : \${location.href}  " + \$('#extensionlist').val()) ;
          
               \$("extensionmanagement").text(data);
               location.reload();
             }
         });
      
  });
  \$('#remextbutton').click(function(){

         \$.ajax({
          data: \$(this).serialize(), // get the form data
          // POST DATA IS SET BELOW 
           data:  { "exturl" : \$('#extensionpayloadlist').val(), "action" : "extrem",  "platform" : \$('#myplatform').val() },
           type: 'POST',
           url: "/actions.sh?action=extrem&ext=" + \$('#extensionlist').val() + "&url=\$exturl", // the file to call
             success: function(data) {
             console.log("Button remextbutton pressed removing : \${location.href} " + \$('#extensionlist').val()) ;
                 //alert(data);
               \$("extensionmanagement").text(data);
               location.reload();
             }
         });
      
      });

      \$('#manualextbutton').click(function(){

         \$.ajax({
          data: \$(this).serialize(), // get the form data
          // POST DATA IS SET BELOW 
           data:  { "exturl" : \$('#manualexturl').val(), "action" : "manualextadd", "platform" : \$('#myplatform').val() },
           type: 'POST',         
           url: "/actions.sh?action=manualextadd&ext=" + \$('#manualexturl').val() + "&url=\$exturl&platform=\$mymodel", // the file to call
             success: function(data) {
             console.log("Button manualextbutton pressed adding : \${location.href} " + \$('#manualexturl').val()) ;
                 //alert(data);
               \$("extensionmanagement").text(data);
               location.reload();
             }
         });
      
      }); 

      \$('#autoextbutton').click(function(){

         \$.ajax({
          data: \$(this).serialize(), // get the form data
           data:  { "action" : "autoaddexts"},
           type: 'POST',
           url: "/index.sh?action=autoaddexts", // the file to call
             success: function(data) {    
              console.log("Button autoaddextbutton pressed");
               \$("extensionmanagement").text(data);
               location.reload();
             }
         });
      
      });

  \$('#redpillmakebutton').click(function(){

         \$.ajax({
          data: \$(this).serialize(), // get the form data
           data:  { "action" : "redpillmake"},
           type: 'POST',
           url: "/index.sh?action=redpillmake", // the file to call
             success: function(data) {    
              console.log("Button redpillmake pressed");
               \$("buildform").text(data);
               location.reload();
             }
         });
      
      });

  \$('#realmac').click(function(){

         \$.ajax({
          data: \$(this).serialize(), // get the form data
           data:  { "action" : "realmac"},
           type: 'POST',
           url: "/index.sh?action=realmac", // the file to call
             success: function(data) {    
              console.log("Button realmac pressed");
               \$("buildform").text(data);
               location.reload();
             }
         });
      
      });
  
    \$('#staticipset').click(function(){

         \$.ajax({
          data: \$(this).serialize(), // get the form data
           data:  { "ipset" : \$('#ipset').val(),"ipaddr" : \$('#ipaddr').val(), "ipgw" : \$('#ipgw').val(), "ipdns" : \$('#ipdns').val(), "ipproxy" : \$('#ipproxy').val(),"action" : "staticipset"},
           type: 'POST',
           url: "/index.sh?action=staticipset", // the file to call
             success: function(data) {    
              console.log("Button realmac pressed");
               \$("staticipform").text(data);
               location.reload();
             }
         });
      
      });
   
     
        
    \$('#buildstatus').hide();

    loadstatus();

    setInterval("loadstatus();",1000);

if (window.location.search.indexOf('action=buildstatus') === -1) {
console.log("no build status action");
      \$('#buildlog').hide();
} else {
console.log("build status action");
      \$('#buildlog').show();
      \$('#buildstatus').show();
}

if (window.location.search.indexOf('action=build') === -1) {
console.log("no build action");
      \$('#buildlog').hide();
} else {
console.log("build action");
      \$('#buildlog').show();
      
}

if (window.location.search.indexOf('result=true') === -1) {
console.log("no build result page");
} else {
console.log("build result page");
      \$('#buildlog').show();
      \$('#buildstatus').show();
}


});

var buildlog = document.getElementById('buildlog');

function getLog() {
    \$.ajax({
        url: 'buildlog.txt',
        dataType: 'text',
        success: function(text) {
            \$("#buildlogtab").text(text);
            setTimeout(getLog, 1000); // refresh every 1 seconds
        }
    })
}

getLog();

    function loadstatus() {
           \$("#buildstatus").load("status.sh");
           //add more lines / divs 
         }

    function hidebuild() {
      \$('#buildform').hide();
      \$('#extmanagement').hide();
      \$('#buildstatus').show();
      \$('#buildlog').show();
    }

    function hidebuildlog() {
      \$('#buildlog').hide();
    }

 function togglemac(e) {
      let txt = e.innerText;
      e.innerText = txt == 'Real Mac' ? 'Gen Mac' : 'Real Mac';
      macaddress.value = txt == '$realmac' ? '$macaddress' : '$realmac';
       }

      
function onModelChange() {
  var x = document.getElementById("myModel").value;
  document.getElementById("model").innerHTML = "You selected: " + x;
}

\$('#redpillmake').tooltip({'trigger':'focus', 'title': 'Change the redpill make to development or production'});
\$('#macaddress').tooltip({'trigger':'focus', 'title': 'Change the mac address to what you like or leave the generated one'});
\$('#serial').tooltip({'trigger':'focus', 'title': 'Change the serial to what you like or leave the generated one'});
\$('#sataportmap').tooltip({'trigger':'focus', 'title': 'Thats a calculated value, if you dont know what that does leave that as is'});
\$('#diskidxmap').tooltip({'trigger':'focus', 'title': 'Thats a calculated value, if you dont know what that does leave that as is'});
\$('#staticboot').tooltip({'trigger':'focus', 'title': 'Set this to true if you have issues with booting TCRP Friend'});


</script>
EOF

  chartinit

  readlog

  cat <<EOF

  </body>
</html>
EOF

}

function sysreboot() {

  wecho "System is going for reboot" | tee -a $LOGFILE
  sync
  sync
  sync
  backuploader
  wecho "Rebooting" | tee -a $LOGFILE
  sleep 2 && /usr/bin/exitcheck.sh reboot | tee -a $LOGFILE

}

function breadcrumb() {

  echo "<div class=\"container\"><div class=\"row\"><div class=\"col-sm\">"
  echo "<nav aria-label=\"breadcrumb\">  <ol class=\"breadcrumb\">"

  [ ! -z "$MODEL" ] && echo "<li class=\"breadcrumb-item\"><a href=\"${THISURL}?action=resetmodel\">$MODEL\</a></li>"
  [ ! -z "$VERSION" ] && echo "<li class=\"breadcrumb-item\"><a href=\"index.sh?action=setversion\">$VERSION\</a></li>"
  echo "<li class=\"breadcrumb-item active\" aria-current=\"page\">Build</li>"

  echo "</ol></nav></div></div></div>"

}

function serialgen() {

  [ ! -z "$GATEWAY_INTERFACE" ] && shift 0 || shift 1

  #if [ "$1" = "DS3615xs" ] || [ "$1" = "DS3617xs" ] || [ "$1" = "DS916+" ] || [ "$1" = "DS918+" ] || [ "$1" = "DS920+" ] || [ "$1" = "DS3622xs+" ] || [ "$1" = "FS6400" ] || [ "$1" = "DVA3219" ] || [ "$1" = "DVA3221" ] || [ "$1" = "DS1621+" ] || [ "$1" = "DVA1622" ] || [ "$1" = "DS2422+" ] || [ "$1" = "RS4021xs+" ] || [ "$1" = "DS1522+" ] || [ "$1" = "DS923+" ] || [ "$1" = "SA6400" ]; then

  if [ -n $(generateSerial $1) ]; then

    serial="$(generateSerial $1)"
    mac="$(generateMacAddress $1)"

    echo "Serial Number for Model = $serial"
    echo "Mac Address for Model $1 = $mac "

    macaddress=$(echo $mac | sed -s 's/://g')

    updateuserconfigfield "extra_cmdline" "sn" "${serial}"
    updateuserconfigfield "extra_cmdline" "mac1" "${macaddress}"
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
  DS1019+)
    permanent="PDN"
    serialstart="1780 1790 1860 1980"
    ;;
  DS720+)
    permanent="SBR"
    serialstart="2030 2040 20C0 2150"
    ;;
  DS920+)
    permanent="SBR"
    serialstart="2030 2040 20C0 2150"
    ;;
  DS1520+)
    permanent="TRR"
    serialstart="2270"
    ;;
  DS3622xs+)
    permanent="SQR"
    serialstart="2030 2040 20C0 2150"
    ;;
  DS1621xs+)
    permanent="S7R"
    serialstart="2080"
    ;;
  DS923+)
    permanent="TQR"
    serialstart="2270"
    ;;
  DS1522+)
    permanent="TRR"
    serialstart="2270"
    ;;
  DS723+)
    permanent="TQR"
    serialstart="2270"
    ;;
  DS1621+)
    permanent="S7R"
    serialstart="2080"
    ;;
  DS2422+)
    permanent="S7R"
    serialstart="2080"
    ;;
  FS2500)
    permanent="PSN"
    serialstart="1960"
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
    permanent="UBR"
    serialstart="2030 2040 20C0 2150"
    ;;
  RS1221+)
    permanent="RWR"
    serialstart="20B0"
    ;;
  RS1619xs+)
    permanent="QPR"
    serialstart="1920"
    ;;
  RS3618xs)
    permanent="ODN"
    serialstart="1130 1230 1330 1430"
    ;;
  RS3413xs+)
    permanent="S7R"
    serialstart="2080"
    ;;
  RS3621xs+)
    permanent="SZR"
    serialstart="20A0"
    ;;
  RS4021xs+)
    permanent="T2R"
    serialstart="2250"
    ;;
  SA3400)
    permanent="RJR"
    serialstart="1920"
    ;;
  SA6400)
    permanent="TQR"
    serialstart="2270"
    ;;
  *)
    permanent=""
    serialstart=""
    ;;
  esac

}

function realmac() {

  getvars

  if [ "$macaddress" = "$realmac" ]; then
    updateuserconfigfield "extra_cmdline" "mac1" "$genmac"
  else
    updateuserconfigfield "extra_cmdline" "mac1" "$realmac"
  fi

}

function redpillmake() {

  getvars

  if [ "$redpillmake" = "prod" ]; then
    updateuserconfigfield "general" "redpillmake" "dev"
  elif [ "$redpillmake" = "dev" ]; then
    updateuserconfigfield "general" "redpillmake" "prod"
  fi

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
  if [ "$1" = "DS923+" ] || [ "$1" = "DS1522+" ] || [ "$1" = "RS4021xs+" ] || [ "$1" = "SA6400" ]; then
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
  DS1019+)
    serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
    ;;
  FS2500)
    serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
    ;;
  FS6400)
    serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
    ;;
  DS720+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS920+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS923+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS1522+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS723+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS1520+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS3622xs+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS1621xs+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS1621+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  DS2422+)
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
  RS1221+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  RS1619xs+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  RS3621xs+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  RS4021xs+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  RS3618xs)
    serialnum="$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(random)
    ;;
  RS3413xs+)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  SA3400)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  SA6400)
    serialnum=$(toupper "$(echo "$serialstart" | tr ' ' '\n' | sort -R | tail -1)$permanent"$(generateRandomLetter)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomValue)$(generateRandomLetter))
    ;;
  *)
    serialnum=""
    ;;
  esac

  echo $serialnum

}

function updateuserconfigfield() {

  block="$1"
  field="$2"
  value="$3"

  if [ "$(jq -re ".$block.$field" $USERCONFIGFILE)" != "$value" ]; then

    if [ -n "$1 " ] && [ -n "$2" ]; then
      jsonfile=$(jq ".$block+={\"$field\":\"$value\"}" $USERCONFIGFILE >update.tmp && mv -f update.tmp $USERCONFIGFILE)
      #echo $jsonfile | jq . >$USERCONFIGFILE
      echo "Updating field in $block , $field to $value" >>updateconfig.log
      verify="$(jq -re .${block}.${field} $USERCONFIGFILE)"
      echo "Verifying user config file for values $block, $field, $value -> $verify" >>updateconfig.log
    else
      echo "No values to update specified"
    fi
  else
    return
  fi
}

function status() {

  action="$1"
  stage="$2"
  status="$3"
  msg="$4"

  /home/tc/html/status.sh "$action" "$stage" "$status" "$msg"

}

function bringoverfriend() {

  echo "Adding my friend"
  status "setstatus" "frienddownload" "false" "Downloading my friend"

  [ ! -d /home/tc/friend ] && mkdir /home/tc/friend/ && cd /home/tc/friend
  URLS=$(curl --insecure -s https://api.github.com/repos/pocopico/tcrpfriend/releases/latest | jq -r ".assets[].browser_download_url")
  for file in $URLS; do curl --insecure --location --progress-bar "$file" -O; done

  if [ -f bzImage-friend ] && [ -f initrd-friend ] && [ -f chksum ]; then
    FRIENDVERSION="$(grep VERSION chksum | awk -F= '{print $2}')"
    BZIMAGESHA256="$(grep bzImage-friend chksum | awk '{print $1}')"
    INITRDSHA256="$(grep initrd-friend chksum | awk '{print $1}')"
    status "setstatus" "frienddownload" "false" "Checking TCRP checksum"
    [ "$(sha256sum bzImage-friend | awk '{print $1}')" == "$BZIMAGESHA256" ] && status "setstatus" "frienddownload" "false" "bzImage-friend checksum OK !" && echo "bzImage-friend checksum OK !" || echo "bzImage-friend checksum ERROR !" || exit 99
    [ "$(sha256sum initrd-friend | awk '{print $1}')" == "$INITRDSHA256" ] && status "setstatus" "frienddownload" "false" "initrd-friend checksum OK !" && echo "initrd-friend checksum OK !" || echo "initrd-friend checksum ERROR !" || exit 99
  else
    status "setstatus" "frienddownload" "fail" "Checksum of TCRP friend failed"
    echo "Could not find friend files, exiting" && exit 0
  fi

  echo "Copying friend to /mnt/$tcrppart"
  status "setstatus" "frienddownload" "false" "Copying friend to /mnt/$tcrppart"

  cp -f /home/tc/friend/bzImage-friend /mnt/$tcrppart && [ -f /mnt/$tcrppart/bzImage-friend ] && [ "$(sha256sum /mnt/$tcrppart/bzImage-friend | awk '{print $1}')" == "$BZIMAGESHA256" ] && echo "bzImage-friend Copied succesfully" && status "setstatus" "frienddownload" "true" "bzImage-friend Copied succesfully to /mnt/$tcrppart"
  cp -f /home/tc/friend/initrd-friend /mnt/$tcrppart && [ -f /mnt/$tcrppart/initrd-friend ] && [ "$(sha256sum /mnt/$tcrppart/initrd-friend | awk '{print $1}')" == "$INITRDSHA256" ] && echo "initrrd-friend Copied succesfully" && status "setstatus" "frienddownload" "true" "initrrd-friend Copied succesfully to /mnt/$tcrppart"
  status "setstatus" "frienddownload" "true" "TCRP friend copied to /mnt/$tcrppart"

}

function buildform() {

  getvars
  satamap

  updateuserconfigfield "general" "model" "$MODEL"
  updateuserconfigfield "general" "version" "$VERSION"

  if [ -z "$serial" ] || [ -z "$macaddress" ]; then
    serialgen "$MODEL" | awk -F= '{print $2}' | sed -e 'N;s/\n/ /' | read serial macaddress
    serialgen "$MODEL" >/dev/null
    updateuserconfigfield "extra_cmdline" "sn" "$serial"
    updateuserconfigfield "extra_cmdline" "mac1" "$macaddress"

  fi

  usbidentify
  updateuserconfigfield "extra_cmdline" "pid" "$productid"
  updateuserconfigfield "extra_cmdline" "vid" "$vendorid"

  updateuserconfigfield "extra_cmdline" "SataPortMap" "$SATAPORTMAP"
  updateuserconfigfield "extra_cmdline" "DiskIdxMap" "$DISKIDXMAP"

  cat <<EOF
   <div class="buildform" id="buildform">
      <div class="title-bar">
        <h3>Build Form</h3>  

EOF

  checkcached

  if [ "$iscached" = "yes" ]; then
    cat <<EOF
<button type="button" id="patfilecached" class="btn btn-lg btn-success position-absolute top-0 start-0 translate-middle" data-toggle="popover" title="Found Cached" data-content="Patfile $patfile is cached">Patfile cached</button>
EOF
  else
    cat <<EOF
<button type="button" id="patfilecached" class="btn btn-lg btn-danger position-absolute top-0 start-0 translate-middle" data-toggle="popover" title="Found Cached" data-content="Patfile $patfile is cached">Patfile not cached</button>
EOF
  fi
  cat <<EOF
      </div>
   <div class="content">

<form id="mybuild" action="/${THISURL}?result=true"  class="form-horizontal" align="left" method="POST">
  <div class="control-group">
  <label class="control-label" for="mymodel">Model</label>
  <div class="controls">
  <input id="mymodel" name="mymodel" value="$MODEL" required readonly/>
   </div>
  </div>
  <div class="control-group">
  <label class="control-label" for="myversion">Version</label>
  <div class="controls">
  <input id="myversion" name="myversion" value="$VERSION" required readonly />
   </div>
  </div>
  <div class="control-group">
  <label class="control-label" for="serial">Serial</label>
  <div class="controls">
  <input id="serial" name="serial" value="$serial" required />
   </div>
  </div>
  <div class="control-group">
  <label  class="control-label" for="macaddress">Macaddress</label>
  <div class="controls">
  <input id="macaddress" name="macaddress" value="$macaddress" required />
   </div>
  </div>
    <div class="control-group">
  <label  class="control-label" for="redpillmake">Redpill Make</label>
  <div class="controls">
  <input id="redpillmake" name="redpillmake" value="$redpillmake" required />
   </div>
  </div>
  <div class="control-group">
  <label  class="control-label" for="sataportmap">SataPortMap</label>
  <div class="controls">
  <input id="sataportmap" name="sataportmap" value="$SATAPORTMAP" required/>
   </div>
  </div>
    <div class="control-group">
  <label  class="control-label" for="diskidxmap">DiskIdxMap</label>
  <div class="controls">
  <input id="diskidxmap" name="diskidxmap" value="$DISKIDXMAP" required/>
   </div>
  </div>
    <div class="control-group">
  <label  class="control-label" for="staticboot">Static Boot</label>
  <div class="controls">
  <input id="staticboot" name="staticboot" value="false" required/>
   </div>
  </div>
<!--
  <div class="control-group">
  <label class="control-label"  class="form-check-label" for="addexts">Automatically add extensions</label>
  <div class="controls">
  <input class="form-check-input" type="checkbox" name="addexts" id="addexts" value="auto" checked>
   </div>
  </div>
  <div class="control-group">
  <label class="control-label"  class="form-check-label" for="withfriend">With Friend</label>
  <div class="controls">
  <input class="form-check-input" type="checkbox" name="withfriend" id="withfriend" value="withfriend" checked>
   </div>
  </div>
  
  <div class="control-group">
  <label class="control-label"  for="extracmdline">Extra Command Line Options (e.g SataPortMap, DiskIdxMap etc</label>
  <div class="controls">
  <textarea id="extracmdline" name="extracmdline" value=" "> </textarea>
   </div>
  </div>
  --> 

  <input id="action" class="hidden" name="action" value="build" hidden required />
  <input id="buildit" class="hidden" name="buildit" value="yes" hidden required />
<br>
  <button id="realmac"  name="realmac" onclick="toggle(this)" type="button" class="btn btn-lg btn-info">Real Mac</button>
  <button id="redpillmakebutton" name="redpillmakebutton" onclick="" type="button" class="btn btn-info btn-sm">Change Redpill Make</button>
  <br><br><button type="submit"  class="btn btn-lg btn-success btnright" id="toggle" onclick="return hidebuild()">Build</button>

</form>

     </div>
    </div>

EOF

  extmanagement

}

function satamap() {

  TEXT=""
  SATAPORTMAP=""
  DISKIDXMAP=""
  PCIPORTS=0
  NUMPORTS=0
  ZEROPORTS=""
  TOTALPORTS=0
  LOOPPORTS=0

  for PCI in $(lspci -d ::106 | awk '{print$1}'); do
    NAME=$(lspci -s "${PCI}" | sed "s/\ .*://")
    TEXT+="${NAME}/n Ports: "
    unset HOSTPORTS
    declare -A HOSTPORTS
    while read LINE; do
      ATAPORT="$(echo ${LINE} | grep -o 'ata[0-9]*')"
      PORT=$(echo ${ATAPORT} | sed 's/ata//')
      HOSTPORTS[${PORT}]=$(echo ${LINE} | grep -o 'host[0-9]*$')
    done < <(ls -l /sys/class/scsi_host | fgrep "${PCI}")
    while read PORT; do
      ls -l /sys/block | fgrep -q "${PCI}/ata${PORT}" && ATTACH=1 || ATTACH=0
      PCMD=$(cat /sys/class/scsi_host/${HOSTPORTS[${PORT}]}/ahci_port_cmd)
      [ "${PCMD}" = "0" ] && DUMMY=1 || DUMMY=0
      [ ${ATTACH} -eq 1 ] && TEXT+="ATTACH"
      [ ${DUMMY} -eq 1 ] && TEXT+="DUMMY"

      TEXT+="${PORT} "
      NUMPORTS=$((${NUMPORTS} + 1))
    done < <(echo ${!HOSTPORTS[@]} | tr ' ' '\n' | sort -n)
    TEXT+="\n"
  done

  for PCI in $(lspci -d ::106 | awk '{print$1}'); do
    MAP="$(echo -e "$TEXT" | grep -i "$PCI" | grep -o ATTACH | wc -w)"
    [ "$MAP" -ge 1 ] && ZEROPORTS+="$MAP" && [ "$MAP" -le 8 ] && let MAP=8 && let PCIPORTS=$(($PCIPORTS + 1))
    [ "$MAP" -eq 0 ] && ZEROPORTS+="$MAP" && let MAP=1 && let PCIPORTS=$(($PCIPORTS + 1))
    TOTALPORTS=$(($TOTALPORTS + $MAP))
    SATAPORTMAP+="$MAP"
  done

  for ((i = 0; i < ${#ZEROPORTS}; i++)); do
    if [ "${ZEROPORTS:$i:1}" -eq 0 ]; then
      DISKIDXMAP+="$(printf "%02X" $(($TOTALPORTS + 1)))"
    elif [ "${ZEROPORTS:$i:1}" -le 8 ] && [ "$LOOPPORTS" -eq 0 ]; then
      DISKIDXMAP+="$(printf "%02X" ${LOOPPORTS})"
      TOTALPORTS=$(($TOTALPORTS - $LOOPPORTS))
      LOOPPORTS=$(($LOOPPORTS + 8 + 1))
    else
      DISKIDXMAP+="$(printf "%02X" $(($LOOPPORTS)))"
      LOOPPORTS=$(($LOOPPORTS + 8))
    fi
  done

  #echo "SATAPORTMAP=${SATAPORTMAP}"
  #echo "DISKIDXMAP=${DISKIDXMAP}"

}

function checkcached() {

  patfile="$(find /mnt/$tcrppart/auxfiles/ | grep -i $OS_ID)"

  [ -z "$patfile" ] && patfile="$(find /home/tc/html/ | grep -i $OS_ID)"

  if [ ! -z "$patfile" ] && [ -f "$patfile" ]; then
    iscached="yes"
    echo "PATFILE for ${MODEL}_${VERSION} is CACHED as file ${patfile}" >>${BUILDLOG}
    status "setstatus" "iscached" "true" "Patfile $patfile is cached"
  else
    iscached="no"
    echo "PATFILE for ${MODEL}_${VERSION} is NOT CACHED" >>${BUILDLOG}
    status "setstatus" "iscached" "false" "Patfile not cached"
  fi

}

function getpost() {
  echo ""
}

function resetmodel() {

  getvars

  cp -f ${HOMEPATH}/include/user_config.json $USERCONFIGFILE
  rm -rf ${HOMEPATH}/payload
  selectmodel

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

function recho() {

  #printf "<div class=\"d-inline p-2 bg-primary text-white\">$@</div>"
  printf "<pre>$@</pre>"

}

function getvars() {

  ln -s /lib /lib64

  tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
  loaderdisk=$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)
  local_cache="/mnt/${tcrppart}/auxfiles"
  GETTIME=$(curl -v --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
  INTERNETDATE=$(date +"%d%m%Y" -d "$GETTIME")
  LOCALDATE=$(date +"%d%m%Y")

  OS_ID=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e ' .os .id')
  PAT_URL=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e ' .os .pat_url')
  PAT_SHA=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e ' .os .sha256')
  ZIMAGE_SHA=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e '.files .zlinux .sha256')
  RD_SHA=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e '.files .ramdisk .sha256')
  RAMDISK_PATCH=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e ' .patches .ramdisk')
  SYNOINFO_PATCH=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e ' .synoinfo')
  RAMDISK_COPY=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e ' .extra .ramdisk_copy')
  SYNOINFO_USER=$(cat $USERCONFIGFILE | jq -r -e ' .synoinfo')
  RD_COMPRESSED=$(cat ${CONFIGFILES}/$MODEL/$VERSION/config.json | jq -r -e ' .extra .compress_rd')
  productid=$(cat $USERCONFIGFILE | jq -r -e ' .extra_cmdline .pid')
  vendorid=$(cat $USERCONFIGFILE | jq -r -e ' .extra_cmdline .vid')

  FILENAME="${OS_ID}.pat"
  realmac=$(ifconfig eth0 | head -1 | awk '{print $NF}' | sed -s 's/://g')
  genmac="$(generateMacAddress $MODEL | sed -e "s/://g")"

  mount ${tcrppart}
  mount ${loaderdisk}1
  mount ${loaderdisk}2

  #wecho "tcrppart            :   $tcrppart    local_cache         :   $local_cache        INTERNETDATE        :   $INTERNETDATE     \  LOCALDATE           :   $LOCALDATE
  #OS_ID               :   $OS_ID              PAT_URL             :   $PAT_URL            PAT_SHA             :   $PAT_SHA          \
  #ZIMAGE_SHA          :   $ZIMAGE_SHA         RD_SHA              :   $RD_SHA             RAMDISK_PATCH       :   $RAMDISK_PATCH    \
  #SYNOINFO_PATCH      :   $SYNOINFO_PATCH     RAMDISK_COPY        :   $RAMDISK_COPY       SYNOINFO_USER       :   $SYNOINFO_USER    \
  #RD_COMPRESSED       :   $RD_COMPRESSED      redpillextension    :   $redpillextension   FILENAME            :   $FILENAME         "

  [ -z "$MODEL" ] && MODEL="$(jq -r -e '.general .model' $USERCONFIGFILE)"
  [ -z "$VERSION" ] && VERSION="$(jq -r -e '.general .version' $USERCONFIGFILE)"
  [ -z "$serial" ] && serial="$(jq -r -e '.extra_cmdline .sn' $USERCONFIGFILE)"
  [ -z "$macaddress" ] && macaddress="$(jq -r -e '.extra_cmdline .mac1' $USERCONFIGFILE)"
  [ -z "$redpillmake" ] && redpillmake="$(jq -r -e ' .general .redpillmake' $USERCONFIGFILE)"
}

function checkextractor() {

  if [ -d /mnt/${tcrppart}/auxfiles/patch-extractor ] && [ -f /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.nano ]; then
    extractorcached="yes"
  else
    extractorcached="no"
  fi

}

function downloadextractor() {

  status "setstatus" "patextraction" "warn" "Extractor not cached, downloading OLD PAT"

  mkdir -p ${PATCHEXTRACTOR}/

  cd ${PATCHEXTRACTOR}/

  curl --insecure --location https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3622xs%2B_42218.pat --output ${HOMEPATH}/oldpat.tar.gz
  #[ -f ${HOMEPATH}/oldpat.tar.gz ] && tar -C${temp_folder} -xf ${HOMEPATH}/oldpat.tar.gz rd.gz

  status "setstatus" "patextraction" "warn" "OLD PAT downloaded, extracting"

  tar xvf ../oldpat.tar.gz hda1.tgz
  tar xf hda1.tgz usr/lib
  tar xf hda1.tgz usr/syno/sbin

  mkdir -p ${PATCHEXTRACTOR}/lib/

  cp usr/lib/libicudata.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libicui18n.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libicuuc.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libjson.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_program_options.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_locale.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_filesystem.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_thread.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_coroutine.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_regex.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libapparmor.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libjson-c.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libsodium.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_context.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libsynocrypto.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libsynocredentials.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_iostreams.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libsynocore.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libicuio.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_chrono.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_date_time.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_system.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libsynocodesign.so.7* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libsynocredential.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libjson-glib-1.0.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libboost_serialization.so* ${PATCHEXTRACTOR}/lib
  cp usr/lib/libmsgpackc.so* ${PATCHEXTRACTOR}/lib

  cp -r usr/syno/sbin/synoarchive ${PATCHEXTRACTOR}/

  status "setstatus" "patextraction" "warn" "Extractor in place, removing unneeded temp files"

  sudo rm -rf usr
  sudo rm -rf ../oldpat.tar.gz
  sudo rm -rf hda1.tgz

  status "setstatus" "patextraction" "warn" "Patching extraction binaries"

  curl --silent --location "https://github.com/pocopico/tinycore-redpill/blob/main/tools/xxd?raw=true" --output xxd

  chmod +x xxd

  ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0100/' | ./xxd -r >synoarchive.nano
  ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0a00/' | ./xxd -r >synoarchive.smallpatch
  ./xxd synoarchive | sed -s 's/000039f0: 0300/000039f0: 0000/' | ./xxd -r >synoarchive.system

  chmod +x synoarchive.*

  status "setstatus" "patextraction" "warn" "Caching extractor for future use"

  [ ! -d /mnt/${tcrppart}/auxfiles/patch-extractor ] && mkdir -p /mnt/${tcrppart}/auxfiles/patch-extractor

  cp -rf ${PATCHEXTRACTOR}/lib /mnt/${tcrppart}/auxfiles/patch-extractor/
  cp -rf ${PATCHEXTRACTOR}/synoarchive.* /mnt/${tcrppart}/auxfiles/patch-extractor/

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

  mkdir -p temp && cd temp

  if [ -d /mnt/${tcrppart}/auxfiles/patch-extractor ] && [ -f /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.nano ]; then
    status "setstatus" "patextraction" "warn" "Extracting pat file : ${PATCHEXTRACTOR}/$patfile" && LD_LIBRARY_PATH=/mnt/${tcrppart}/auxfiles/patch-extractor/lib /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.nano -xvf ${PATCHEXTRACTOR}/$patfile
  else
    wecho "Extractor not found" && status "setstatus" "patextraction" "warn" "Extractor not found"
  fi
  ## Extract ramdisk

  flashfile=$(ls flashupdate*s2*)

  tar xvf $flashfile && tar xvf content.txz

  mkdir -p rd.temp
  cd rd.temp && unlzma -c ../rd.gz | cpio -idm
  etc/VERSION

}

function getstaticmodule() {

  #SYNOMODEL="$(echo $MODEL | sed -s 's/+/p/g' | tr '[:upper:]' '[:lower:]')_${REVISION}"
  SYNOMODEL="$(echo $OS_ID | sed -s 's/+/p/g' | tr '[:upper:]' '[:lower:]')"

  cd ${HOMEPATH}

  wecho "Removing any old redpill.ko modules"
  [ -f ${HOMEPATH}/redpill.ko ] && rm -f ${HOMEPATH}/redpill.ko

  extension=$(curl --insecure --silent --location "$extensionrepofile")

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

  if [ -f ${HOMEPATH}/redpill.ko ] && [ -n $(strings ${HOMEPATH}/redpill.ko | grep -i $MODEL) ]; then
    wecho "Copying redpill.ko module to ramdisk"
    cp ${HOMEPATH}/redpill.ko ${TEMPPAT}/rd.temp/usr/lib/modules/rp.ko
  else
    wecho "Module does not contain platorm information for ${MODEL}"
  fi

  [ -f ${TEMPPAT}/rd.temp/usr/lib/modules/rp.ko ] && wecho "Redpill module is in place"

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

  checkcached

  if [ "$iscached" = "yes" ]; then
    echo "Found cached PAT file $patfile"
    cp $patfile ./$FILENAME
    status "setstatus" "downloadingpat" "true" "Already cached"
    return
  fi

  if [ ! -f $FILENAME ]; then
    wecho "Downloading PAT file $FILENAME for MODEL=$MODEL, Version=$VERSION, SHA256=$PAT_SHA"
    status "setstatus" "downloadingpat" "false" "Downloading PAT file $FILENAME for MODEL=$MODEL, Version=$VERSION, SHA256=$PAT_SHA"
    curl --insecure --silent "$PAT_URL" --output "$FILENAME" | tee -a ${BUILDLOG}

    [ "$(sha256sum $FILENAME | awk '{print $1}')" = "$PAT_SHA" ] && status "setstatus" "downloadingpat" "true" "Downloaded PAT file $FILENAME succesfully" && wecho "File downloaded and matches expected sha256sum" || wecho "Error downloaded file is corrupted"
  else
    wecho "$(sha256sum $FILENAME | awk '{print $1}')" = "$PAT_SHA"
    wecho "File $FILENAME is already downloaded"
    status "setstatus" "downloadingpat" "true" "File $FILENAME is already downloaded"
    return
    if [ "$(sha256sum $FILENAME | awk '{print $1}')" = "$PAT_SHA" ]; then
      wecho "File downloaded and matches expected sha256sum"
      status "setstatus" "downloadingpat" "true" "File $FILENAME downloaded and matches expected sha256sum"
    else
      wecho "Error downloaded file is corrupted stopping process. Remove file $FILENAME and try again"
      #rm -f $FILENAME
      status "setstatus" "downloadingpat" "fail" "Error downloaded file is corrupted stopping process. Remove file $FILENAME and try again"
      exit 99
    fi
  fi

  if [ -f $FILENAME ] && [ ! -f ${tcrppart}/auxfiles/$filename ]; then
    if [ $(df -h /mnt/${tcrpart} | tail -1 | awk '{print ($4+0)}') -le 400 ]; then
      cp $filename ${tcrppart}/auxfiles/$filename
    else
      rm -f ${tcrppart}/auxfiles/*.pat
      cp $filename ${tcrppart}/auxfiles/$filename
    fi
  fi

}

function downloadtools() {

  wecho "Downloading tools"

  [ ! -d ${HOMEPATH}/tools ] && mkdir -p ${HOMEPATH}/tools
  cd ${HOMEPATH}/tools
  for FILE in $TOOLS; do
    [ ! -f ${HOMEPATH}/tools/$FILE ] && curl --silent --insecure --location "$TOOLSPATH/${FILE}" -O
    chmod +x $FILE
  done

  status "setstatus" "downloadtools" "true" "Tools downloaded"
  cd ${HOMEPATH}

}

function extractpat() {

  FILENAME="$1"
  mkdir -p $TEMPPAT

  if [ "$isencrypted" = "yes" ]; then
    checkextractor && [ "$extractorcached" = "yes" ] && wecho "Extractor Cached, proceeding..." && status "setstatus" "patextraction" "warn" "Extractor cached"
    wecho "Extracting encrypted PAT file $FILENAME"
    status "setstatus" "patextraction" "false" "Extracting encrypted PAT file $FILENAME"
    [ ! -d ${TEMPPAT} ] && mkdir -p ${TEMPPAT}

    LD_LIBRARY_PATH=/mnt/${tcrppart}/auxfiles/patch-extractor/lib /mnt/${tcrppart}/auxfiles/patch-extractor/synoarchive.system -C ${TEMPPAT} -xf $FILENAME
  else
    wecho "Extracting unencrypted PAT file $FILENAME to $TEMPPAT"
    status "setstatus" "patextraction" "false" "Extracting unencrypted PAT file $FILENAME to $TEMPPAT"
    tar xf $FILENAME -C ${TEMPPAT} && status "setstatus" "patextraction" "false" "File $FILENAME extracted to $TEMPPAT"
  fi

  [ ! -f ${TEMPPAT}/VERSION ] && echo "FAILED to extract" && status "setstatus" "patextraction" "false" "FAILED to extract" && exit 99
  [ -f ${TEMPPAT}/VERSION ] && . ${TEMPPAT}/VERSION && status "setstatus" "patextraction" "true" "Extracted PAT file, VERSION Found : ${major}.${minor}.${micro}_${buildnumber}" && wecho "Extracted PAT file, VERSION Found : ${major}.${minor}.${micro}_${buildnumber}"
  extractedzImagesha="$(sha256sum ${TEMPPAT}/zImage | awk '{print $1}')"
  extractedrdsha="$(sha256sum ${TEMPPAT}/rd.gz | awk '{print $1}')"
  wecho "zImage sha256sum : $extractedzImagesha" && updateuserconfigfield "general" "zimghash" "${extractedzImagesha}"
  wecho "rd sha256sum : $extractedrdsha" && updateuserconfigfield "general" "rdhash" "${extractedrdsha}"

}

function patchkernel() {

  wecho "Patching Kernel"
  status "setstatus" "kernelpatch" "false" "Patching kernel $TEMPPAT/zImage"
  ${HOMEPATH}/tools/bzImage-to-vmlinux.sh ${TEMPPAT}/zImage ${TEMPPAT}/vmlinux >log 2>&1 >/dev/null
  ${HOMEPATH}/tools/kpatch ${TEMPPAT}/vmlinux ${TEMPPAT}/vmlinux-mod >log 2>&1 >/dev/null
  ${HOMEPATH}/tools/vmlinux-to-bzImage.sh ${TEMPPAT}/vmlinux-mod ${TEMPPAT}/zImage-dsm >/dev/null

  [ -f ${TEMPPAT}/zImage-dsm ] && wecho "Kernel Patched, sha256sum : $(sha256sum ${TEMPPAT}/zImage-dsm)" && status "setstatus" "kernelpatch" "true" "Kernel Patched, sha256sum : $(sha256sum ${TEMPPAT}/zImage-dsm)"

}

function cachepat() {

  echo "Caching PAT file"
  status "setstatus" "cachingpat" "false" "Caching PAT file"
  cd ${TEMPPAT}
  rm -rf rd.temp && rm -rf vmlinux* && rm -rf zImage-dsm && rm -rf initrd-dsm && status "setstatus" "cachingpat" "false" "Removing temp files from ${TEMPPAT}"
  echo "Cached pat file :  /mnt/$tcrppart/auxfiles/${BUILDMODEL}_${BUILDVERSION}.pat"
  rm -rf /mnt/$tcrppart/auxfiles/*.pat && status "setstatus" "cachingpat" "true" "Creating tar file to: /mnt/$tcrppart/auxfiles/${BUILDMODEL}_${BUILDVERSION}.pat " && tar cfz /mnt/$tcrppart/auxfiles/${BUILDMODEL}_${BUILDVERSION}.pat * && status "setstatus" "cachingpat" "true" "Cached file to: /mnt/$tcrppart/auxfiles/${BUILDMODEL}_${BUILDVERSION}.pat " || echo "Failed to cache file" || status "setstatus" "cachingpat" "fail" "Failed to cache file"

}

function cleanbuild() {

  echo "Cleaning build directory"
  status "setstatus" "cleanbuild" "true" "Removing temp OLD pat" && rm -rf /home/tc/oldpat.tar.gz
  status "setstatus" "cleanbuild" "true" "Removing temp patch-extractor" && rm -rf /home/tc/patch-extractor
  status "setstatus" "cleanbuild" "true" "Removing /home/tc/payload" && rm -rf /home/tc/payload
  status "setstatus" "cleanbuild" "true" "Removing /home/tc/custom.gz" && rm -rf /home/tc/custom.gz
  status "setstatus" "cleanbuild" "true" "Removing /home/tc/customtemp" && rm -rf /home/tc/customtemp
  status "setstatus" "cleanbuild" "true" "Removing ${TEMPPAT}" && rm -rf ${TEMPPAT}
  status "setstatus" "cleanbuild" "true" "Removing ${HOMEPATH}/html/*.pat" && mv -f ${HOMEPATH}/html/*.pat /tmp/ && rm -rf ${HOMEPATH}/html/*.pat
  status "setstatus" "cleanbuild" "true" "Removing ${HOMEPATH}/friend" && rm -rf ${HOMEPATH}/friend

  status "setstatus" "cleanbuild" "true" "Build directory cleaned"

}

function createdownloadlinks() {

  ln -sf /tmp/${BUILDMODEL}_${BUILDVERSION}.pat ${HOMEPATH}/html/assets/${BUILDMODEL}_${BUILDVERSION}.pat
  ln -sf ${HOMEPATH}/user_config.json ${HOMEPATH}/html/assets/user_config.json
  ln -sf /mnt/$tcrppart/auxfiles/${BUILDMODEL}_${BUILDVERSION}.pat ${HOMEPATH}/html/assets/${BUILDMODEL}_${BUILDVERSION}.pat-unenc

}

function addextensions() {

  cd $HOMEPATH/

  status "setstatus" "extadd" "false" "Adding extensions"

  # extadd URL PLATFORM
  BUILDMODEL="$(echo $MODEL | tr '[:upper:]' '[:lower:]' | sed -e "s/+/p/g")"
  platform_selected="$(jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' $CUSTOMCONFIG | jq ".build_configs[] | select(.id==\"${BUILDMODEL}-${VERSION}\")")"
  EXTENSIONS="$(echo $platform_selected | jq -r -e '.add_extensions[]' | grep json | awk -F: '{print $1}' | sed -s 's/"//g')"
  EXTENSIONS_SOURCE_URL="$(echo $platform_selected | jq -r -e '.add_extensions[]' | grep json | awk '{print $2}' | sed -e 's/,//g' -e 's/"//g')"
  BUILDVERSION="$(echo $VERSION | awk -F- '{print $2}')"

  wecho "PLATFORM SELECTED : $platform_selected"
  wecho "EXTENSIONS_SOURCE_URL : $EXTENSIONS_SOURCE_URL"

  wecho "Adding extensions for ${BUILDMODEL}_${BUILDVERSION}"

  for EXT in $EXTENSIONS_SOURCE_URL; do
    wecho "Adding required extension $EXT for ${BUILDMODEL}_${BUILDVERSION}" && status "setstatus" "extadd" "warn" "Adding required extension $EXT for ${BUILDMODEL}_${BUILDVERSION}"
    wecho "extadd $EXT ${BUILDMODEL}_${BUILDVERSION}"

    $HOMEPATH/include/extmgr.sh extadd $EXT "${BUILDMODEL}_${BUILDVERSION}"

  done
  status "setstatus" "extadd" "false" "Auto detecting required extensions"
  $HOMEPATH/include/listmodules.sh "${BUILDMODEL}_${BUILDVERSION}"

  status "setstatus" "extadd" "false" "Processing extensions"
  wecho "Processing extensions"
  $HOMEPATH/include/extmgr.sh processexts "${BUILDMODEL}_${BUILDVERSION}"
  status "setstatus" "extadd" "true" "Completed extensions"

}

function patchramdisk() {

  addextensions

  status "setstatus" "ramdiskpatch" "false" "Patching ramdisk"
  temprd="${TEMPPAT}/rd.temp/"
  wecho "Patching RamDisk"
  wecho "Extracting ramdisk to $temprd"

  [ ! -d $temprd ] && mkdir -p $temprd && cd $temprd && xz -dc <"${TEMPPAT}/rd.gz" | cpio -idm >/dev/null 2>&1
  [ -f ${TEMPPAT}/rd.temp/VERSION ] && ${TEMPPAT}/rd.temp/VERSION
  wecho "Extracted ramdisk VERSION : ${major}.${minor}.${micro}_${buildnumber}"
  PATCHES="$(echo $RAMDISK_PATCH | jq . | sed -s 's/@@@COMMON@@@/\/home\/tc\/config\/_common/' | grep config | sed -s 's/"//g' | sed -s 's/,//g')"

  wecho "Patches to be applied : $PATCHES"

  cd $temprd
  for patch in $PATCHES; do
    wecho "Applying patch $patch in dir $PWD"
    patch -p1 <$patch
  done

  wecho "Applying model synoinfo patches"
  status "setstatus" "ramdiskpatch" "false" "Applying model syinfo patches"

  while IFS=":" read KEY VALUE; do
    echo "Key :$KEY Value: $VALUE"
    _set_conf_kv $KEY $VALUE $temprd/etc/synoinfo.conf
  done <<<$(echo $SYNOINFO_PATCH | jq . | grep ":" | sed -s 's/"//g' | sed -s 's/,//g')

  wecho "Applying user synoinfo settings"
  status "setstatus" "ramdiskpatch" "false" "Applying user synoinfo settings"

  while IFS=":" read KEY VALUE; do
    echo "Key :$KEY Value: $VALUE"
    _set_conf_kv $KEY $VALUE $temprd/etc/synoinfo.conf
  done <<<$(echo $SYNOINFO_USER | jq . | grep ":" | sed -s 's/"//g' | sed -s 's/,//g')

  wecho "Copying extra ramdisk files "
  status "setstatus" "ramdiskpatch" "false" "Copying extra ramdisk files"

  while IFS=":" read SRC DST; do
    echo "Source :$SRC Destination : $DST"
    cp -f $SRC $DST
    cmp -s $SRC $DST || echo "File $SRC differ to $DST" && echo "FILE : $SRC copied to : $DST succesfully"
  done <<<$(echo $RAMDISK_COPY | jq . | grep "COMMON" | sed -s 's/"//g' | sed -s 's/,//g' | sed -s 's/@@@COMMON@@@/\/home\/tc\/config\/_common/')

  #wecho "Adding precompiled redpill module"
  #getstaticmodule

  cd $HOMEPATH
  $HOMEPATH/include/extmgr.sh createcustominitfile "${BUILDMODEL}_${BUILDVERSION}"
  cd $temprd
  cp -rpf $HOMEPATH/customtemp/* .

  # Reassembly ramdisk
  wecho "Reassempling ramdisk"
  status "setstatus" "ramdiskpatch" "false" "Reassempling ramdisk"

  if [ "${RD_COMPRESSED}" == "true" ]; then
    (cd "${temprd}" && find . | cpio -o -H newc -R root:root | xz -9 --format=lzma >"${TEMPPAT}/initrd-dsm") >/dev/null 2>&1 >/dev/null
  else
    (cd "${temprd}" && find . | cpio -o -H newc -R root:root >"${TEMPPAT}/initrd-dsm") >/dev/null 2>&1
  fi
  [ -f ${TEMPPAT}/initrd-dsm ] && wecho "Patched ramdisk created $(ls -l ${TEMPPAT}/initrd-dsm)" && status "setstatus" "ramdiskcreation" "true" "Patched ramdisk created $(ls -l ${TEMPPAT}/initrd-dsm)"
  status "setstatus" "ramdiskpatch" "true" "Done patching ramdisk"

  wecho "Copying file to ${tcrppart}"

  status "setstatus" "copyfilestodisk" "false" "Copying all files to disk"
  status "setstatus" "copyfilestodisk" "false" "Copying  $HOMEPATH/custom.gz to /mnt/${tcrppart}/" && cp -f $HOMEPATH/custom.gz /mnt/${tcrppart}/ && status "setstatus" "copyfilestodisk" "false" "Copied $HOMEPATH/custom.gz to /mnt/${tcrppart}/"
  #status "setstatus" "copyfilestodisk" "false" "Copying  $HOMEPATH/custom.gz to /mnt/${loaderdisk}1/ " && cp -f $HOMEPATH/custom.gz /mnt/${loaderdisk}1/ && status "setstatus" "copyfilestodisk" "false" "Copied $HOMEPATH/custom.gz to /mnt/${loaderdisk}1/"
  status "setstatus" "copyfilestodisk" "false" "Copying  ${TEMPPAT}/zImage-dsm to /mnt/${tcrppart}/" && cp -f ${TEMPPAT}/zImage-dsm /mnt/${tcrppart}/ && status "setstatus" "copyfilestodisk" "false" "Copied ${TEMPPAT}/zImage-dsm to /mnt/${tcrppart}/"
  status "setstatus" "copyfilestodisk" "false" "Copying  ${TEMPPAT}/initrd-dsm to /mnt/${tcrppart}/" && cp -f ${TEMPPAT}/initrd-dsm /mnt/${tcrppart}/ && status "setstatus" "copyfilestodisk" "false" "Copied ${TEMPPAT}/initrd-dsm to /mnt/${tcrppart}/"
  status "setstatus" "copyfilestodisk" "true" "Copied all boot files to the loader disk"

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

  #window.open("index.sh&monitor");

  getvars

  wecho "Starting build"
  wecho "Building loader for $MODEL, $VERSION, with serial number : $serial and macaddress : $macaddress"
  wecho "Redpill Make $redpillmake, SataPortMap: $sataportmap, DiskIdxMap: $diskidxmap, StaticBoot: $staticboot"
  wecho "extracommands : $extracmdline"

  #wecho "Updating user_config with serial : $serial and macaddress : $macaddress"
  updateuserconfigfield "extra_cmdline" "sn" "$serial"
  updateuserconfigfield "extra_cmdline" "mac1" "$macaddress"
  # Update the redpillmake
  updateuserconfigfield "general" "redpillmake" "$redpillmake"

  rm -rf ${HOMEPATH}/temppat

  testarchive $FILENAME
  checkextractor
  checkcached

  [ "$isencrypted" = "yes" ] && [ "$extractorcached" = "no" ] && downloadextractor

  extractpat "$patfile"

  if [ "$extractedzImagesha" = "$ZIMAGE_SHA" ]; then
    wecho "Copying original zImage to partitions ${loaderdisk}1 and ${loaderdisk}2"
    cp -f ${TEMPPAT}/zImage /mnt/${loaderdisk}1/
    cp -f ${TEMPPAT}/zImage /mnt/${loaderdisk}2/
    wecho "zImage sha256sum matches expected sha256sum, patching kernel"
    patchkernel
  else
    wecho "zImage does not match sha256sum : $extractedzImagesha"
  fi

  if [ "$extractedrdsha" = "$RD_SHA" ]; then
    wecho "Copying original ramdisk to partitions ${loaderdisk}1 and ${loaderdisk}2"
    cp -f ${TEMPPAT}/rd.gz /mnt/${loaderdisk}1/
    cp -f ${TEMPPAT}/rd.gz /mnt/${loaderdisk}2/
    wecho "ramdisk sha256sum matches expected sha256sum, patching kernel"
    patchramdisk
  else
    wecho "rd.gz  does not match sha256sum : $extractedrdsha"
  fi

  [ -n "${extracmdline}" ] && wecho "Extra User built defined command line parameters ${extracmdline}"

  while IFS="=" read KEY VALUE; do
    #wecho "User cmdline Key :$KEY Value: $VALUE"
    #_set_conf_kv $KEY $VALUE $USERCONFIGFILE
    #wecho "Debug : ${KEY} : $(json_has_field '$USERCONFIGFILE' '.extra_cmdline.$KEY')"
    if [ ! -z $KEY ] && [ ! -z $VALUE ]; then
      /usr/local/bin/jq -e -r ".extra_cmdline.${KEY}|select(0)" "$USERCONFIGFILE" >/dev/null 2>&1 >/dev/null
      rtncode=$?
      if [ $rtncode -eq 0 ]; then
        #wecho "Field exists, updating"
        updateuserconfigfield "extra_cmdline" "${KEY}" "${VALUE}"
      else
        #wecho "Field does not exist, adding "
        updateuserconfigfield "extra_cmdline" "${KEY}" "${VALUE}"

      fi
    fi
  done <<<$(echo $extracmdline | sed -s 's/ /\n/g')

  #wecho "Clearing and testing $USERCONFIGFILE"
  json="$(cat $USERCONFIGFILE | sed -s 's/\\r//g' | jq .)" && echo -E "${json}" | jq . >$USERCONFIGFILE

  #updating user_config with build form data
  echo "Updating $USERCONFIGFILE with build form data SataPortMap: $sataportmap DiskIdxMap: $diskidxmap StaticBoot: $staticboot" | tee -a $LOGFILE
  updateuserconfigfield "extra_cmdline" "SataPortMap" "${sataportmap}"
  updateuserconfigfield "extra_cmdline" "DiskIdxMap" "${diskidxmap}"
  updateuserconfigfield "general" "staticboot" "${staticboot}"

  #wecho "Building CMD Line"

  USB_LINE=$(getcmdline ${CONFIGFILES}/$MODEL/$VERSION/config.json $USERCONFIGFILE 2>&1 | grep linux | head -1 | cut -c 16-999)
  SATA_LINE=$(getcmdline ${CONFIGFILES}/$MODEL/$VERSION/config.json $USERCONFIGFILE 2>&1 | grep linux | tail -1 | cut -c 16-999)

  updateuserconfigfield "general" "usb_line" "${USB_LINE}"
  updateuserconfigfield "general" "sata_line" "${SATA_LINE}"

  #wecho "Copying $USERCONFIGFILE to boot partition"
  cp -f $USERCONFIGFILE /mnt/${tcrppart}/
  [ "$(sha256sum $USERCONFIGFILE | awk '{print $1}')" = "$(sha256sum /mnt/${tcrppart}/user_config.json | awk '{print $1}')" ] && wecho "File copied succesfully" || wecho "User config file is corrupted "

  bringoverfriend

  generategrub

  cachepat

  checkloader

  cleanbuild

  createdownloadlinks

  backuploader silent

  setgrubentry

  echo "Finished building the loader. "
  status "setstatus" "finishloader" "true" "Finished building the loader at : $(date +"%A %b %Y Time: %H:%M:%S")"
  return

}

setgrubentry() {

  status "setstatus" "setgrubentry" "warn" "Setting next grub entry"
  echo "Setting next grub entry " | tee -a $LOGFILE

  default="$(grep menuentry /mnt/${loaderdisk}1/boot/grub/grub.cfg | awk -F\' '{print $2}' | grep -i Friend)"
  ISUSB="$(udevadm info --query property --name /dev/${loaderdisk} | grep -i DEVPATH | grep -i USB | wc -l)"

  if [ "$staticboot" = "true " ] && [ "$ISUSB" = "1" ]; then
    usbentry="$(grep menuentry /mnt/${loaderdisk}1/boot/grub/grub.cfg | awk -F\' '{print $2}' | grep -i USB)"
    status "setstatus" "setgrubentry" "true" "Setting next grub entry to static USB : $usbentry"
    echo "Setting next grub entry to static USB : $usbentry" | tee -a $LOGFILE
    sudo /usr/local/bin/grub-editenv /mnt/${loaderdisk}1/boot/grub/grubenv set saved_entry="$usbentry"
  elif [ "$staticboot" = "true " ] && [ "$ISUSB" = "0" ]; then
    sataentry="$(grep menuentry /mnt/${loaderdisk}1/boot/grub/grub.cfg | awk -F\' '{print $2}' | grep -i SATA)"
    status "setstatus" "setgrubentry" "true" "Setting next grub entry to static SATA : $sataentry"
    echo "Setting next grub entry to static SATA : $sataentry" | tee -a $LOGFILE
    sudo /usr/local/bin/grub-editenv /mnt/${loaderdisk}1/boot/grub/grubenv set saved_entry="$sataentry"
  else
    status "setstatus" "setgrubentry" "true" "Setting next grub entry to : $default"
    echo "Setting next grub entry to Friend : $default" | tee -a $LOGFILE
    sudo /usr/local/bin/grub-editenv /mnt/${loaderdisk}1/boot/grub/grubenv set saved_entry="$default"
  fi

  savedentry="$(sudo /usr/local/bin/grub-editenv /mnt/${loaderdisk}1/boot/grub/grubenv list | awk -F= '{print $2}')"
  status "setstatus" "setgrubentry" "true" "Grub entry has been set to : $savedentry"
  echo "Grub entry has been set to : $savedentry" | tee -a $LOGFILE

}

function generategrub() {

  cd ${HOMEPATH}/html

  getvars

  BUILDMODEL="$(echo $MODEL | tr '[:upper:]' '[:lower:]' | sed -e "s/+/p/g")"
  BUILDVERSION="$(echo $VERSION | awk -F- '{print $2}')"

  echo "Generating GRUB entries for model :${BUILDMODEL}_${BUILDVERSION}"
  status "setstatus" "gengrub" "false" "Generating GRUB entries for model :${BUILDMODEL}_${BUILDVERSION}"

  ${HOMEPATH}/include/grubmgr.sh generate "${BUILDMODEL}_${BUILDVERSION}" && [ -f grub.cfg ] && echo "Generated successfully" || echo "Failed to generate grub.cfg"
  ${HOMEPATH}/include/grubmgr.sh addentry usb && [ $(grep -i USB grub.cfg | wc -l) -gt 0 ] && echo "Added USB entry" || echo "Failed to add USB entry"
  ${HOMEPATH}/include/grubmgr.sh addentry sata && [ $(grep -i SATA grub.cfg | wc -l) -gt 0 ] && echo "Added SATA entry" || echo "Failed to add SATA entry"
  ${HOMEPATH}/include/grubmgr.sh addentry tcrp && [ $(grep -i "Tiny Core Image Build" grub.cfg | wc -l) -gt 0 ] && echo "Added TCRP entry" || echo "Failed to add SATA entry"
  ${HOMEPATH}/include/grubmgr.sh addentry tcrpfriend && [ $(grep -i "Tiny Core Friend" grub.cfg | wc -l) -gt 0 ] && echo "Added TCRP FRIEND entry" || echo "Failed to add SATA entry"

  cp /mnt/${loaderdisk}1/boot/grub/grub.cfg /mnt/${loaderdisk}1/boot/grub/grub.cfg.old
  cp -f grub.cfg /mnt/${loaderdisk}1/boot/grub/grub.cfg

  status "setstatus" "gengrub" "true" "Finished generating GRUB entries for model :${BUILDMODEL}_${BUILDVERSION}"

}

function chartinit() {

  tcrppart="$(mount | grep -i optional | grep cde | awk -F / '{print $3}' | uniq | cut -c 1-3)3"
  freemem=$(free | grep Mem | awk '{print $4/$2*100}')
  usedmem=$(free | grep Mem | awk '{print $3/$2*100}')
  cpuload=$(cat /proc/stat | grep cpu | tail -1 | awk '{print ($5*100)/($2+$3+$4+$5+$6+$7+$8+$9+$10)}' | awk '{print "CPU Usage: " 100-$1}')
  freehomespace=$(df -k /home/tc/ | grep root | awk '{print $4/$2*100}')
  usedhomespace=$(df -k /home/tc/ | grep root | awk '{print $3/$2*100}')
  freetcrpspace=$(df -k /mnt/$tcrppart | grep sd | awk '{print $4/$2*100}')
  usedtcrpspace=$(df -k /mnt/$tcrppart | grep sd | awk '{print $3/$2*100}')

  cat <<EOF
<script>

// chart colors
var colors = ['#007bff','#28a745','#333333','#c3e6cb','#dc3545','#6c757d'];
/* donut charts */
var donutOptions = {
  cutoutPercentage: 85, 
  legend: {position:'bottom', padding:5, labels: {pointStyle:'circle', usePointStyle:true}}
};


// Home 
var chDonutData1 = {
    labels: ['Home space % Free', 'Home space % Used'],
    datasets: [
      { backgroundColor: colors.slice(0,3), borderWidth: 0, data: [$freehomespace, $usedhomespace] }
      ]
      };

var chDonutData2 = {
    labels: ['TCRP space % Free', 'TCRP space % Used'],
    datasets: [
      { backgroundColor: colors.slice(0,3), borderWidth: 0, data: [$freetcrpspace, $usedtcrpspace] }
      ]
      };

var chDonutData3 = {
    labels: ['Mem % Free', 'Mem % Used'],
    datasets: [
      { backgroundColor: colors.slice(0,3), borderWidth: 0, data: [$freemem, $usedmem] }
      ]
      };


var chDonut1 = document.getElementById("chDonut1");
if (chDonut1) {
  new Chart(chDonut1, {
      type: 'doughnut',
      data: chDonutData1,
      options: donutOptions
  });
}

var chDonut2 = document.getElementById("chDonut2");
if (chDonut2) {
  new Chart(chDonut2, {
      type: 'doughnut',
      data: chDonutData2,
      options: donutOptions
  });
}


var chDonut3 = document.getElementById("chDonut3");
if (chDonut3) {
  new Chart(chDonut3, {
      type: 'doughnut',
      data: chDonutData3,
      options: donutOptions
  });
}


</script>

EOF

}

function loaderstatus() {

  #wecho "Current used Space in /home/tc is:$(du -sh /home/tc)"

  cat <<EOF
<div class="container"<div class="row">
<table class="table table-dark mx-auto w-auto">
  <thead>
    <tr>
      <th scope="col">Home Space</th>
      <th scope="col">TCRP Partition Space</th>
      <th scope="col">Memory</th>
   </tr>
  </thead>
  <tbody>
    <tr>
      <td><div class="col-sm ">
            <div class="card">
                <div class="card-body">
                    <canvas id="chDonut1" ></canvas>
                </div>
            </div>
     </div></td>
      <td>  <div class="col-sm ">
            <div class="card">
                <div class="card-body">
                    <canvas id="chDonut2"   ></canvas>
                </div>
            </div>
     </div></td>
      <td>  <div class="col-sm ">
            <div class="card">
                <div class="card-body">
                    <canvas id="chDonut3"  ></canvas>
                </div>
            </div>
     </div>
     </td>
      </tr>
  
  </tbody>
</table>
</div></div>
EOF

}

function listplatforms() {

  models="$(ls ${CONFIGFILES} | grep -v comm | sed -e 's/\///g')"
  echo "<h3>Available Platforms Hardware Information</h3>"
  cat <<EOF
<table class="table table-dark">
<thead><tr><th title="Field #1">Model</th>
<th title="Field #2">Series</th>
<th title="Field #3">CPU</th>
<th title="Field #4">Cores</th>
<th title="Field #5">Threads</th>
<th title="Field #6">Platform</th>
<th title="Field #7">RAM</th>
</tr></thead>
<tbody><tr>
EOF

  for model in $models; do
    echo "<td> $(jq -r -e ".[] | select(.Model | contains(\"$model\"))" ${HOMEPATH}/include/platforms.json | jq -r -e .Model) </td>"
    echo "<td> $(jq -r -e ".[] | select(.Model | contains(\"$model\"))" ${HOMEPATH}/include/platforms.json | jq -r -e .Series) </td>"
    echo "<td> $(jq -r -e ".[] | select(.Model | contains(\"$model\"))" ${HOMEPATH}/include/platforms.json | jq -r -e .CPU) </td>"
    echo "<td> $(jq -r -e ".[] | select(.Model | contains(\"$model\"))" ${HOMEPATH}/include/platforms.json | jq -r -e .Cores) </td>"
    echo "<td> $(jq -r -e ".[] | select(.Model | contains(\"$model\"))" ${HOMEPATH}/include/platforms.json | jq -r -e .Threads) </td>"
    echo "<td> $(jq -r -e ".[] | select(.Model | contains(\"$model\"))" ${HOMEPATH}/include/platforms.json | jq -r -e .Platform) </td>"
    echo "<td> $(jq -r -e ".[] | select(.Model | contains(\"$model\"))" ${HOMEPATH}/include/platforms.json | jq -r -e .RAM) </td>"
    echo "</tr>"
  done

  echo "</tr></tbody></table>"

}

function autoaddexts() {

  getvars

  wecho "Automatically detecting the required extensions"
  BUILDMODEL="$(echo $MODEL | tr '[:upper:]' '[:lower:]' | sed -e "s/+/p/g")"
  platform_selected="$(jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' $CUSTOMCONFIG | jq ".build_configs[] | select(.id==\"${BUILDMODEL}-${VERSION}\")")"
  EXTENSIONS="$(echo $platform_selected | jq -r -e '.add_extensions[]' | grep json | awk -F: '{print $1}' | sed -s 's/"//g')"
  EXTENSIONS_SOURCE_URL="$(echo $platform_selected | jq -r -e '.add_extensions[]' | grep json | awk '{print $2}' | sed -e 's/,//g' -e 's/"//g')"
  BUILDVERSION="$(echo $VERSION | awk -F- '{print $2}')"

  wecho "Autoadding, executing : ${HOMEPATH}/include/listmodules.sh for ${BUILDMODEL}_${BUILDVERSION}" | tee -a ${BUILDLOG}
  ${HOMEPATH}/include/listmodules.sh ${BUILDMODEL}_${BUILDVERSION} | tee -a ${BUILDLOG}

}

function extmanagement() {

  getvars

  cat <<EOF
   <div class="extmanagement" id="extmanagement">
      <div class="title-bar">
        <h3>Extension Management</h3>
        <!-- Add buttons for minimization, maximization, and closing the window -->
    </div>
         <div class="content">
EOF
  if [ -z "$MODEL" ] || [ -z "$VERSION" ]; then
    echo "<p>Model or Version is not selected or not found, please click build to select model first<p>"
    return
  fi

  BUILDMODEL="$(echo $MODEL | tr '[:upper:]' '[:lower:]' | sed -e "s/+/p/g")"
  platform_selected="$(jq -s '.[0].build_configs=(.[1].build_configs + .[0].build_configs | unique_by(.id)) | .[0]' $CUSTOMCONFIG | jq ".build_configs[] | select(.id==\"${BUILDMODEL}-${VERSION}\")")"
  EXTENSIONS="$(echo $platform_selected | jq -r -e '.add_extensions[]' | grep json | awk -F: '{print $1}' | sed -s 's/"//g')"
  EXTENSIONS_SOURCE_URL="$(echo $platform_selected | jq -r -e '.add_extensions[]' | grep json | awk '{print $2}' | sed -e 's/,//g' -e 's/"//g')"
  BUILDVERSION="$(echo $VERSION | awk -F- '{print $2}')"
  wecho "Please note that for MODEL ${BUILDMODEL}_${BUILDVERSION}, the following extensions are added automatically: $EXTENSIONS <br>"

  for exturl in $EXTENSIONS_SOURCE_URL; do

    if [ $(jq -re '.url' ${HOMEPATH}/payload/*/rpext* | grep -i $exturl | wc -l) -ge 1 ]; then
      echo "Extension $exturl already added, skipping" | tee -a ${BUILDLOG} >/dev/null
      continue
    else
      ${HOMEPATH}/include/extmgr.sh extadd $exturl ${BUILDMODEL}_${BUILDVERSION} | tee -a ${BUILDLOG} >/dev/null
    fi

  done

  #listplaforms

  extensionpayload="$(
    for ext in $(cat /home/tc/payload/extensions | uniq); do
      cat /home/tc/payload/$ext/*json | jq -r -e '. | .id,.url ' | paste -d " " - - | sort | uniq
    done
  )"
  [ ! -f $extensionfile ] && curl --insecure -sL $extensionrepofile -O
  extensionlist="$(cat $extensionfile | jq -r -e '. | .id,.url ' | paste -d " " - - | sort | uniq)"

  echo "<div id=\"extmanagement\">"
  echo "<input type=\"hidden\" id=\"myplatform\" name=\"myplatform\" value=\"${BUILDMODEL}_${BUILDVERSION}\">"
  echo "<select rows=\"10\" id=\"extensionlist\" name=\"extensionlist\" class=\"form-select\" size=\"3\" aria-label=\"size 3 select example\">"
  while IFS=" " read -r extension exturl; do
    tooltiptext="$(jq -r -e ". |  select(.id==\"$extension\") | .info.description " $extensionfile | uniq)"
    echo "<option value=\"$exturl\" data-toggle=\"tooltip\" title=\"$tooltiptext\" >$extension</option>"
  done < <(printf '%s\n' "$extensionlist")

  echo "</select>"

  echo "<button id=\"addextbutton\" name=\"addextbutton\" onclick=\"\" type=\"button\" class=\"btn btn-primary btn-sm\">Add extension</button></div>"

  echo "<select rows=\"10\" id=\"extensionpayloadlist\" name=\"extensionpayload\" class=\"form-select\" size=\"3\" aria-label=\"size 3 select example\">"
  while IFS=" " read -r extension exturl; do

    echo "<option value=\"$exturl\">$extension</option>"
  done < <(printf '%s\n' "$extensionpayload")

  echo "</select>"

  echo "<button id=\"remextbutton\" name=\"remextbutton\" onclick=\"\" type=\"button\" class=\"btn btn-danger btn-sm\">Remove extension</button></div>"
  echo "<input type=\"url\" class=\"form-control input-sm\" id=\"manualexturl\" placeholder=\"Extension URL to manualy add \">"
  echo "<button id=\"manualextbutton\" name=\"manualextbutton\" onclick=\"\" type=\"button\" class=\"btn btn-info btn-sm\">Manual add extensions</button>"
  echo "<button id=\"autoextbutton\" name=\"autoextbutton\" onclick=\"\" type=\"button\" class=\"btn btn-info btn-sm\">Auto add extensions</button>"

  echo "</div></div></div>"

}

checkloader() {

  echo "Checking loader consistency ..."
  status "setstatus" "checkloader" "false" "Checking loader consistency ..."
  status "setstatus" "checkloader" "false" "Checking menuentries ..."
  echo -n "Checking menuentries ..." && echo "$(grep menuentry /mnt/${loaderdisk}1/boot/grub/grub.cfg | wc -l) entries found" && status "setstatus" "checkloader" "false" "$(grep menuentry /mnt/${loaderdisk}1/boot/grub/grub.cfg | wc -l) entries found"
  echo "Checking boot files are in place..."
  status "setstatus" "checkloader" "false" "Checking boot files are in place..."

  for bootfile in bzImage-friend initrd-friend zImage-dsm initrd-dsm user_config.json custom.gz; do
    [ -f /mnt/${tcrppart}/$bootfile ] && echo "OK ! file /mnt/${tcrppart}/$bootfile, IN PLACE" && status "setstatus" "checkloader" "false" "OK ! file /mnt/${tcrppart}/$bootfile, IN PLACE" || echo "Error ! /mnt/${tcrppart}/$bootfile MISSING" || status "setstatus" "checkloader" "false" "Error ! /mnt/${tcrppart}/$bootfile MISSING"
  done

  status "setstatus" "checkloader" "false" "Checking user_config.json general block ..."
  echo -n "Checking user_config.json general block ..." && [ $(jq .general /mnt/${tcrppart}/user_config.json | wc -l) -ge 12 ] && echo "OK" && status "setstatus" "checkloader" "true" "Done, all seems OK"

}

function latestscript() {

  curl --insecure -L $SCRIPTREPO -o /tmp/index.sh
  chmod +x /tmp/index.sh

  curversion="$(grep "SCRIPTVERSION=" /home/tc/html/index.sh | head -1 | awk -F\" '{print $2}')"
  repoversion="$(grep "SCRIPTVERSION=" /tmp/index.sh | head -1 | awk -F\" '{print $2}')"
  reposha256sum="/tmp/index.sh | awk '{print $1'"
  cursha256sum="$(sha256sum /home/tc/html/index.sh | awk '{print $1}')"

  rm -f /tmp/index.sh
  if [ "$curversion" != "$repoversion" ] || [ "$reposha256sum" != "$cursha256sum" ] && [ $(($(echo $repoversion | sed -e 's/'.//')-$(echo $curversion| sed -e 's/'.//'))) -gt 0 ]; then
    wecho "Current version : $curversion, new version available $repoversion, please update"
    echo "<a href=\"${THISURL}?action=updatescript\" class=\"btn btn-primary btn-lg active\" role=\"button\" aria-pressed=\"true\">UPDATE</a>"
  fi

}

function updatescript() {

  curl --insecure -L $SCRIPTREPO -o /tmp/index.sh && chmod +x /tmp/index.sh
  repoversion="$(grep "SCRIPTVERSION=" /tmp/index.sh | head -1 | awk -F\" '{print $2}')"

  [ ! -n "$(/tmp/index.sh version)" ] && cp /tmp/index.sh /home/tc/html/index.sh && chmod +x /home/tc/html/index.sh && wecho "Script updated to version $repoversion" && exit 0
  [ -n "$(/tmp/index.sh version)" ] && wecho "Error updating script, please try again later" && exit 1
  rm -f /tmp/index.sh

}

function fullupgrade() {

  getvars

  cd $HOMEPATH

  backupdate="$(date +%Y-%b-%d-%H-%M)"

  echo "Performing a full TCRP upgrade"

  mkdir -p /mnt/$tcrppart/backup
  echo "Backuping up current files to /mnt/$tcrppart/backup/loaderbackup-${backupdate}.tgz"
  tar cfz /mnt/$tcrppart/backup/loaderbackup-${backupdate}.tgz /home/tc 2>&1 >/dev/null
  git --git-dir=/dev/null clone --depth=1 $rploadergit
  cd /home/tc/tinycore-redpill && sudo cp -frp * /home/tc && cd /home/tc
  rm -rf tinycore-redpill
  find /home/tc -type f -name "*.sh" -exec chmod +x {} \;
  find /home/tc/tools -type f -exec chmod +x {} \;

  backuploader

}

function buildstatus() {

  echo "<div id="buildstatus"></div><br>"

}

function readlog() {

  cat <<EOF
<div class="buildlog fixed-bottom pre-scrollable bg-dark" id="buildlog">
<h3>Build output log<button id="hideoutputlog" class="btn btn-lg btn-success btn-left" onclick="return hidebuildlog()">Hide build log</button></h3>
<pre id="buildlogtab"></pre>

</div>

EOF

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
  [ -z "$GATEWAY_INTERFACE" ] && [ "$1" = "version" ] && echo "$SCRIPTVERSION" || echo "This is meant to run under CGI or to include functions in other scripts"
  [ ! -z "$GATEWAY_INTERFACE" ] && [ "$1" = "version" ] && echo "$SCRIPTVERSION" && exit 0
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
    action="$(echo "${get[action]}" | sed -s "s/'//g")"
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
    staticboot="$(echo "${post[staticboot]}" | sed -s "s/'//g")"
    sataportmap="$(echo "${post[sataportmap]}" | sed -s "s/'//g")"
    diskidxmap="$(echo "${post[diskidxmap]}" | sed -s "s/'//g")"
    redpillmake="$(echo "${post[redpillmake]}" | sed -s "s/'//g")"
    if [ -z "$(echo ${post[action]} | sed -s "s/'//g")" ]; then
      action="$(echo "${get[action]}" | sed -s "s/'//g")"
    else
      action="$(echo "${post[action]}" | sed -s "s/'//g")"
    fi
    #action="$(echo "${post[action]}" | sed -s "s/'//g")"
    extracmdline="$(
      echo "${post[extracmdline]}" | sed -s "s/'//g" | sed -s 's/ /\n/g' | sed -s 's/%3D/=/g'
    )"
    buildit="$(echo "${post[buildit]}" | sed -s "s/'//g")"
    if [ "$action" == "extadd" ]; then
      exturl="$(echo "${post[exturl]}" | sed -s "s/'//g")"
    fi
    if [ "$action" == "staticipset" ]; then
      ipset="$(echo "${post[ipset]}" | sed -s "s/'//g")"
      ipaddr="$(echo "${post[ipaddr]}" | sed -s "s/'//g")"
      ipgw="$(echo "${post[ipgw]}" | sed -s "s/'//g")"
      ipdns="$(echo "${post[ipdns]}" | sed -s "s/'//g")"
      ipproxy="$(echo "${post[ipproxy]}" | sed -s "s/'//g")"
    fi
    if [ "$action" == "mountshare" ]; then
      share="$(echo "${post[share]}" | sed -s "s/'//g")"
      mountpoint="$(echo "${post[mountpoint]}" | sed -s "s/'//g")"
      cifsuser="$(echo "${post[cifsuser]}" | sed -s "s/'//g")"
      cifspass="$(echo "${post[cifspass]}" | sed -s "s/'//g")"
      enccifsuser="$(printf %s "${post[cifsuser]}" | jq -sRr @uri | sed -s "s/'//g")"
      enccifspass="$(printf %s "${post[cifspass]}" | jq -sRr @uri | sed -s "s/'//g")"
    fi

  fi

  #echo "POST STRING : $POST_STRING : Action = $action" | tee -a buildlog.log
  #echo "<br>REQUEST METHOD $REQUEST_METHOD , MODEL : $MODEL , VERSION : $VERSION"
  #echo "<br>Serial : $serial , MAC : $macaddress , Buildit : $buildit"
  #echo "<br>Build VARS : MODEL :$MODEL VERSION: $VERSION SN: $serial MAC: $macaddress BUILDIT: $buildit"
  #echo "<br>Build VARS : sataportmap :$sataportmap diskidxmap: $diskidxmap RepillMake: $redpillmake Static Boot: $staticboot "

  [ "$action" == "backuploader" ] && result=$(backuploader) && recho "$result" | tee -a ${BUILDLOG}
  [ "$action" == "listplatforms" ] && result=$(listplatforms) && wecho "$result" | tee -a buildlog.log
  [ "$action" == "cleanloader" ] && result=$(cleanbuild) && recho "$result" | tee -a ${BUILDLOG}
  [ "$action" == "extensions" ] && result=$(extmanagement) && wecho "$result" | tee -a ${BUILDLOG}
  [ "$action" == "extadd" ] && wecho "Extadd" && result=$($HOMEPATH/include/extmgr.sh extadd $exturl $MODEL) && wecho "$result" | tee -a ${BUILDLOG}
  [ "$action" == "setversion" ] && result=$(selectversion) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "resetmodel" ] && result=$(resetmodel) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "redpillmake" ] && result=$(redpillmake) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "staticip" ] && result=$(staticip) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "staticipset" ] && result=$(staticipset) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "realmac" ] && result=$(realmac) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "autoaddexts" ] && result=$(autoaddexts) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "generategrub" ] && result=$(generategrub $MODEL) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "bringoverfriend" ] && result=$(bringoverfriend) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "versionhistory" ] && result=$(versionhistory) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "mountshare" ] && result=$(mountshare) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "buildstatus" ] && result=$(buildstatus) && echo "$result" | tee -a ${BUILDLOG}
  [ "$action" == "updatescript" ] && result=$(updatescript) && recho "$result" | tee -a ${BUILDLOG}
  [ "$action" == "fullupgrade" ] && result=$(fullupgrade) && recho "$result" | tee -a ${BUILDLOG}
  [ "$action" == "sysreboot" ] && result=$(sysreboot) && recho "$result" | tee -a ${BUILDLOG}
  [ "$action" == "filemanagement" ] && result=$(filemanagement) && echo "$result" | tee -a ${BUILDLOG}

  [ "$action" == "none" ] && loaderstatus

  if [ "$action" == "build" ]; then

    echo "Clearing log file" >${BUILDLOG}

    getvars

    if [ $(jq . $USERCONFIGFILE | wc -l) -ge 38 ]; then
      echo "File $USERCONFIGFILE looks OK" | tee -a $BUILDLOG >/dev/null
    else
      wecho "Error both $USERCONFIGFILE file looks corrupted, select Additional Actions -> Reset model to recreate"
      pagefooter
      exit 99
    fi

    if [ ! -z "$MODEL" ] && [ ! -z "$VERSION" ] && [ ! -z "$serial" ] && [ ! -z "$macaddress" ] && [ ! -z "$buildit" ]; then

      echo "Building loader for model, $MODEL and software version, $VERSION" | tee -a ${BUILDLOG} >/dev/null
      buildstatus

      #status clearstatus
      status "setstatus" "buildstatus" "true" "Started building the loader from Model :${MODEL}-${VERSION} at : $(date +"%A %b %Y Time: %H:%M:%S")"

      downloadtools | tee -a ${BUILDLOG} >/dev/null

      downloadpat | tee -a ${BUILDLOG} >/dev/null

      build | tee -a ${BUILDLOG} >/dev/null

      #result="$(cd ${HOMEPATH} && ./rploader.sh build v1000-7.1.0-42661 withfriend)"
      #recho "$result" | tee -a buildlog.log

    fi

    if [ -z "$MODEL" ]; then

      selectmodel

    elif [ -z "$VERSION" ]; then
      selectversion
    fi

    if [ ! -z "$MODEL" ] && [ ! -z "$VERSION" ] && [ -z "$buildit" ] && [ ! -z "$action" ]; then

      #selectversion
      #echo "<br></h1>Selected Model = $MODEL <br> Selected Version = $VERSION</h1><br>"
      breadcrumb
      buildstatus
      buildform
      status recreatejson

    fi

  fi

  pagefooter
fi
