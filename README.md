Refresher
===============
Monitors your file-system and hosts a web-page which refreshes when a file-system change is detected, uses WebSocket for this communication. Was built primarily to help ease the workflow when working with luxe.

Example workflow:

	# serves file specified by -i flag, defaults to index.html in current directory.
	# the -r switch specifies which directories to use for serving other things (resources for example) defaults to the same folder
	# as the index.html file is in.
	# the -d switch specifies which directory to watch for changes, currently not recursive.
	# the last command is what to run when a change is detected (build script in this case!).
	racket refresh.rkt -i bin/web/index.html -r bin/web -d src/orb/ ./build.sh
