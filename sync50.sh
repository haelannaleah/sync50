#!/bin/bash
# sync50
# a wrapper for copy.com
#
# by Annaleah Ernst
# jterm 2016
# annaleahernst@college.harvard.edu


# important cloud paths
readonly CLDWKSPCS="workspaces"
readonly CLDUSERS="$CLDWKSPCS/${C9_USER}"
readonly CLDPRJCT="$CLDUSERS/${C9_PROJECT}"

# important local paths
readonly WORKDIR="${HOME}/workspace/bash_prac2"  # TODO: address to workspace
readonly COPYLOC="${HOME}/copy"                  # location of the copy folder
readonly DOTCOPY="${HOME}/.copy"                 # location of the metadata
readonly STATUSFILE="$DOTCOPY/status.txt"        # location of status data
readonly SYNCDIR="$COPYLOC/userdata"             # root directory of copy.com data
readonly SYMLINKDIR="$SYNCDIR/$CLDUSERS"         # directory containing symlink
readonly SYMLINK="$SYMLINKDIR/${C9_PROJECT}"     # symlink to workspace

# the copy.com cli that we're wrapping
readonly COPYCMD="$COPYLOC/x86_64/CopyCmd"           
readonly COPYCONSOLE="$COPYLOC/x86_64/CopyConsole"

# status
STATUS=""
readonly MISSLOGIN="Missing Login Information"
readonly INVALIDLOGN="Incorrect username or password"
readonly NOTINSTALLED="Sync50 has not been installed. Type 'sync50 start' to begin setup."

# process variables; name, ID
readonly PROCESSNAME="CopyConsole"
PID=`ps -ef | grep "$PROCESSNAME" | grep -v grep | awk '{print $2}'`
readonly TIMEOUT=5       # process times out after this many seconds

# messages
readonly STARTSUCCESS="Syncing started successfully!"
readonly STARTFAILURE="Unable to start sync50 at this time."
readonly STOPSUCCESS="Syncing stopped."
readonly STOPFAILURE="Unable to stop sync50 at this time."

# misc regexs
readonly LSREGEX='s/^d.[ \t\f\v]*|^-.[ \t\f\v]*(\S* )//gm'  # for listing files
readonly EXREGEX='s/^\///gm'                                # for listing excludes

# displays information on the usage of this wrapper
help(){
    echo "Usage: sync50 [FUNCTION]"
    echo "Functions:"
    echo -e "\tinstall\t\tinstall copy.com binaries and set up account"
    echo -e "\tstart\t\tstart copy.com syncing, or install if first run"
    echo -e "\tstop\t\tstop copy.com syncing"
}

# installs the copy.com binaries for the first time
install(){
    if [ ! -e "$COPYCMD" ]; then
        echo "Downloading Copy...."
        wget -q -O - "https://copy.com/install/linux/Copy.tgz" |  tar xzf -
        
        # make the metadata folder if copy.com was lazy
        if [ ! -e "$STATUSFILE" ]; then
            mkdir -p "$DOTCOPY"
            echo "$MISSLOGIN" > "$STATUSFILE"
        fi
        
        # create cloud root dir and link to current workspace 
        mkdir -p "$SYMLINKDIR"  
        ln -s "$WORKDIR" "$SYMLINK" 
        
        echo "Download complete."
    else 
        echo "Already installed."
    fi
    start
}


