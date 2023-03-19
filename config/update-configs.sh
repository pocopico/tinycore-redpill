for file in `cat file`
do 
echo "Working on $file"
value=`grep $file files-chksum | grep os.sha256|awk '{print $1}'`
jsonfile=$(jq ".os.sha256=\"$value\"" $file/7.2.0-64216/config.json) 
echo $jsonfile | jq . > $file/7.2.0-64216/config.json

value=`grep $file files-chksum | grep files.zlinux.sha256|awk '{print $1}'`
jsonfile=$(jq ".files.zlinux.sha256=\"$value\"" $file/7.2.0-64216/config.json) 
echo $jsonfile | jq . > $file/7.2.0-64216/config.json

value=`grep $file files-chksum | grep files.ramdisk.sha256|awk '{print $1}'`
jsonfile=$(jq ".files.ramdisk.sha256=\"$value\"" $file/7.2.0-64216/config.json) 
echo $jsonfile | jq . > $file/7.2.0-64216/config.json

value=`grep $file files-chksum | grep files.vmlinux.sha256|awk '{print $1}'`
jsonfile=$(jq ".files.vmlinux.sha256=\"$value\"" $file/7.2.0-64216/config.json) 
echo $jsonfile | jq . > $file/7.2.0-64216/config.json

done 

