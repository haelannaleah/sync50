# sync50
Wraps the CLI interface to copy.com for use backing up workspaces with cloud9
TODO: update paths for sync50 and sync50 daemon to reflect their location in bin.

# Usage
1. Esure you have inotify-tools installed (sudo apt-get install -y inotify-tools)
2. Run "sync50 start" to:
    a) install and setup the copy.com binaries (first time use)
    b) login to copy.com (if you were unable to do so in the first step)
    c) start syncing
3. Run "sync50 stop" to stop syncing with the cloud.
4. Run "sync50 status" to get an update on the syncing process.
5. Run "sync50 uninstall" to remove the copy.com binaries and folders. This will
    not damage your workspace data.
6. Run "sync50 help" for a recap of these options.
7. To recover a workspace that has been backed up with sync50, go to your copy.com
    account, workspaces/<user>/<project> and verify that your files are present.
    There are two options for recovery:
    1. Delete your old workspace and create a new one with the same name on the
        same cloud9 account. Download and run sync50. The contents of your old 
        workspace should appear momentarily.
    2. Create a new workspace and run sync50. Navigate to your copy.com account.
        In workspaces/<user>, you should see the new empty workspace folder. Now
        find your old workspace and drag its contents into the new workspace. You
        should see the files appear in your new workspace momentarily.
8. DO NOT muck with the workspaces directory in your copy.com account unless you
    you want those changes reflected in your local workspaces.
**Note: sync50 will only backup files in the workspace part of your cloud9 file
    tree. If you have added files or folders above it in the file hierarchy, they
    will not be saved.**

# About
Sync50 wraps the copy.com command line interface for use with cloud9 workspaces.
It is able to back up multiple workspaces and users on the same copy.com account
and prevents files and folders from outside the current workspace from being 
downloaded, which in turn prevents overfilling the IDE.

# Design

## sync50daemon
Accepts 4 input arguments (currently accepts 5, but should be paired down to 4 when
sync50 is installed in bin). These arguments are: the directory to ignore, and three
directories to watch for changes. This daemon runs in the background until killed,
and triggers when files are created in the parent directories of "<USER>". On trigger,
it calls sync50 --delete_local_excludes, which calls stop, deleteExcludes, excludes,
and start. This is how sync50 is able to dynamically avoid downloading extraneous 
files even after initial install.

## sync50

### check
Checks the exit status of the most recently called function, and if it is non-zero,
stops sync50 and exits.

### deleteExcludes
Locally deletes files that have been unintentionally downloaded from the cloud; ie
new excludes. Because copy.com does not have the ability to whitelist certain files,
this is our best option to prevent the IDE from being bricked if the copy.com user
adds extraneous files or new workspaces.

### exclude
Adds extraneous files to the exclude list. It uses a regex to strip the output of
CopyCmd Cloud ls (listing the files on the cloud) to a usable form. Ex:
    In the directory workspaces
        Logged in as annaleahernst@college.harvard.edu
        dX          workspaces
        dX          users
        -X          test_file.c
        -X          more tests.txt
    is stripped to
        users
        test_file.c
        more tests.txt
Each file or folder that is not supposed to be synced is ignored. The file
hierarchy of the copy.com/cloud9 workspaces should be invariant;
in the copy root directory, exclude everything but "workspaces"
in workspaces, exclude everything but "$USER"
in "<$USER>", exclude everything but "<$PROJECT>"

### help
Display usage information

### install
If not installed, download the copy.com binaries. For some reason, when downloading
the binaries, copy.com does not consistently provide the .copy metadata folder. 
For this reason, if it has not been provided, this program creates it and populates
it with the status file. Copy.com will later add additional metadata and update
the status file, but it must exist, so it is created if necessary.
Additional program metadata is stored in .copy.
We also create a file to store the process ID of the sync50daemon (more later)
and we make the root of the copy.com directory we will sync with.
".copy/userdata" is analogous to the root of copy.com. Inside, we have a folder 
called "workspaces", then a folder called "<USER>", then a folder called "<PROJECT>".
"<PROJECT>" is actually a symlink to "workspace". Thus, we are able to preserve 
an extensive file hierarchy on the cloud without changin user workflow.

### login
Prompts user for login information. If they do not have an account, directs them
to copy.com, else prompts for email and password. Checks for edge case where password
is empty, then attempts to log in the user to the copy.com daemon service and
calling "process init"

### process [start|stop|init]
Handles the copy.com daemon. It takes a little fime for the CopyConsole daemon to
get it's feet on the ground, so in the first part of this function, we wait for
a state change by polling the current process list for "CopyConsole". Once it appears
(or disappears), or times out, we exit the initial polling loop and update $PID.
The following behavior depends on what the input argument was.
    init:
        If there is no process id, then nothing is running and login failed. We 
        alert the user and exit. Else...
        Immediately stop syncing. Call exclude to prevent syncing unwanted files.
        After exclusions are complete, start syncing.
    start:
        If there is a process id, alert success, else failure
    stop:
        If there is not a process id, alert success, else failure

### status
Cat the contents of the status file and store them in $STATUS.

### start
Starts sync50. If the copy.com binaries have not been downloaded, start will begin
the install process. If the status file contains the missing login or invalid login
message, start runs login.
Otherwise, start starts the CopyConsole daemon and the sync50daemon. The CopyConsole
daemon interfaces with copy.com. The sync50daemon prevents new unwanted files from
being downloaded.

### stop
Stops sync50. If there is a CopyConsole process running, kill it. Then, check if
the copy daemon is running and kill it as well. Run "process stop" to verify we 
stopped successfully. Update the status file.

### uninstall
Removes the copy.com binaries (but not sync50). Prompts the user for consent to 
uninstall. Stops the sync50 processes. Unlinks workspace and the copy folders.
Removes the copy and .copy folders and alerts the user copy has been uninstalled.
