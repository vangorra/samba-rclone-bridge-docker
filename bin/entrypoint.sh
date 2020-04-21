#!/usr/bin/env bash
set -e

DEFAULT_SHARE_USERNAME="files"
DEFAULT_SHARE_PASSWORD="FrogsHouseLight"
DEFAULT_SHARE_NAME="files"
DEFAULT_HOSTNAME="files"

function errorMsg() {
  echo "ERROR: $@"
}

function coalesce() {
  if [[ -n "$1" ]]; then
    echo "$1"
  elif [[ -n "$2" ]]; then
    echo "$2"
  fi
}

function showUsage() {
  cat << EOF
usage:
  -d|--destination  The destination to copy the files. (required)
  -u|--username     Username for the share. (Default: $DEFAULT_SHARE_USERNAME)
  -p|--password     Password for the share. (Default: $DEFAULT_SHARE_PASSWORD)
  -s|--share        Share name. (Default: $DEFAULT_SHARE_NAME)
  -n|--name         Name of server. (Default $DEFAULT_HOSTNAME)
EOF
}

while [[ "$#" -gt 0 ]]
do
  key="$1"
  case "$key" in
    -d|--destination)
      RCLONE_DESTINATION="$2"
      shift
      shift
    ;;
    -u|--username)
      SHARE_USERNAME="$2"
      shift
      shift
    ;;
    -p|--password)
      SHARE_PASSWORD="$2"
      shift
      shift
    ;;
    -s|--share)
      SHARE_NAME="$2"
      shift
      shift
    ;;
    -n|--name)
      HOSTNAME="$2"
      shift
      shift
    ;;
    -h|--help|-help)
      showUsage
      exit
      shift
      shift
    ;;
    *)
      shift # past argument
    ;;
  esac
done

SHARE_USERNAME=$(coalesce "$SHARE_USERNAME" "$DEFAULT_SHARE_USERNAME")
SHARE_PASSWORD=$(coalesce "$SHARE_PASSWORD" "$DEFAULT_SHARE_PASSWORD")
SHARE_NAME=$(coalesce "$SHARE_NAME" "$DEFAULT_SHARE_NAME")
HOSTNAME=$(coalesce "$HOSTNAME" "$DEFAULT_HOSTNAME")
HOST_UID=$(ls -n /config/rclone.conf | sed -E 's/ +/ /g' | cut -d' ' -f3)
HOST_GID=$(ls -n /config/rclone.conf | sed -E 's/ +/ /g' | cut -d' ' -f4)

echo ""
echo "Setting up"
echo "Config:"
cat << EOF
RCLONE_DESTINATION: $RCLONE_DESTINATION
SHARE_USERNAME: $SHARE_USERNAME
SHARE_PASSWORD: $SHARE_PASSWORD
SHARE_NAME: $SHARE_NAME
HOSTNAME: $HOSTNAME
EOF

echo "Generating hostname file"
echo "$HOSTNAME" > /etc/hostname

echo "Generating samba config"
cat /config-base/smb.conf | \
  sed -E "s/HOSTNAME/$HOSTNAME/g" | \
  sed -E "s/SHARE_NAME/$SHARE_NAME/g" | \
  sed -E "s/SHARE_USERNAME/$SHARE_USERNAME/g" > /etc/samba/smb.conf

echo "Creating local user to match owner of rclone.conf with UID: $HOST_UID and GID: $HOST_GID."
addgroup -g "$HOST_GID" "$SHARE_USERNAME"
adduser -D -H -G "$SHARE_USERNAME" -s /bin/false -u "$HOST_UID" "$SHARE_USERNAME"

echo "Setting samba password"
echo -e "${SHARE_PASSWORD}\n${SHARE_PASSWORD}" | smbpasswd -a -s -c /etc/samba/smb.conf "$SHARE_USERNAME"

echo "Creating /files and setting permissions"
mkdir -p /files
chown -R "$HOST_UID:$HOST_GID" /files
chmod -R 755 /files

echo ""
echo "Starting supervisord"
supervisord --configuration /etc/supervisord.conf

echo ""
echo "Starting files monitor."
/usr/local/bin/monitor_files.sh --destination "$RCLONE_DESTINATION" --unique-filenames
