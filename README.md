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
