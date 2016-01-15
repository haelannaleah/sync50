#!/bin/bash
# sync50
# a wrapper for copy.com
#
# by Annaleah Ernst
# jterm 2016
# annaleahernst@college.harvard.edu

############### BEGIN GLOBAL AND CONSTANT DECLARATIONS #########################

set -uo pipefail
IFS=$'\n\t'

# important cloud paths
readonly CLDWKSPCS="workspaces"
readonly CLDUSERS="$CLDWKSPCS/${C9_USER}"
readonly CLDPRJCT="$CLDUSERS/${C9_PROJECT}"

# important local paths
readonly WORKDIR="${HOME}/workspace/bash_prac"   # TODO: address to workspace
readonly COPYLOC="${HOME}/copy"                  # location of the copy folder
readonly DOTCOPY="${HOME}/.copy"                 # location of the metadata
readonly STATUSFILE="$DOTCOPY/status.txt"        # location of status data
readonly WATCHPID="$DOTCOPY/watchPID.txt"        # location of process id for running watch daemon
readonly SYNCDIR="$DOTCOPY/userdata"             # root directory of copy.com data
readonly SYMLINKDIR="$SYNCDIR/$CLDUSERS"         # directory containing symlink
readonly SYMLINK="$SYMLINKDIR/${C9_PROJECT}"     # symlink to workspace

# the copy.com cli that we're wrapping
readonly COPYCMD="$COPYLOC/x86_64/CopyCmd"           
readonly COPYCONSOLE="$COPYLOC/x86_64/CopyConsole"

# status messages
STATUS=""
readonly INVALIDLOGN="Incorrect username or password"
readonly MISSLOGIN="Missing Login Information"
readonly NOTINSTALLED="Sync50 has not been installed. Type 'sync50 start' to begin setup."
readonly NOWATCH="No watch running"

# process variables; name, ID
readonly PROCESSNAME="CopyConsole"
PID=$(ps -ef | grep "$PROCESSNAME" | grep -v grep | awk '{print $2}')
readonly TIMEOUT=5       # process times out after this many seconds

# messages
readonly STARTSUCCESS="Syncing started successfully!"
readonly STARTFAILURE="Unable to start sync50 at this time."
readonly STOPSUCCESS="Syncing stopped."
readonly STOPFAILURE="Unable to stop sync50 at this time."

# misc regexs (don't panic)
readonly EXREGEX='s/^\///gm'                                # for listing excludes
readonly LSREGEX='s/^d.[ \t\f\v]*|^-.[ \t\f\v]*(\S* )//gm'  # for listing files

################## BEGIN FUNCTION DEFINITIONS ##################################


deleteExcludes(){
    delete_helper(){
        for file in $(ls "$1"); do
            if [ "$file" != "$2" ]; then
                rm -rf "$1/$file"
            fi
        done
    }
    delete_helper "$SYNCDIR" "$CLDWKSPCS"
    delete_helper "$SYNCDIR/$CLDWKSPCS" "${C9_USER}"
    delete_helper "$SYNCDIR/$CLDUSERS" "${C9_PROJECT}"
}

