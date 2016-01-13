#!/bin/bash

COPYBIN=${HOME}/bin/copy
COPYLOC=${HOME}/copy
DOTCOPY=${HOME}/.copy

SETUPDONE="$DOTCOPY"/status.txt
INSTALLDONE="$COPYLOC"

CS50="CS50 IDE"
WORKSPACE="$CS50"/"$WKSPC"

WORKDIR=${HOME}/"$WORKSPACE"
#WORKDIR=${HOME}/workspace/bash_prac

COPYCMND=${HOME}/copy/x86_64/CopyCmd
COPYCONSOLE=${HOME}/copy/x86_64/CopyConsole

MISSLOGIN="Missing Login Information"
INVALIDLOGN="Incorrect username or password"
STATUS=""

PROCESSNAME="CopyConsole"
PID=`ps -ef | grep "$PROCESSNAME" | grep -v grep | awk '{print $2}'`

SLEEPTIME=10

STARTSUCCESS="Syncing started successfully!"
STARTFAILURE="Unable to start sync50 at this time."

STOPSUCCESS="Syncing stopped."
STOPFAILURE="Unable to stop sync50 at this time."

help(){
    echo "Usage: sync50 [FUNCTION]"
    echo "Functions:"
    echo -e "\tinstall\t\tinstall copy.com binaries and set up account"
    echo -e "\tstart\t\tstart copy.com syncing, or install if first run"
    echo -e "\tstop\t\tstop copy.com syncing"
}

install(){
    if [ ! -e "$INSTALLDONE" ]; then
        echo "Downloading Copy...."
        wget -O - "https://copy.com/install/linux/Copy.tgz" |  tar xzf -
        if [ ! -e "$SETUPDONE" ]; then
            mkdir -p "$DOTCOPY"
            echo "$MISSLOGIN" > "$SETUPDONE"
        fi
        echo "Download complete."
    else 
        echo "Already installed."
    fi
    start
}

# checks current processes to make sure the copy daemon started/stopped 
process(){
    CURRENTPID=$PID
    COUNTER=0
    until [ "$CURRENTPID" != "$PID" ] || [ $COUNTER = $SLEEPTIME ]; do
        echo -n "... "
        sleep 1
        CURRENTPID=`ps -ef | grep "$PROCESSNAME" | grep -v grep | awk '{print $2}'`
        let COUNTER+=1
    done; echo
    if [ -n "$CURRENTPID" ]; then
        [[ $1 = "start" ]] && echo "$STARTSUCCESS" || echo "$STOPFAILURE" 
    else
        [[ $1 = "stop" ]] && echo "$STOPSUCCESS" || echo "$STARTFAILURE"
    fi
}

# set current status
status(){
    STATUS="$(head -n 1 $SETUPDONE)"
}

# log in to copy.com
login(){
    echo -n "Do you already have a Copy.com account? [y/N]: "; read prompt
    if [[ "$prompt" =~ [yY](es)* ]]; then
        echo "To setup copy.com and backup your workspace, please enter your account information."
        echo -n "email address: "; read email
        echo -n "password: "; read -s pswrd; echo
        $COPYCONSOLE -daemon -u="$email" -p="$pswrd" -r="$WORKDIR" > /dev/null
        echo "Checking..."
        sleep 2
        status
        echo $STATUS
        if [ "$STATUS"  = "$INVALIDLOGN" ]; then
            exit
        fi
        process "start"
    else
        echo "Before proceeding with setup, you need a copy.com account."
        echo "Please proceed to https://www.copy.com and create an account. Exiting..."
    fi
}

# start copy
start(){
    status
    if [ ! -e "$INSTALLDONE" ]; then
        install
    elif [ "$STATUS"  = "$MISSLOGIN" ] || [ "$STATUS"  = "$INVALIDLOGN" ]; then
        echo "Account not setup."
        login
    elif [ -z "$PID" ]; then
        echo "Starting..."
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
        kill ${PID}
        process "stop"
    else
        echo "Sync50 is not running!"
    fi
}

# uninstall copy
uninstall(){
    rm -rf $COPYLOC
    rm -rf $DOTCOPY
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
        echo "Usage: sync50 [start|stop|uninstall]"
        echo "Try 'sync50 --help' for more information."
        ;;
esac
exit