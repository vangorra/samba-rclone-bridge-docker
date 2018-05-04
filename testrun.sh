#!/usr/bin/env bash
set -e

function showUsage() {
  cat <<EOF
usage: testrun.sh <config dir> <rclone destination>

EOF
}

CONFIG_DIR="$1"
RCLONE_DESTINATION="$2"
IMAGE_NAME="samba-rclone-bridge-docker"
CONTAINER_NAME="samba-rclone-bridge-docker"

if [[ -z "$CONFIG_DIR" ]]; then
  echo "Error: config directory required."
  showUsage
  exit 1
fi

if ! [[ -e "$CONFIG_DIR" ]]; then
  echo "Error '$CONFIG_DIR' does not exist."
  showUsage
  exit 1
fi

if ! [[ -d "$CONFIG_DIR" ]]; then
  echo "Error: '$CONFIG_DIR' is not a directory."
  showUsage
  exit 1
fi

if [[ -z "$RCLONE_DESTINATION" ]]; then
  echo "Error: Must provide an rclone destination."
  showUsage
  exit 1
fi

echo "Stopping and removing existing container"
docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.ID}}" | xargs -r docker rm -f

echo "Building container"
docker build --tag "$IMAGE_NAME" .

echo "Starting new container."
docker run \
  --tty \
  --interactive \
  --name "$CONTAINER_NAME" \
  --publish 137-139:137-139 \
  --publish 445:445 \
  --volume "$CONFIG_DIR:/config" \
  "$IMAGE_NAME" \
  --destination "$RCLONE_DESTINATION" \
  --username testuser \
  --password testpass \
  --share test

echo "Stopping and removing existing container"
docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.ID}}" | xargs -r docker rm -f