# climb through file tree and exlude all files not in project to prevent bricking IDE
# usage: exclude [FILE/FOLDER TO KEEP] [PATH TO CURRENT DIR]
exclude(){
    exclude_helper(){
        dir=""
        path=""
        # get stripped down file/directory names
        if [ $# = 2 ]; then
            # starting at 3rd line of search results; first line is metadata, 2nd is pwd
            dir=$($COPYCMD Cloud ls "$2" | sed -r "$LSREGEX" | tail -n +3)
            path="$2/"
        else
            # starting at 2nd line of search results; first is metadata
            dir=$($COPYCMD Cloud ls | sed -r "$LSREGEX" | tail -n +2)
        fi
        echo "$dir" | while read file; do
            if [ "$file" != "$1" ]; then
                echo -n "... "
                $COPYCMD Cloud exclude -exclude "$path$file" > /dev/null
            fi
        done
    }
    # exclude files in each sub directory of our workspaces tree
    exclude_helper "$CLDWKSPCS"
    exclude_helper "${C9_USER}" "$CLDWKSPCS"
    exclude_helper "${C9_PROJECT}" "$CLDUSERS"
    echo
}

# displays information on the usage of this wrapper
help(){
    echo "Usage: sync50 [FUNCTION]"
    echo "Functions:"
    echo -e "\tstart\t\tstart copy.com syncing, or install if first run"
    echo -e "\tstop\t\tstop Copy.com syncing"
    echo -e "\tuninstall\t\tremove Copy.com files"
}

# installs the copy.com binaries for the first time
install(){
    if [ ! -e "$COPYCMD" ]; then
        echo "Downloading Copy...."; echo -n "... "
        wget -q -O - "https://copy.com/install/linux/Copy.tgz" |  tar xzf - > /dev/null; echo -n "... "
        sudo apt-get install inotify-tools > /dev/null
        echo -n "..."; echo
        
        # make the metadata folder if copy.com was lazy
        if [ ! -e "$STATUSFILE" ]; then
            mkdir -p "$DOTCOPY"
            echo -n "$MISSLOGIN" > "$STATUSFILE"
        fi
        echo "$NOWATCH" > "$WATCHPID"
        
        # create root dir for the cloud and link to current workspace 
        mkdir -p "$SYMLINKDIR"  
        ln -s "$WORKDIR" "$SYMLINK" 
        
        echo "Download complete."
    else 
        echo "Already installed."
    fi
    start
}

# log in to copy.com after install
login(){
    echo -n "Do you already have a Copy.com account? [y/N]: "; read prompt
    if [[ "$prompt" =~ [yY](es)* ]]; then
        echo "To setup Copy.com and backup your workspace, please enter your account information."
        echo -n "email address: "; read email
        echo -n "password: "; read -s pswrd; echo
        echo "Checking..."
        [ -z $pswrd ] && echo "$INVALIDLOGN" && exit    # check for null password
        
        # attempt to login user
        #$COPYCONSOLE -daemon -u="$email" -p="$pswrd" -r="$SYNCDIR" > /dev/null
        $COPYCONSOLE -daemon -u="annaleahernst@college.harvard.edu" -p="abc123ABC" -r="$SYNCDIR" > /dev/null
        process "init"
    else
        echo "Before completing setup, you need a copy.com account."
        echo "Please proceed to https://www.copy.com and create an account. Exiting..."
    fi
}

# handles current CopyConsole daemon process
# arguments: [start|stop|init]
# start: PID starts as "". Run until PID changes to a value or timeout, report success or failure
# stop: PID starts as a value. Run until PID changes to "" or timeout, report success or failure
# init: PID starts as "". Run until PID changes to a value, report failure or if successful...
#       immediately run stop to prevent syncing. Run exlcude on the cloud file tree. Finally,
#       run start to begin syncing.
process(){
    currentPID=$PID
    counter=0
    # until there's a process id state change or we run out of time, search for process
    until [ "$currentPID" != "$PID" ] || [ $counter = $TIMEOUT ]; do
        echo -n "... "
        sleep 1
        currentPID=$(ps -ef | grep "$PROCESSNAME" | grep -v grep | awk '{print $2}')
        let counter+=1
    done; echo
    PID="$currentPID" # update current PID
    
    case "$1" in
        "start")
            # if there's a process, echo succcess, else failure
            [[ -n "$currentPID" ]] && echo "$STARTSUCCESS" || echo "$STARTFAILURE"
            ;;
        "stop")
            # if there's not a process, echo succcess, else failure
            [[ -z "$currentPID" ]] && echo "$STOPSUCCESS" || echo "$STOPFAILURE"
            ;;
        "init")
            if [ -z "$currentPID" ]; then
                # if there's not a process running, there was an error
                status
                echo "$STATUS. Exiting..." 
                exit 
            else
                # stop syncing and handle excludes
                stop > /dev/null
                echo "Setup successful. Beginning exclusions. This may take a few minutes..."
                exclude
                echo "Exclusions complete."
                start
            fi
            ;;
        *)
            ;;
    esac
}

# set current status
status(){
    if [ -e "$STATUSFILE" ]; then
        STATUS="$(head -n 1 $STATUSFILE)"
    else
        STATUS="$NOTINSTALLED"
    fi
}

# start copy
start(){
    status  # get status
    if [ ! -e "$COPYLOC" ]; then
        install
    elif [ "$STATUS"  = "$MISSLOGIN" ] || [ "$STATUS"  = "$INVALIDLOGN" ]; then
        echo "Account not setup."
        login
    elif [ -z "$PID" ]; then
        echo "Starting..."
        
        # begin watching directories of interest for unwanted changes and store process id
        inotifywait "@$SYNCDIR/$CLDPRJCT" "$SYNCDIR" "$SYNCDIR/$CLDWKSPCS" "$SYNCDIR/$CLDUSERS" \
            -e move,create & echo $! > "$WATCHPID"
            
        # start copy daemon
        $COPYCONSOLE -daemon > /dev/null    
        process "start"
    else
        echo "Sync50 is already running!"
    fi
}

# stop syncing
stop(){
    if [ -n "$PID" ]; then
        echo "Stopping..."
        kill $(head -n 1 $WATCHPID); echo "$NOWATCH" > "$WATCHPID" # remove watch
        kill $PID
        process "stop"
    else
        echo "Sync50 is not running!"
    fi
}

# (safely) uninstall copy
uninstall(){
    if [ -e $COPYCMD ]; then
        echo -n "Are you sure you want to uninstall Copy? [y/N]: "; read prompt
        if [[ "$prompt" =~ [yY](es)* ]]; then 
            echo "Uninstalling..."; echo -n "... "
            stop > /dev/null
            unlink "$SYMLINK"; echo -n "... "
            rm -rf "$COPYLOC"; echo -n "... "
            rm -rf "$DOTCOPY"; echo
            echo "Copy has been uninstalled."
        fi
    else 
        echo "Copy is not installed!"
    fi
}


######################### BEGIN BODY OF PROGRAM ##############################

pushd ${HOME} >/dev/null

if [ $# != 1 ]; then
    help
    exit
fi

case "$1" in
    "help")
        help
        ;;
    "start")
        start
        ;;
    "status")
        status
        echo "$STATUS"
        ;;
    "stop")
        stop
        ;;
    "uninstall")
        uninstall
        ;;
    "--delete_local_excludes")
        stop
        exclude && deleteExcludes
        start
        ;;
    *)
        echo "sync50: unrecognized option '$1'"
        echo "Usage: sync50 [start|stop|status|uninstall]"
        echo "Try 'sync50 help' for more information."
        ;;
esac
exit

# cloudFiles=`$COPYCMD Cloud ls | sed -r 's/^d.[ \t\f\v]*|^-.[ \t\f\v]*(\S* )//gm' | tail -n +2`

# excludeFiles=`$COPYCMD Cloud exclude -list | sed -r 's/^\///gm' | tail -n +3`