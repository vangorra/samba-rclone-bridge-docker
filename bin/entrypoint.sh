#!/usr/bin/env bash
set -e

RCLONE_CONFIG_FILE="/config/rclone.conf"
SHARE_USERNAME="files"
SHARE_PASSWORD="FrogsHouseLight"
SHARE_NAME="files"
HOSTNAME="files"

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
  -u|--username     Username for the share. (Default: $SHARE_USERNAME)
  -p|--password     Password for the share. (Default: $SHARE_PASSWORD)
  -s|--share        Share name. (Default: $SHARE_NAME)
  -n|--name         Name of server. (Default $HOSTNAME)
EOF
}

if ! [[ -e "$RCLONE_CONFIG_FILE" ]]; then
  errorMsg "'$RCLONE_CONFIG_FILE' does not exist. You need to map it with --volume <hostpath to config dir>:/config. Or you need to configure rclone."
  exit 1
fi

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
      SHARE_USERNAME=$(coalesce "$2" "$SHARE_USERNAME")
      shift
      shift
    ;;
    -p|--password)
      SHARE_PASSWORD=$(coalesce "$2" "$SHARE_PASSWORD")
      shift
      shift
    ;;
    -s|--share)
      SHARE_NAME=$(coalesce "$2" "$SHARE_NAME")
      shift
      shift
    ;;
    -n|--name)
      HOSTNAME=$(coalesce "$2" "$HOSTNAME")
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

if [[ -z "$RCLONE_DESTINATION" ]]; then
  errorMsg "Destination was not provided."
  showUsage
  exit 1
fi

# Verify config section in rclone.conf exists for destination provided.
RCLONE_CONFIG_SECTION_NAME=$(echo "$RCLONE_DESTINATION" | sed -E 's/:.*//')
if [[ $(grep -c "\[$RCLONE_CONFIG_SECTION_NAME\]" "$RCLONE_CONFIG_FILE") != "1" ]]; then
  errorMsg "Could not find a config section named '$RCLONE_CONFIG_SECTION_NAME' in rclone.conf."
  exit 1
fi

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

echo "Generating supervisord config"
cat /config-base/supervisord.conf | \
  sed -E "s/SHARE_USERNAME/$SHARE_USERNAME/g" > /etc/supervisord.conf

echo "Creating local user to match owner of rclone.conf with UID: $HOST_UID and GID: $HOST_GID."
addgroup -g "$HOST_GID" "$SHARE_USERNAME"
adduser -D -H -G "$SHARE_USERNAME" -s /bin/false -u "$HOST_UID" "$SHARE_USERNAME"

echo "Creating /files and setting permissions"
mkdir /files
chown -R "$HOST_UID:$HOST_GID" /files
chmod -R 755 /files

echo "Setting samba password"
echo -e "${SHARE_PASSWORD}\n${SHARE_PASSWORD}" | smbpasswd -a -s -c /etc/samba/smb.conf "$SHARE_USERNAME"

echo ""
echo "Starting supervisord"
export RCLONE_DESTINATION
supervisord -c /etc/supervisord.conf
