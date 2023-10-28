#!/usr/bin/sudo bash

HOMEPATH="/home/tc"
CONFIGFILES="${HOMEPATH}/config"

#####################################

if [ -z "$GATEWAY_INTERFACE" ]; then
  [ -z "$GATEWAY_INTERFACE" ] && [ "$1" = "version" ] && echo "$SCRIPTVERSION" || echo "This is meant to run under CGI or to include functions in other scripts"
  [ ! -z "$GATEWAY_INTERFACE" ] && [ "$1" = "version" ] && echo "$SCRIPTVERSION" && exit 0
else

  action="$(echo "${QUERY_STRING}" | awk -F= '{print $2}' | awk -F\& '{print $1}')"
  echo "$QUERY_STRING" >>/home/tc/html/files.txt
  case $action in
  delfile)
    FILENAME="$(echo "${QUERY_STRING}" | awk -F\& '{print $2}' | awk -F= '{print $2}')"
    [ "$FILENAME" = "ALL" ] && rm -rf /home/tc/html/files/* || rm -f /home/tc/html/files/$FILENAME
    [ "$FILENAME" ! = "ALL" ] && [ ! -f /home/tc/html/$FILENAME ] && echo "$FILENAME has been deleted" >>/home/tc/html/files.txt || echo "$FILENAME has not been deleted" >>/home/tc/html/files.txt
    ;;
  usefile)
    FILENAME="$(echo "${QUERY_STRING}" | awk -F\& '{print $2}' | awk -F= '{print $2}')"

    if [ $(echo $FILENAME | cut -c 1-3) = "DSM" ]; then
      NEWFILENAME=$(echo $FILENAME | tr '[:upper:]' '[:lower:]' | cut -c 5-99 | sed -e 's/+/p/g' -e 's/%2B/p/g')
      mv ${FILENAME} ${NEWFILENAME}
      FILENAME="${NEWFILENAME}"
    fi

    fileextension="$(echo $FILENAME | awk -F. '{print $NF}')"
    models="$(ls ${CONFIGFILES} | grep -v comm | grep -v disabled | sed -e 's/\///' | sed -e 's/+/p/g' | tr '[:upper:]' '[:lower:]')"
    case $fileextension in
    pat)

      model="$(echo $FILENAME | awk -F_ '{print $1}')" && echo "MODELS : $models , model: $model" >>/home/tc/html/files.txt && [ $(echo $models | grep -w $model) ] && echo "found pat file for model $model" >>/home/tc/html/files.txt
      ln -s /home/tc/html/files/$FILENAME /home/tc/html/$FILENAME

      ;;
    json)

      if [ "$FILENAME" = "user_config.json" ]; then
        model=$(jq -re '.general.model' /home/tc/html/files/$FILENAME | sed -e 's/+/p/g' | tr '[:upper:]' '[:lower:]')
        echo "MODELS : $models , model: $model" >>/home/tc/html/files.txt && [ $(echo $models | grep -w $model) ] && echo "found user config file for model $model" >>/home/tc/html/files.txt
        mv /home/tc/$FILENAME /home/tc/${FILENAME}.$(date +%Y%m%d%H%M) && ln -s /home/tc/html/files/$FILENAME /home/tc/$FILENAME
      else
        echo "found json file that i cannot use" >>/home/tc/html/files.txt
      fi

      ;;
    esac
    ;;

  esac

  // Redirect to index.html
  cat <<EOF

<!DOCTYPE html>
<html lang="en">
  <head>
  <meta http-equiv="refresh" content="0; url=/index.sh?action=filemanagement" />
  </head>  
</html>

EOF

fi
