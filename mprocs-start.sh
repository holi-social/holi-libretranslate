#!/bin/bash

IMAGE_NAME=holi-libretranslate
CONTAINER_NAME=holi-libretranslate

if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "Image $IMAGE_NAME does not exist. Building the image..."
    docker build -t $IMAGE_NAME --build-arg lang_codes=en,de .
fi

if [[ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]]; then
    docker rm -f $CONTAINER_NAME
fi

echo "Starting the $IMAGE_NAME container..."
docker run -ti --rm --name $CONTAINER_NAME -p 5000:5000 $IMAGE_NAME --host 0.0.0.0
