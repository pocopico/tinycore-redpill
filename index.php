<?php

function htmlhead() {

  echo <<<EOF

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

    <div class="navbar navbar-inverse navbar-fixed-top navbar-expand-lg navbar-light bg-light">
      <div class="navbar-inner">
        <div class="container">
          <button type="button" class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="brand" href="#">TinyCore RedPill 💊</a>
          <div class="nav-collapse collapse">
            <ul class="nav">
              <li class="active"><a href="#">Home</a></li>
                 <li class="nav-item dropdown">
        <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
          System
        </a>
        <div class="dropdown-menu" aria-labelledby="navbarDropdown">
          <a class="dropdown-item" href="#">Action</a>
          <a class="dropdown-item" href="#">Another action</a>
          <div class="dropdown-divider"></div>
          <a class="dropdown-item" href="#">Something else here</a>
        </div>
      </li>
              <li><a href="https://github.com/pocopico/tinycore-redpill">Tinycore Redpill Repo</a></li>
              <li><a href="https://xpenology.com/forum/topic/53817-redpill-tinycore-loader/">Contact</a></li>
            </ul>
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>

    <div class="container">

EOF;

    }

function htmlfooter(){

  echo <<<EOF

    </div> <!-- /container -->

    <!-- Le javascript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
    <script src="assets/js/jquery.js"></script>
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

  </body>
</html>

EOF;

}

function executecmd($cmd){

  echo "<pre>";
  $handle = popen($cmd, 'r');
  while (!feof($handle)) {
    echo fgets($handle);
    flush();
    //  ob_flush();
  }
  pclose($handle);
  
  echo "</pre>";
}

function getuserconfig(){

$vid=""; $pid=""; $sn="";$mac1="" ; $mac2="";$mac3="";$mac4="";

$file = '/home/tc/user_config.json'; 
$json = file_get_contents($file);
$data = json_decode($json,true);

$extracmdline = $data["extra_cmdline"];
$synoinfo = $data["synoinfo"];
$ramdiskcopy= $data["ramdisk_copy"] ;

//print_r($data);
//foreach($data as $key => $value) {
//    $$key = $value;
//}



$vid=$extracmdline["vid"] ; 
$pid=$extracmdline["pid"] ; 
$sn=$extracmdline["sn"] ; 
$mac1=$extracmdline["mac1"] ; 
if (!empty($extracmdline["mac2"]) && is_null($extracmdline["mac2"]) ) {   $mac2=$extracmdline["mac2"] ; };
if (!empty($extracmdline["mac3"]) && is_null($extracmdline["mac3"]) ) {   $mac2=$extracmdline["mac3"] ; };
if (!empty($extracmdline["mac4"]) && is_null($extracmdline["mac4"]) ) {   $mac2=$extracmdline["mac4"] ; };
$sataportmap=$extracmdline["SataPortMap"] ; 
$diskidxmap=$extracmdline["DiskIdxMap"] ; 

//global $vid, $pid, $sn, $mac1, $mac2, $mac3, $mac4, $sataportmap, $diskidxmap;
//echo "Extra_cmdline: " . $extracmdline;
//echo "Synoinfo: " . $synoinfo;

setuserconfig($vid, $pid, $sn, $mac1, $mac2, $mac3, $mac4, $sataportmap, $diskidxmap,$synoinfo, $ramdiskcopy );

}


function setuserconfig($vid, $pid, $sn, $mac1, $mac2, $mac3, $mac4, $sataportmap, $diskidxmap, $synoinfo, $ramdiskcopy){


$file = '/home/tc/user_config_new.json'; 

$extracmdline = [ 
"vid" => "$vid",
"pid" => "$pid",
"sn" => "$sn",
"mac1" => "$mac1",
"SataPortMap" => "$sataportmap",
"DiskIdxMap" => "$diskidxmap"
];


$json = [

"extra_cmdline"=> $extracmdline,
"synoinfo" => $synoinfo,
"ramdisk_copy" => $ramdiskcopy

];

file_put_contents($file, json_encode($json));

}


function showuserconfig(){

$file = '/home/tc/user_config_new.json'; 
$json = file_get_contents($file);

echo "<pre>";
echo "$json";
echo "</pre>";
}


function getplaforms(){


$file = '/home/tc/custom_config.json'; 
$json = file_get_contents($file);
$data = json_decode($json,true);

$configs = $data["build_configs"];

echo "Select Platform : " ;
echo "<select>";

foreach($configs as $elem)  {
   echo("<option value=" . $elem['id'] . ">" . $elem['id'] . "</option>");
}
echo "</select>";

}


htmlhead();
getuserconfig();
//showuserconfig();
getplaforms();
htmlfooter();