#!/bin/bash

RETRY_COUNT="6"
echo `date`
echo "Watching /files for changes."
inotifywait -q --monitor --event close_write,moved_to --format '%w%f' "/files/" | while read FILE_PATH
do
  if ! [[ -f "$FILE_PATH" ]]; then
    continue
  fi

  for i in $(seq 1 "$RETRY_COUNT")
  do
    echo "($i/$RETRY_COUNT) Copying '$FILE_PATH' to '$RCLONE_DESTINATION'"
    rclone --retries 1 --config /config/rclone.conf copy "$FILE_PATH" "$RCLONE_DESTINATION"
    if [[ "$?" = "0" ]]; then
      echo "Copy successful, removing temp file."
      rm "$FILE_PATH"
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
