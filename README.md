# Push2Couch
Push to Couch `push2couch.sh` is a script that allows you to push a flat structure of folders and subfolders into CouchDB as design documents.
The script has the following input arguments:

```
--protocol CouchDB server protocol. Default http
--server   CouchDB server name or IP address. Default localhost
--port     CouchDB server port. Default 5984
--user     CouchDB user name
--password CouchDB password	
--db       Database name, it must exists. Mandatory argument
--help     Display help message
```

The argument for database name `--db` must be supplied. This folder contains the database structure. Each subfolder in the database folder 
represnts the name of a desing document. Like in the schema bellow:

```
	test_db
	      |_ app
	      |_ fullddoc
```

This means that we may upload into `test_db` database the following design documents: `_design/app`, `_design/fullddoc`.
The script will delete them if they already exists in the database.

Inside each folder representing a design document the following subforder structure may exists:

```
	test_db
	      |_ app
		|_ attachments
			|... [JS CouchApp]
			|... [source files]
		|_ ddoc.json	      
```

All documents found in `attachments` folder will be attached to the design document. The JSON structure in `ddoc.json` will be loaded as such and replace the existing structrure of the desing document. The structure of the JSON file is:
```json
{
	"language": "javascript",
	"views":{
		"viewName":{
			"map":"function(doc){ ... }",
			"reduce":"function(){ ... }"
		},
		"lib":{
			"libName":"function nametoExport(){ ... } 
			exports['libName'] = nameToExport"
		}
	},
	"lists":{
		"listName":"function(head, req){ ... }"
	},
	"updates":{
		"updateName":"function(doc, req){ ... }"
	},
	"shows":{
		"showName":"function(doc, req){ ... }"
	},
	"filters":{
		"filterName":"function(doc, req){ ... }"
	},
	"full_text":{
		"indexName":{
			"index":"function(doc){ ... }"
		}
	},
	"rewrites": [
		{
			"to":"",
			"from":"",
			"method":"",
			"query":{}

		} 
	],
	"validate_doc_update":"function(newDoc, oldDoc, userCtx){ ... }"
}
```

# p2c
Is the light version of Push 2 Couch and deals with the attachments only. Please use `push2couch.sh` instead.

# couchapp-wrapper
A wrapper for couchapp to sync CouchDB ddoc back and forth with local repository. This script has a lot of hardcoded names, ports, protocol and has to be adapted for particular usage.  

Help needed from comunity!