#!/bin/bash

# important paths
readonly CLDWKSPCS="workspaces"
readonly CLDUSERS="$CLDWKSPCS/${C9_USER}"
readonly CLDPRJCT="$CLDUSERS/${C9_PROJECT}"
readonly DOTCOPY="${HOME}/.copy"                 # location of the metadata
readonly SYNCDIR="$DOTCOPY/userdata"             # root directory of copy.com data
readonly SYNC50PATH=$(pwd)

start(){
    counter=0
    while [ true ]; do
        # begin watching directories of interest for unwanted changes and store process id
        inotifywait "@$SYNCDIR/$CLDPRJCT" "$SYNCDIR" "$SYNCDIR/$CLDWKSPCS" "$SYNCDIR/$CLDUSERS" \
            -e move,create && "$SYNCH50PATH/sync50" "--delete_local_excludes"
        let counter+=1
    done
}


case "$1" in
    "start")
        start
        ;;
    "stop")
        stop
        ;;
    *)
        ;;
esac
exit