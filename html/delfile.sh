#!/usr/bin/sudo bash

if [ -z "$GATEWAY_INTERFACE" ]; then
    [ -z "$GATEWAY_INTERFACE" ] && [ "$1" = "version" ] && echo "$SCRIPTVERSION" || echo "This is meant to run under CGI or to include functions in other scripts"
    [ ! -z "$GATEWAY_INTERFACE" ] && [ "$1" = "version" ] && echo "$SCRIPTVERSION" && exit 0
else

    FILENAME="$(echo "${QUERY_STRING}" | awk -F= '{print $2}')"

    [ "$FILENAME" = "ALL" ] && rm -rf /home/tc/html/files/* || rm -f /home/tc/html/files/$FILENAME

    [ "$FILENAME" ! = "ALL" ] && [ ! -f /home/tc/html/$FILENAME ] && echo "$FILENAME has been deleted" >>/home/tc/html/dellog.txt || echo "$FILENAME has not been deleted" >>/home/tc/html/dellog.txt

    echo "Gateway is : $GATEWAY_INTERFACE"

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
