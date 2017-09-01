# couchapp-wrapper
A wrapper for couchapp to sync CouchDB ddoc back and forthe with local repository

# Push2Couch
Pushc to Couch is a script that allows you to push a flat structure of folders and subfolders into CouchDB as design documents.
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
	      |_ user_views
	      |_ complete_ddoc
```

This means that we may upload into `test_db` database the following design documents: `_design/app`, `_design/user_views`, `_design/complete_ddoc`.
The script will delete them if they already exists in the database.

Inside each folder representing a design document the following subforder structure may exists:

```
	test_db
	      |_ app
			|_ attachments
				|... [JS CouchApp]
				|... [source files]

			|_ views
				|_ lib
					|_ lib_name
						|_ lib_export_module.js
				|_ view_name
					|_ map.js
					|_ reduce.js

			|_ lists
				|_ list_function.js

			|_ shows
				|_ show_function.js

			|_ updates
				|_ update_function.js

			|_ filters
				|_ filter_function.js

			|_ full_text
				|_ index_name
					|_ index.js

			|_ rewrites.js
			|_ validate_doc_update.js
	      
```

Each subfolder will be mapped to an attribute of the design document or will attach files to that design document.
