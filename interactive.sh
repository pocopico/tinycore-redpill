#!/bin/bash
INPUT=/tmp/menu.sh.$$
OUTPUT=/tmp/output.sh.$$

BACKTITLE="RedPill Loader : $TARGET_PLATFORM $TARGET_VERSION $TARGET_REVISION"

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
	build)   getvars $TARGET_PLATFORM-$TARGET_VERSION-$TARGET_REVISION ;  checkinternet ; getlatestrploader ; gitdownload ;;
	return) echo "mainmenu"; return ;;

esac


}

function extmenu(){

dialog --clear --help-button \
--backtitle "$BACKTITLE" \
--menu "Choose the option" 18 45 45 \
auto "Auto add extensions" \
add "Auto add extensions" \
remove "Auto add extensions" \
update "Update extensions" \
info "Get information about installed extensions" \
return "Return to main menu" 2>"${INPUT}" 

menuitem=$(<"${INPUT}")
# make decsion 
case $menuitem in
	auto) dialog --msgbox "$(listmodules)" 60 30 ;;
    add ) dialog --form "Please enter download URL" 60 40 2 "URL:" 1 1 "" 1 12 15 0 ;;
    remove) dialog --form "Please enter download URL" 60 40 2 "URL:" 1 1 "" 1 12 15 0  ;;
    update) dialog --msgbox "`/home/tc/redpill-load/ext-manager.sh update 2>&1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"`" 60 70  ;;
    info) 	dialog --msgbox "`/home/tc/redpill-load/ext-manager.sh info 2>&1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"`" 60 70 	;;
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

# make decsion 
case $menuitem in
	build) buildmenu ;;
	ext) extmenu ;;
	download)    getvars $TARGET_PLATFORM-$TARGET_VERSION-$TARGET_REVISION ;  checkinternet ; gitdownload  ;;
	listmods) msgbox $(listmodules) 20 50 ; echo "$extensionslist" ;;
	serialgen) serialgenmenu ;;
	update) checkinternet ; getlatestrploader ;;
	clean) cleanloader ; break ;;
	Exit) echo "Bye"; break;;
	Cancel) echo "Bye"; break;;
esac

done

}

dialog --backtitle "RedPill Loader 💊" --infobox "Welcome to RedPill 💊 Loader Interactive" 3 45 ; sleep 2

mainmenu


# if temp files found, delete
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT