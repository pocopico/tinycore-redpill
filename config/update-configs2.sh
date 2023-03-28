for file in `cat file`
do 
model=`echo $file |sed -e 's/+/%2B/g'`
echo "Working on $file for model $model"

value="https://global.synologydownload.com/download/DSM/beta/7.2/64216/DSM_${model}_64216.pat"
jsonfile=$(jq ".os.pat_url=\"$value\"" $file/7.2.0-64216/config.json) 
echo $jsonfile | jq . > $file/7.2.0-64216/config.json
done 

