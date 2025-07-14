#!/bin/sh
docker buildx build 31/fpm    --platform linux/arm64  -t trajano/nextcloud-custom:fpm --load
docker buildx build 31/apache    --platform linux/arm64  -t trajano/nextcloud-custom:apache --load