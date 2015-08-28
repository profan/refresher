Refresher
===============
Monitors your file-system and hosts a web-page which refreshes when a file-system change is detected, uses WebSocket for this communication. Was built primarily to help ease the workflow when working with luxe.

Program Flags:
--------------------
 * The ``-i`` flag specifies what index to serve and inject code into, defaults to index.html in current directory.
 * The ``-r`` switch specifies which directories to use for serving other things (resources for example) defaults to the same folder as the index.html file is in.
 * The ``-d`` switch specifies which directory to watch for changes, currently not recursive.The last command is what to run when a change is detected (build script in this case!).

        # flag example usage
        racket refresh.rkt -i bin/web/index.html -r bin/web -d src/orb/ ./build.sh

Simply use -h or --help to get up the help text.
