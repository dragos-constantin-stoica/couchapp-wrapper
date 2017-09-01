#!/bin/bash

#
# Push to CouchDB design documents stored in a folder on local drive.
# This tool transforms a flat directory-file structure into a couple of
# design documents, including attachments.
#
# @author: Dragos STOICA
# @date: 15.03.2016
# @licence: Apache 2.0
#


#
# Change database connection accordingly
# using the command line parameters
#
COUCHDB_PROTOCOL="http"
COUCHDB_SERVER="localhost"
COUCHDB_PORT="5984"
COUCHDB_USER=""
COUCHDB_PASSWORD=""
COUCHDB_CONNECTION=""

COUCHDB_DATABASE=""
REV=""
declare -a TMP_FILES=('_head.txt' '_tail.txt'); 

#
# Auxiliary function to build CouchDB connection string
#
build_couchdb_connection()
{
	if [[ ${COUCHDB_USER} ]] && [[ ${COUCHDB_PASSWORD} ]]; then
		COUCHDB_CONNECTION=$COUCHDB_PROTOCOL"://"$COUCHDB_SERVER":"$COUCHDB_PORT
	else
		COUCHDB_CONNECTION=$COUCHDB_PROTOCOL"://"$COUCHDB_USER":"$COUCHDB_PASSWORD"@"$COUCHDB_SERVER":"$COUCHDB_PORT
	fi
}

#
# Auxiliary function to delete temporary files
#
del_tmp_files()
{
	for tmpf in "${TMP_FILES[@]}"
	do
		if [ -e "$tmpf" ]; then
			# echo "File exists"
			rm $tmpf
		fi 
	done
}


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
# Auxiliary function of how to use this tool
#
usage()
{
	echo "Tool to Push design documents to CouchDB"
	echo "Usage example:"
	echo -e "\n$0 --server=[server] --port=[port] --db=[database]\n"
	echo "All subfolders from folder [database] will be considered as"
	echo "design documents. The name of the subfolder is the ddoc name "
	echo -e "\n\t test_db"
	echo -e "\t\t|_ app"
	echo -e "\t\t|_ user_views\n"
	echo "will be mapped to _design/couchapp and _design/user_views."
	echo ""
	echo "The structure of the design document is mapped on subfolders:"
	echo -e "\n\t test_db"
	echo -e "\t\t|_ app"
	echo -e "\t\t\t|_ attachments"	
	echo -e "\t\t\t\t|... [JS CouchApp]"
	echo -e "\t\t\t\t|... [source files]\n"
	echo -e "\t\t\t|_ views"	
	echo -e "\t\t\t\t|_ lib"
	echo -e "\t\t\t\t\t|_ lib_name"
	echo -e "\t\t\t\t\t\t|_ lib_export_module.js"
	echo -e "\t\t\t\t|_ view_name"
	echo -e "\t\t\t\t\t|_ map.js"
	echo -e "\t\t\t\t\t|_ reduce.js\n"
	echo -e "\t\t\t|_ lists"
	echo -e "\t\t\t\t|_ list_function.js\n"	
	echo -e "\t\t\t|_ shows"
	echo -e "\t\t\t\t|_ show_function.js\n"		
	echo -e "\t\t\t|_ updates"
	echo -e "\t\t\t\t|_ update_function.js\n"	
	echo -e "\t\t\t|_ filters"		
	echo -e "\t\t\t\t|_ filter_function.js\n"	
	echo -e "\t\t\t|_ full_text"
	echo -e "\t\t\t\t|_ index_name"
	echo -e "\t\t\t\t\t|_ index.js\n"	
	echo -e "\t\t\t|_ rewrites.js"	
	echo -e "\t\t\t|_ validate_doc_update.js\n"	
	echo "See test_db folder for an example."
	echo "The attachments will be uploaded to _design/[ddoc_name]"
	echo "in the [database]. Please specify other parameters if needed."
	echo ""
	echo -e " --protocol\tCouchDB server protocol. Default http"
	echo -e " --server  \tCouchDB server name or IP address. Default localhost"
	echo -e " --port    \tCouchDB server port. Default 5984"
	echo -e " --user    \tCouchDB user name"
	echo -e " --password\tCouchDB password"	
	echo -e " --db      \tDatabase name, it must exists. Mandatory argument"
	echo -e " --help    \tDisplay this message"
	echo ""
	echo "> -~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~ <"
	echo "Example:"
	echo -e "\n$0 --db=test_db\n"
	echo "Realx and enjoy life!"
}


