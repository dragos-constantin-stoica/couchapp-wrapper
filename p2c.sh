#!/bin/bash

#
# Push to CouchDB all files in argument[1] directory
# as attachetemts to argument[3] document in 
# argument[2] database
#
# @authon: Dragos STOICA
# @date: 15.03.2016
# @licence: Apache 2.0
#


#
# Change database connection accordingly
# this is local instance with username and password root
#
COUCHDB_CONNECTION="http://user:password@127.0.0.1:5984"

#
# Cleanup first
# Delete database
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!DO NOT DO THIS IN PRODUCTION!!!
# !!!THIS IS FOR TESTING PURPOSES!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#curl -X DELETE $COUCHDB_CONNECTION/$2
#curl -X PUT $COUCHDB_CONNECTION/$2

#
# How to use this tool
#
usage()
{
	echo "Push to CouchDB tool usage:"
	echo "$0 [folder_path] [destination_database] [document_name]"
	echo ""
	echo "All files from [folder_path] including subfolders"
	echo "will be uploaded as attachments to [document_name]"
	echo "in the [destination_database]"
	echo "-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
	echo "Example:"
	echo "$0 ./app db_test _design/app"
 
	return
}


if [ $# -lt 3 ]; then
	usage
	exit 0
fi

#
# Delete destination document if it exists
#
REV=`curl -I HEAD -s "$COUCHDB_CONNECTION/$2/$3" | grep "ETag:" | sed 's/ETag: \"/rev=/g' | sed 's/\"//g'`

if [[ ${REV} ]]; then
    REV=${REV%$'\r'}
    curl -vX DELETE  "$COUCHDB_CONNECTION/$2/$3?$REV"
fi

#
# Create multipart/realted document
#

rm t.txt
rm h.txt

FIRST_ATTACHMENT=0


echo -en '--5u930\r\ncontent-type: application/json\r\n\r\n' > h.txt
echo -en '{\r\n\t"pushapp": "v0.0.1",\r\n\t"_attachments": {\r\n' >> h.txt

for file in `find $1 -type f | sed 's:^./\(.*\)$:\1:'`; do

	echo $file
	if [ $FIRST_ATTACHMENT -eq 0 ]; then
		FIRST_ATTACHMENT=1
	else
		echo -en ",\r\n" >> h.txt
		 
	fi
	
	MIME_TYPE=`file -b --mime-type ./$file`
	
	echo -en '\t\t"'$file'":{\r\n\t\t\t"follows":true,\r\n' >> h.txt
	echo -en '\t\t\t"content_type":"'$MIME_TYPE'",\r\n' >> h.txt
    # On linux
	#echo -en '\t\t\t"length":'`stat --printf="%s" ./$file`'\r\n\t\t}' >> h.txt
    # On MAC
    echo -en '\t\t\t"length":'`stat -f "%z" ./$file`'\r\n\t\t}' >> h.txt
	
	# Print the content of the file in t.txt
	echo -en '\r\n--5u930\r\n' >> t.txt
	if [ "$MIME_TYPE" != "text/plain" ]; then 
		echo -en 'Content-Type: '$MIME_TYPE >> t.txt
		echo -en '\r\nContent-transfer-encoding: '`file -b --mime-encoding ./$file`'\r\n\r\n' >> t.txt
	else
		echo -en '\r\n' >> t.txt
	fi
	cat ./$file >> t.txt

done

echo -en '\r\n\t}\r\n}\r\n' >> h.txt

# Concatenate h and t
cat t.txt >> h.txt

# Close mulipart/realted document
echo -en "\r\n--5u930--\r\n" >> h.txt

#
# Write document to the database
#

curl -vX PUT $COUCHDB_CONNECTION/$2/$3 \
-H 'Content-Type:  multipart/related; boundary="5u930"' --data-binary @h.txt

# Cleanup
rm t.txt
rm h.txt
