#!/bin/bash
INPUT=/tmp/menu.sh.$$
OUTPUT=/tmp/output.sh.$$

[[ "$(which dialog)_" == "_" ]] &&  tce-load -wi dialog
 

function buildmenu(){

dialog --clear --help-button \
--backtitle "$BACKTITLE" \
--menu "Choose the option" 18 45 45 \
build "Build Loader" \
return "Return to main menu" 2>"${INPUT}" 

menuitem=$(<"${INPUT}")
# make decsion 
case $menuitem in
	build)   
	        getvars $TARGET_PLATFORM-$TARGET_VERSION-$TARGET_REVISION ;  checkinternet ; getlatestrploader ; gitdownload    
        	echo "Using static compiled redpill extension"
            getstaticmodule
            echo "Got $REDPILL_MOD_NAME "
            listmodules
            echo "Starting loader creation "
            buildloader
 ;;
	return) echo "mainmenu"; return ;;

esac


}

function extmenu(){ 

if [ ! -d /home/tc/redpill-load ] || [ ! -d /home/tc/redpill-lkm ] ; then 
	dialog --msgbox "No loader directoy exists, please download first " 30 90
	return
	else 
	continue
	fi

dialog --clear --help-button \
--backtitle "$BACKTITLE" \
--menu "Choose the option" 18 45 45 \
auto "Auto add extensions" \
add "Auto add extensions" \
addlist "Select extensions from a list" \
remove "Auto add extensions" \
update "Update extensions" \
info "Get information about installed extensions" \
return "Return to main menu" 2>"${INPUT}" 

menuitem=$(<"${INPUT}")
# make decsion 
case $menuitem in
	auto) dialog --msgbox "$(listmodules)" 30 90 ;;
    add ) 
	dialog --inputbox "Please enter download URL" 10 90 "http://" 2>$OUTPUT 
	dialog --msgbox "`/home/tc/redpill-load/ext-manager.sh add $(<$OUTPUT) 2>&1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"`" 30 90
	;;
	addlist)
	LIST=`jq  ". | select(.id )  .info.name, .info.description" rpext-index.json | sed -s 's/ /_/g' | sed -s 's/"/ /g' | awk '{printf (NR%2==0) ? $0 "\n" : $0}' |  sed -s 's/""/" "/g' |sed -s 's/$/ "off" /'`
    dialog --checklist "Select extensions from the list" 25 120 20 $LIST 2>$OUTPUT
	for ext in `cat $OUTPUT` 
	do
	dialog --msgbox "`/home/tc/redpill-load/ext-manager.sh add https://raw.githubusercontent.com/pocopico/rp-ext/master/$ext/rpext-index.json 2>&1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"`" 30 90 ; sleep 1
	done
    ;;
	
    remove) 
	LIST=$(let num=0 ; for item in `find /home/tc/redpill-load/custom/extensions/* -type d  | awk -F\/ '{print $7}'` ; do let num=$num+1 ; echo "$item $num off" ; done)
             if [ `echo $LIST |wc -w` -gt 1 ] ; then
	         dialog --checklist "Remove" 20 90 10 $LIST 2>$OUTPUT
	         #ext=$(<$OUTPUT)
			      if [ `cat $OUTPUT |wc -w` -gt 0 ] ; then 
				  for ext in $(<$OUTPUT) 
				  do
	              dialog --msgbox "`/home/tc/redpill-load/ext-manager.sh remove $ext 2>&1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"`" 30 90
				  done
	              rm $OUTPUT
			      else 
			      return
			      fi
		  else
		  return	
		  fi 
	;;
    update) dialog --msgbox "`/home/tc/redpill-load/ext-manager.sh update 2>&1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"`" 30 90  ;;
    info) 	dialog --msgbox "`/home/tc/redpill-load/ext-manager.sh info 2>&1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"`" 30 90 	;;
	return) echo "mainmenu"; return ;;
esac


}

function msgbox(){

dialog --backtitle "@BACKTITLE" --msgbox "$@"

}

function serialgenmenu(){

dialog --clear --help-button \
--backtitle "$BACKTITLE" \
--menu "Choose the option" 18 45 45 \
DS3615xs "DS3615xs" \
DS3617xs "DS3617xs" \
DS916+   "DS916+"   \
DS918+   "DS918+"   \
DS920+   "DS920+"   \
DVA3219  "DVA3219"  \
DVA3221  "DVA3221"  \
return "Return to main menu" 2>"${INPUT}" 

menuitem=$(<"${INPUT}")
# make decsion 
case $menuitem in
    DS3615xs) 
	msgbox "Serial Number for Model $menuitem : $(generateSerial $menuitem)\nMac Address for Model $menuitem : $(generateMacAddress $menuitem)"  10 70
	;;                                                     
    DS3617xs)                                              
	msgbox "Serial Number for Model $menuitem : $(generateSerial $menuitem)\nMac Address for Model $menuitem : $(generateMacAddress $menuitem)"  10 70
	;;                                                    
    DS916+)                                               
	msgbox "Serial Number for Model $menuitem : $(generateSerial $menuitem)\nMac Address for Model $menuitem : $(generateMacAddress $menuitem)"  10 70
	;;                                                    
    DS918+)                                               
	msgbox "Serial Number for Model $menuitem : $(generateSerial $menuitem)\nMac Address for Model $menuitem : $(generateMacAddress $menuitem)"  10 70
	;;                                                    
    DS920+)                                               
	msgbox "Serial Number for Model $menuitem : $(generateSerial $menuitem)\nMac Address for Model $menuitem : $(generateMacAddress $menuitem)"  10 70
	;;                                                    
    DVA3219)                                              
	msgbox "Serial Number for Model $menuitem : $(generateSerial $menuitem)\nMac Address for Model $menuitem : $(generateMacAddress $menuitem)"  10 70
	;;                                                    
    DVA3221)                                              
    msgbox "Serial Number for Model $menuitem : $(generateSerial $menuitem)\nMac Address for Model $menuitem : $(generateMacAddress $menuitem)"  10 70
	;;
    info) dialog --msgbox "`ls . `" 20 50 ;;
	return) echo "mainmenu"; return ;;
esac


}



function mainmenu(){

while true
do

dialog --clear --help-button \
--backtitle "$BACKTITLE" \
--menu "Choose the option" 18 45 45 \
build "Build Loader" \
ext "Manage extensions" \
download "Download RedPill Sources" \
listmods "List Modules" \
serialgen "Serial and Mac generation" \
update "Update rploader" \
clean "Clean and Exit" \
Exit "Exit to shell" 2>"${INPUT}" 

menuitem=$(<"${INPUT}")

case $menuitem in
	build) buildmenu ;;
	ext) extmenu ;;
	download)  dialog --msgbox "`getvars $TARGET_PLATFORM-$TARGET_VERSION-$TARGET_REVISION ;  checkinternet ; gitdownload`" 30 90  ;;
	listmods) msgbox "$(listmodules) 2>&1" 30 90 ; echo "$extensionslist" ;;
	serialgen) serialgenmenu ;;
	update) checkinternet ; getlatestrploader ;;
	clean) cleanloader ; break ;;
	Exit) echo "Bye"; break;;
esac

done

}

dialog --backtitle "RedPill Loader" --infobox "Welcome to Tinycore RedPill Loader Interactive" 3 45 ; sleep 1

getvars $2

BACKTITLE="RedPill Loader : $TARGET_PLATFORM $TARGET_VERSION $TARGET_REVISION"

mainmenu


# if temp files found, delete
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT