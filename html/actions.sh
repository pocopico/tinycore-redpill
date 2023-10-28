#!/usr/bin/sudo bash

function pagehead() {
  cat <<EOF

<!DOCTYPE html>
<html>
    <head>
        <!-- head definitions go here -->
    </head>
    <body>
        <!-- the content goes here -->
$@ OK
EOF

}

function pagebody() {
  cat <<EOF
    </body>
</html>

EOF
}

function urldecode {
  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

logtofile() {

  echo "$@" >>actions.log

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

  if [ "$REQUEST_METHOD" = "GET" ]; then
    MODEL="$(echo ${get[mymodel]} | sed -e "s/'//g")"
    VERSION="$(echo ${get[myversion]} | sed -e "s/'//g")"
    action="$(echo "${get[action]}" | sed -e "s/'//g")"
  elif [ "$REQUEST_METHOD" = "POST" ]; then
    exturl="$(echo ${post[exturl]})"
    platform="$(echo ${post[platform]})"
    if [ -z "$(echo ${post[mymodel]} | sed -e "s/'//g")" ]; then
      MODEL="$(echo "${get[mymodel]}" | sed -e "s/'//g")"
    else
      MODEL="$(echo "${post[mymodel]}" | sed -e "s/'//g")"
    fi
    VERSION="$(echo "${post[myversion]}" | sed -e "s/'//g")"
    REVISION="$(echo "${VERSION}" | awk -F- '{print $2}')"
    serial="$(echo "${post[serial]}" | sed -e "s/'//g")"
    macaddress="$(echo "${post[macaddress]}" | sed -e "s/'//g")"

    if [ -z "$(echo ${post[action]} | sed -e "s/'//g")" ]; then
      action="$(echo "${get[action]}" | sed -e "s/'//g")"
    else
      action="$(echo "${post[action]}" | sed -e "s/'//g")"
    fi
    #action="$(echo "${post[action]}" | sed -e "s/'//g")"
    extracmdline="$(
      echo "${post[extracmdline]}" | sed -e "s/'//g" | sed -e 's/ /\n/g' | sed -e 's/%3D/=/g'
    )"
    buildit="$(echo "${post[buildit]}" | sed -e "s/'//g")"

  fi

fi

case $action in

extadd)
  /home/tc/include/extmgr.sh extadd $exturl $platform
  ;;
extrem)
  /home/tc/include/extmgr.sh extremove $exturl $platform
  ;;
manualextadd)
  /home/tc/include/extmgr.sh extadd $exturl $platform
  ;;

esac

logtofile "------------------- Start ------------------------"
logtofile "cmd : $action, $1 $2 $3 $4"
logtofile "ext url : $exturl"
logtofile "ext platform : $platform"
logtofile "GATEWAY : $GATEWAY_INTERFACE"
logtofile "Request method : $REQUEST_METHOD"
logtofile "POST Action : ${post[action]}"
logtofile "GET Action : $action"
logtofile "Post all : ${post[@]}"
logtofile "GET all : ${get[@]}"

logtofile "QUERY : $QUERY_STRING"
logtofile "POST : $POST_STRING"
logtofile "------------------- End ------------------------"
