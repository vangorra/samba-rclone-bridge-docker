#!/bin/bash

# Strip slashes at end of rclone dest.
RCLONE_FILE_HASH_LENGTH="4"
RETRY_COUNT="6"
BASE_STAGING_DIR="/tmp/monitor_files_staging"

echo `date`
echo "Watching /files for changes."
inotifywait -q --monitor --event close_write,moved_to --format '%w%f' "/files/" | while read FILE_PATH
do
  if ! [[ -f "$FILE_PATH" ]]; then
    continue
  fi

  echo ""
  echo "File creation detected."
  for i in $(seq 1 "$RETRY_COUNT")
  do
    echo "Attempting copy $i of $RETRY_COUNT"

    FILE_HASH=$(md5sum "$FILE_PATH" | cut -d ' ' -f1 | head -c "$RCLONE_FILE_HASH_LENGTH")
    FILE_EXT=$(basename "$FILE_PATH" | sed -E 's/.*\.([a-zA-Z0-9]+)$/\1/')
    FILE_NAME=$(basename "$FILE_PATH" | sed -E 's/\.[a-zA-Z0-9]+$//')
    STAGING_DIR="$BASE_STAGING_DIR/$FILE_HASH"
    STAGING_FILE_PATH="$STAGING_DIR/$FILE_NAME.$FILE_HASH.$FILE_EXT"

    echo "Copying '$FILE_PATH' to staging '$STAGING_FILE_PATH'."
    mkdir -p "$STAGING_DIR"
    cp "$FILE_PATH" "$STAGING_FILE_PATH"

    echo "Copying '$STAGING_FILE_PATH' to '$RCLONE_DESTINATION'"
    rclone --retries 1 --config /config/rclone.conf copy "$STAGING_FILE_PATH" "$RCLONE_DESTINATION"
    if [[ "$?" = "0" ]]; then
      echo "Copy successful, removing temp files."
      rm "$FILE_PATH"
      rm -rf "$STAGING_DIR"
      break;
    fi

    if [[ "$i" < "$RETRY_COUNT" ]]; then
      echo "Copy failed, retrying in 5 seconds."
      sleep 5
    else
      echo "Copy failed. Will not retry."
    fi
   done
done
