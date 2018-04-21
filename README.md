# samba-rclone-bridge-docker
This container will create a windows network share and move all new files to a cloud provider.

Many high end printers have a scanner. Many of these printers also have a feature to scan to a local network share. 
Such a feature is useful but a bit dated in a cloud-centric world. This container helps to bridge the gap. 
Configure rclone, launch the container, then configure your printer to scan to the share.

## Quickstart
- Get and configure rclone for your preferred cloud provider.
- Launch the container
```
docker run \
  --name scanbridge \
  --publish 137-139:137-139 \
  --publish 445:445 \
  --volume /path/to/rclone/config/dir:/config \
  vangorra/samba-rclone-bridge-docker \
  --destination GoogleDrive:Scanned
```
- Configure your printer to scan to \\machine_ip\files.
  - username: files
  - password: FrogsHouseLight
  
## Usage
```
usage:
  -d|--destination  The destination to copy the files. (required)
  -u|--username     Username for the share. (Default: files)
  -p|--password     Password for the share. (Default: FrogsHouseLight)
  -s|--share        Share name. (Default: files)
  -n|--name         Name of server. (Default files)
```
