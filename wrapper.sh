#!/bin/bash

#
# Wrapper for couchapp
# - syncs design document from CouchDB databases defined in DATABASES to local directory and back
# - you can do a partial sync using cone and push for a specific _design document 
#
# Author - Dragos STOICA
#

# the list of databases to sync with
declare -a DATABASES=('bd2012' 'bd2012_esantionare'); 
declare -A SERVERS
# test, production and local server IP or DNS entry
SERVERS[test_db]=apiatest.couchdb
SERVERS[prod_db]=apia2014.couchdb
SERVERS[localhost]=127.0.0.1
declare -A FOLDERS
# name of folder on local repository where design documents are stored
FOLDERS[test_db]="_teste"
FOLDERS[prod_db]=""
FOLDERS[localhost]="_local"

server=""
database=""

usage()
{
	echo "Usage:"
	echo "$0 clone [source_server] [dbname] [all|view_name]"
	echo "$0 push  [destination_server] [dbname] [all|view_name]"
	echo "$0 deploy [source_server]  [destination_server]"
	echo "$0 copy [source_server]  [destination_server] [dbname] [view_name]"
	echo "where:"
	echo "[dbname] = bd2012 | bd2012_esantionare"
	echo "[source_server],[destination_server] = localhost | test_db | prod_db"
	echo "-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
	return
}

# Auxiliary function for view cloning
clone_view()
{
	echo "Clone view: $1, from database: $database, server: $server"
	if [ "$1" = "all" ]; then
		VIEWS=`curl --request GET -s "http://$server:5984/$database/_all_docs?startkey=%22_design/%22&endkey=%22_design0%22" | awk '{FS="[\":\"]+";if($2 == "id") print $3}'`
		for VIEW in $VIEWS
		do
			#echo "cloing view: ${VIEW}"
			couchapp clone http://$server:5984/$database/${VIEW} ./${VIEW} >/dev/null 2>&1
		done
	else
		couchapp clone http://$server:5984/$database/$1 $1 >/dev/null 2>&1
	fi
}

# Auxiliary function for pushing document to database
push_view()
{
	echo "Push view: $1, in database: $database, server: $server"
	#pentru test_db pe localhost
	#server=$localhost

	if [ "$1" = "all" ]; then
		DIRS=`ls -l --time-style="long-iso" ./_design | egrep '^d' | awk '{print $8}'`
		# "ls -l $MYDIR"      = get a directory listing
		# "| egrep '^d'"           = pipe to egrep and select only the directories
		# "awk '{print $8}'" = pipe the result from egrep to awk and print only the 8th field
		# and now loop through the directories:
		filename="../TMP_`date +%Y-%m-%d_%H-%M-%S`.sh"
		touch $filename
		chmod -cf a+x $filename
		echo "#!/bin/bash" >> $filename	
		urls=""
		compacturls=""
		for DIR in $DIRS
		do
			couchapp push _design/${DIR} http://$server:5984/$database >/dev/null 2>&1
			curl -X PUT http://$server:5984/$database/_design/updateDosar/_update/delCouchapp/_design/${DIR} >/dev/null 2>&1
			if [ -d ./_design/${DIR}/views ]; then
				echo "# _design/${DIR} has at least one view, call it for index refresh" >> $filename
				viewname=`ls -1 ./_design/${DIR}/views/ | head -1`
				urls=$urls${DIR}"/_view/"$viewname","
				compacturls=$compacturls${DIR}"," 
			fi
			if [ -d ./_design/${DIR}/fulltext ]; then
				echo "# _design/${DIR} has at least one lucene index, call for optimization" >> $filename
				VIEWS=`ls -1 ./_design/${DIR}/fulltext/ | awk 'BEGIN{FS="."};{print $1}'`
				for viewname in $VIEWS
				do
					echo "# background execution: http://$server:5984/_fti/productie/$database/_design/${DIR}/${viewname}/_expunge si _optimize" >> $filename
					echo "curl -X POST -s \"http://$server:5984/_fti/productie/$database/_design/${DIR}/${viewname}/_expunge\" >/dev/null 2>&1" >> $filename
					echo "curl -X POST -s \"http://$server:5984/_fti/productie/$database/_design/${DIR}/${viewname}/_optimize\" >/dev/null 2>&1" >> $filename
				done
			fi
		done

		urls=${urls%?}
		compacturls=${compacturls%?} 

		echo "# background execution: http://$server:5984/$database/_design/${DIR}/_view/$viewname" >> $filename			
		echo "curl -X GET -s \"http://$server:5984/$database/_design/{$urls}\" >/dev/null 2>&1" >> $filename
		echo "curl -H \"Content-Type: application/json\" -X POST  \"http://$server:5984/$database/_compact/{$compacturls}\" >/dev/null 2>&1" >> $filename

		echo "#delete this file after issuing all commands" >> $filename
		echo "rm -rf $filename" >> $filename
		/bin/bash $filename &
	else
		couchapp push $1 http://$server:5984/$database >/dev/null 2>&1
		curl --request PUT http://$server:5984/$database/_design/updateDosar/_update/delCouchapp/$1 >/dev/null 2>&1
		if [ -d ./$1/views ]; then
			echo "# $1 has at least a view, call it for reindexing" >> $filename
			viewname=`ls -1 ./$1/views/ | head -1`
			echo "# background execution: http://$server:5984/$database/$1/_view/$viewname" >> $filename
			echo "curl -X GET -s \"http://$server:5984/$database/$1/_view/$viewname\" >/dev/null 2>&1" >> $filename
			echo "curl -H \"Content-Type: application/json\" -X POST  \"http://$server:5984/$database/_compact/$1\" " >> $filename
		fi
		if [ -d ./$1/fulltext ]; then
			echo "# $1 has at least a lucene index, call for optimzation" >> $filename
			viewname=`ls -1 ./$1/fulltext/ | head -1 | awk 'BEGIN{ FS = "."}; {print $1}'`
			echo "# background execution: http://$server:5984/_fti/productie/$database/$1/$viewname/_optimize" >> $filename
			echo "curl -X POST -s \"http://$server:5984/_fti/productie/$database/$1/$viewname/_expunge\" >/dev/null 2>&1" >> $filename
			echo "curl -X POST -s \"http://$server:5984/_fti/productie/$database/$1/$viewname/_optimize\" >/dev/null 2>&1" >> $filename
		fi
		echo "#delete this file after issuing all commands" >> $filename
		echo "rm -rf $filename" >> $filename
		/bin/bash $filename &
	fi
}

