### Automatically Update Tailscale on the Synology NAS platform

# Description

This script automatically updats Tailscale on Synology NAS from the Tailscale website

### 1. Save the Script to Your NAS

Download the script and place it into a location of your choosing. As an example, if you are using the "`admin`" account for system administration tasks, you can place the script within that accounts home folder; such as in a nested directory location like this:

    /home/scripts/bash/tailscale/syno.tailscaleupdate/update_tailscale.sh

-or-

    /homes/admin/scripts/bash/tailscale/syno.tailscaleupdate/update_tailscale.sh

### 2. Setup a Scheduled Task in the DSM

1. Open the [DSM](https://www.synology.com/en-global/knowledgebase/DSM/help) web interface
1. Open the [Control Panel](https://www.synology.com/en-global/knowledgebase/DSM/help/DSM/AdminCenter/ControlPanel_desc)
1. Open [Task Scheduler](https://www.synology.com/en-global/knowledgebase/DSM/help/DSM/AdminCenter/system_taskscheduler)
   1. Click Create -> Scheduled Task -> User-defined script
   1. Enter Task: name as '`Syno.Tailscale Update`', and leave User: set to '`root`'
   1. Click Schedule tab and configure per your requirements
   1. Click Task Settings tab
   1. Enter 'User-defined script' similar to:
   '`bash /home/scripts/bash/tailscale/syno.tailscaleupdate/update_tailscale.sh`'
   ...if using the above script placement example. '`/volume1`' is the default storage volume on a Synology NAS. You can determine your script directory's full pathname by looking at the Location properties of the folder with the [File Station](https://www.synology.com/en-global/knowledgebase/DSM/help/FileStation/FileBrowser_desc) tool in the DSM:
      1. Right-click on the folder containing the script and choose Properties
      1. Copy the full directory path from the Location field
1. Click OK