# climb through file tree and exlude all files not in project to prevent bricking IDE
# usage: exclude PROTECTED PATH
exclude(){
    dir=""
    path=""
    if [ $# = 2 ]; then
         dir=`$COPYCMD Cloud ls "$2" | sed -r "$LSREGEX" | tail -n +3`
         path="$2/"
    else
        dir=`$COPYCMD Cloud ls | sed -r "$LSREGEX" | tail -n +2`
    fi
    echo "$dir" | while read file; do
        echo -n "... "
        if [ "$file" != "$1" ]; then
            $COPYCMD Cloud exclude -exclude "$path$file" > /dev/null
        fi
    done
}

# log in to copy.com after install
login(){
    echo -n "Do you already have a Copy.com account? [y/N]: "; read prompt
    if [[ "$prompt" =~ [yY](es)* ]]; then
        echo "To setup copy.com and backup your workspace, please enter your account information."
        echo -n "email address: "; read email
        echo -n "password: "; read -s pswrd; echo
        echo "Checking..."
        [ -z $pswrd ] && echo "$INVALIDLOGN" && exit    # check for null password
        
        # attempt to login user
        $COPYCONSOLE -daemon -u="$email" -p="$pswrd" -r="$SYNCDIR" > /dev/null
        #$COPYCONSOLE -daemon -u="annaleahernst@college.harvard.edu" -p="abc123ABC" -r="$SYNCDIR" > /dev/null
        process "init"
    else
        echo "Before proceeding with setup, you need a copy.com account."
        echo "Please proceed to https://www.copy.com and create an account. Exiting..."
    fi
}

# handles current CopyConsole process
# arguments: [start|stop|init]
# start: check if 
process(){
    CURRENTPID=$PID
    COUNTER=0
    # until there's a process id state change or we run out of time, search for process
    until [ "$CURRENTPID" != "$PID" ] || [ $COUNTER = $TIMEOUT ]; do
        echo -n "... "
        sleep 1
        CURRENTPID=`ps -ef | grep "$PROCESSNAME" | grep -v grep | awk '{print $2}'`
        let COUNTER+=1
    done; echo
    PID="$CURRENTPID" # update current PID
    
    case "$1" in
        "start")
            # if there's a process, echo succcess, else failure
            [[ -n "$CURRENTPID" ]] && echo "$STARTSUCCESS" || echo "$STARTFAILURE"
            ;;
        "stop")
            # if there's not a process, echo succcess, else failure
            [[ -z "$CURRENTPID" ]] && echo "$STOPSUCCESS" || echo "$STOPFAILURE"
            ;;
        "init")
            if [ -z "$CURRENTPID" ]; then
                # if there's not a process running, there was an error
                status
                echo "$STATUS. Exiting..." 
                exit 
            else
                # stop syncing and handle excludes
                stop > /dev/null
                echo "Setup successful. Beginning excludes. This may take a few minutes..."
                
                # exclude files in each sub directory
                exclude "$CLDWKSPCS"
                exclude "${C9_USER}" "$CLDWKSPCS"
                exclude "${C9_PROJECT}" "$CLDUSERS"
                echo
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
        $COPYCONSOLE -daemon > /dev/null    # start copy daemon
        process "start"
    else
        echo "Sync50 is already running!"
    fi
}

# stop syncing
stop(){
    if [ -n "$PID" ]; then
        echo "Stopping..."
        kill $PID
        process "stop"
    else
        echo "Sync50 is not running!"
    fi
}

# uninstall copy
uninstall(){
    stop
    unlink "$SYMLINK"
    rm -rf "$COPYLOC"
    rm -rf "$DOTCOPY"
    echo "Copy has been uninstalled."
}

pushd ${HOME} >/dev/null

if [ $# != 1 ]; then
    help
    exit
fi

case "$1" in
    "--help")
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
    *)
        echo "sync50: unrecognized option '$1'"
        echo "Usage: sync50 [start|stop|status|uninstall]"
        echo "Try 'sync50 --help' for more information."
        ;;
esac
exit

# directory regex: ^L.*|^d.[ \t\f\v]*|^-.[ \t\f\v]*(\S* ), MULTILINE

# remove the login line, and all non file name lines

# cloudFiles=`$COPYCMD Cloud ls | sed -r 's/^d.[ \t\f\v]*|^-.[ \t\f\v]*(\S* )//gm' | tail -n +2`

# excludeFiles=`$COPYCMD Cloud exclude -list | sed -r 's/^\///gm' | tail -n +3`