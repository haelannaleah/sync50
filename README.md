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

# 
