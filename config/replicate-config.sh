
for file in `cat file`
do 
echo "Working on $file"
cp -rp $file/7.1.1-42962 $file/7.2.0-64216
cd $file/7.2.0-64216
sed -i 's/42962/64216/g' config.json
sed -i 's/7.1.1/7.2.0/g' config.json
sed -i 's/redpill-linux-v4.4.180+.ko/redpill-linux-v4.4.302+.ko/g' config.json
file=`ls *42962*bsp`
newfile=`echo $file |sed -e 's/42962/64216/g'`
mv $file $newfile
cd /mnt/hgfs/Downloads/redpill-load/config
done