#
# Auxiliary function to push attachments to a design document
# The first argument is the directory where the files are
# The second argument is the design document name
push_attachments()
{
	#
	# Cleanup temporary files
	#
	del_tmp_files


	#
	# Create multipart/realted document
	#


	FIRST_ATTACHMENT=0


	echo -en '--5u930\r\ncontent-type: application/json\r\n\r\n' > ${TMP_FILES[0]}
	echo -en '{\r\n\t"pushapp": "v0.0.1",\r\n\t"_attachments": {\r\n' >> ${TMP_FILES[0]}

	for file in `find $1 -type f | sed 's:^./\(.*\)$:\1:'`; do

		#echo $file
		attachment_name=`echo $file| sed 's:'$1'/::g'`
		#echo $attachment_name

		if [ $FIRST_ATTACHMENT -eq 0 ]; then
			FIRST_ATTACHMENT=1
		else
			echo -en ",\r\n" >> ${TMP_FILES[0]}
			
		fi
		
		MIME_TYPE=`file -b --mime-type ./$file`
		#
		# FIX for css mime-type
		# put text/css instead of text/plain
		#
		if [ "${file##*.}" = "css"  ]; then
			MIME_TYPE="text/css"
		fi
		echo -en '\t\t"'$attachment_name'":{\r\n\t\t\t"follows":true,\r\n' >> ${TMP_FILES[0]}
		echo -en '\t\t\t"content_type":"'$MIME_TYPE'",\r\n' >> ${TMP_FILES[0]}
		# On linux
		echo -en '\t\t\t"length":'`stat --printf="%s" ./$file`'\r\n\t\t}' >> ${TMP_FILES[0]}
		# On MAC
		#echo -en '\t\t\t"length":'`stat -f "%z" ./$file`'\r\n\t\t}' >> ${TMP_FILES[0]}
		
		# Print the content of the file in ${TMP_FILES[1]}
		echo -en '\r\n--5u930\r\n' >> ${TMP_FILES[1]}
		if [ "$MIME_TYPE" != "text/plain" ]; then 
			echo -en 'Content-Type: '$MIME_TYPE >> ${TMP_FILES[1]}
			echo -en '\r\nContent-transfer-encoding: '`file -b --mime-encoding ./$file`'\r\n\r\n' >> ${TMP_FILES[1]}
		else
			echo -en '\r\n' >> ${TMP_FILES[1]}
		fi
		cat ./$file >> ${TMP_FILES[1]}

	done

	echo -en '\r\n\t}\r\n}\r\n' >> ${TMP_FILES[0]}

	# Concatenate h and t
	cat ${TMP_FILES[1]} >> ${TMP_FILES[0]}

	# Close mulipart/realted document
	echo -en "\r\n--5u930--\r\n" >> ${TMP_FILES[0]}

	#
	# Write document to the database
	#
	REV=`curl -I HEAD -s "$COUCHDB_CONNECTION/$COUCHDB_DATABASE/$2" | grep "ETag:" | sed 's/ETag: \"/rev=/g' | sed 's/\"//g'`
	if [[ ${REV} ]]; then
		REV=${REV%$'\r'}
		curl -vX PUT $COUCHDB_CONNECTION/$COUCHDB_DATABASE/$2?$REV \
		-H 'Content-Type:  multipart/related; boundary="5u930"' --data-binary @${TMP_FILES[0]}
	else
		curl -vX PUT $COUCHDB_CONNECTION/$COUCHDB_DATABASE/$2 \
		-H 'Content-Type:  multipart/related; boundary="5u930"' --data-binary @${TMP_FILES[0]}
	fi

	# Cleanup temporary files
	del_tmp_files
}

###################
# The main script #
###################

#
# Check if at leas 2 arguments were passed
#
if [ $# -lt 1 ]; then
	usage
	exit 0
fi

#
# Check command line arguments and exit in the absence of 
# mandatory arguments
#
while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        --help)
            usage
            exit
            ;;
        --protocol)
			COUCHDB_PROTOCOL=$VALUE
			;;
        --server)
            COUCHDB_SERVER=$VALUE
            ;;
        --port)
            COUCHDB_PORT=$VALUE
            ;;
        --user)
            COUCHDB_USER=$VALUE
            ;;
        --password)
            COUCHDB_PASSWORD=$VALUE
            ;;
        --db)
            COUCHDB_DATABASE=$VALUE
            ;;
        *)
			usage
            echo "ERROR: unknown parameter \"$PARAM\""
            exit 1
            ;;
    esac
    shift
done

# Check database manadatory parameter
if [ -z "$COUCHDB_DATABASE" ]; then
	usage
	echo "Database name must be provided via --db argument"
	exit 1
fi

# Check if the folder exits
if [ ! -e "$COUCHDB_DATABASE" ]; then
	echo "$COUCHDB_DATABASE folder does not exists!"
	exit 1
fi

# Seems ok! Start processing
build_couchdb_connection

#
# Go inside the folder and fetch each subfolder
# this should contain the information for a 
# desing document
# 
for ddoc in `find ${COUCHDB_DATABASE}/ -maxdepth 1 -type d | sed 's/'${COUCHDB_DATABASE}'\///g'`; do
	echo $ddoc 
	DDOC_NAME='_design/'$ddoc

	#
	# Delete destination design document if it exists
	#
	REV=`curl -I HEAD -s "$COUCHDB_CONNECTION/$COUCHDB_DATABASE/$DDOC_NAME" | grep "ETag:" | sed 's/ETag: \"/rev=/g' | sed 's/\"//g'`

	if [[ ${REV} ]]; then
		REV=${REV%$'\r'}
		curl -vX DELETE  "$COUCHDB_CONNECTION/$COUCHDB_DATABASE/$DDOC_NAME?$REV"
	fi
	
	#
	# Explore the structure of the design document folder and compose the document
	#
	
	#
	# Look for attachments subfolder
	#
	
	if [ -e "$COUCHDB_DATABASE/$ddoc/attachments" ]; then
		push_attachments $COUCHDB_DATABASE"/"$ddoc"/attachments" $DDOC_NAME
	fi
	
	#
	# Look for ddoc.json containing the JavaScript code
	#
	if [ -f "$COUCHDB_DATABASE/$ddoc/ddoc.json"  ]; then
		REV=`curl -I HEAD -s "$COUCHDB_CONNECTION/$COUCHDB_DATABASE/$DDOC_NAME" | grep "ETag:" | sed 's/ETag: \"/rev=/g' | sed 's/\"//g'`

		if [[ ${REV} ]]; then
			REV=${REV%$'\r'}
			# Update existing document
		else
			# New document
		fi

	fi

done	

######################
# End of Main script #
######################