#
# clone 
# expects the following parameters
# $1 - source server from which we clone from
# $2 - destination server to which the clone will be pushed to
# $3 - database name
# $4 - view name, expected format: "_design/[name]" sau [all] for all views
#
clone()
{
	echo "Database: $2, view: $3"
	for db in "${DATABASES[@]}"
	do
		if [ "$2" = "$db" ]; then
			server=${SERVERS[$1]}
			database=$2
			if [ ! -d "$db${FOLDERS[$1]}" ]; then
				mkdir $db${FOLDERS[$1]}
			fi
			cd $db${FOLDERS[$1]}	
			clone_view $3
			cd ..
		fi
	done
}

#
# push 
# expects the following parameters
# $1 - destination servere where to push to
# $2 - database name
# $3 - view name, expected format: "_design/[nume]", does not support [all]
# please respect the folder and file structure
#
push()
{
	echo "Database: $2, view: $3"
	for db in "${DATABASES[@]}"
	do
		if [ "$2" = "$db" ]; then
		server=${SERVERS[$1]}
		database=$2
		if [ ! -d "$db${FOLDERS[$1]}" ]; then
			mkdir $db${FOLDERS[$1]}
		fi
		cd $db${FOLDERS[$1]}
		push_view $3
		cd ..
		fi
	done
}

#
# deploy 
# expects the following parameters
# $1 - source server
# $2 - destination server
# all design documents are cloned from source database to destination database
#
deploy()
{
	if [ "$1" = "$2" ]; then
		echo "Source server must be different from destination server !!!"
		usage
	else
		for db in "${DATABASES[@]}"
		do
			rm -rf $db${FOLDERS[$1]}
			mkdir $db${FOLDERS[$1]}
			clone $1 $db all
			rm -rf $db${FOLDERS[$2]}
			mkdir $db${FOLDERS[$2]}
		done
		for db in "${DATABASES[@]}"
		do
			cp -r $db${FOLDERS[$1]}/. $db${FOLDERS[$2]}
			push $2 $db all												
		done
	fi
}

#
# copy 
# expects the following parameters
# $1 - source server to copy from
# $2 - destination server to copy to
# $3 - database name
# $4 - view name, expected format: "_design/[nume]", does not support [all]
# used to copy a new view from the source server to the destination server
# note the databases have the same names 
#
copy()
{
	if [ "$1" = "$2" ]; then
		echo "Source server must be different from destination server !!!"
		usage
	else
		for db in "${DATABASES[@]}"
		do
			if [ "$3" = "$db" ]; then	
				if [ -d ./$db${FOLDERS[$1]}/$4 ]; then
					rm -rf ./$db${FOLDERS[$1]}/$4
					mkdir ./$db${FOLDERS[$1]}/$4
				fi
				clone $1 $db $4
				if [ -d ./$db${FOLDERS[$2]}/$4 ]; then
					rm -rf ./$db${FOLDERS[$2]}/$4
					mkdir ./$db${FOLDERS[$2]}/$4
				fi			
			fi
		done	
		for db in "${DATABASES[@]}"
		do
			if [ "$3" = "$db" ]; then
				cp -r ./$db${FOLDERS[$1]}/$4/. ./$db${FOLDERS[$2]}/$4
				push $2 $db $4
			fi
		done	
	fi
}

###############
# Main script #
###############

if [ $# -lt 3 ]; then
	usage
	exit 0
fi
#echo $1, $2, $3, $4

case $1 in
	"clone")  clone $2 $3 $4 ;;
	"push")   push $2 $3 $4	;;
	"deploy") deploy $2 $3	;;
	"copy")   copy $2 $3 $4 $5 ;;
	*)      echo "unknown command: $1"
			usage ;;
esac
exit 0

######################
# End of main script #
######################
