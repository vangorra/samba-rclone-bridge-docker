FROM alpine:3.7

RUN apk --no-progress update && \
	apk --no-cache add samba bash inotify-tools supervisor ca-certificates && \
	apk --no-cache add --virtual=build-dependencies wget curl unzip && \
	wget -o rclone.zip https://downloads.rclone.org/v1.40/rclone-v1.40-linux-386.zip && \
	unzip rclone-v1.40-linux-386.zip && \
	cp rclone-v1.40-linux-386/rclone /usr/local/bin/rclone && \
	rm -rf rclone-v1.40-linux-386 && \
	rm rclone-v1.40-linux-386.zip && \
	apk del --purge build-dependencies

COPY config-base/* /config-base/
COPY bin/* /usr/local/bin/

# exposes samba's default ports (137, 138 for nmbd and 139, 445 for smbd)
EXPOSE 137/udp 138/udp 139 445

ENTRYPOINT ["entrypoint.sh"]
