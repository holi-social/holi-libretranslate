#!/bin/bash

docker build -t holi-libretranslate .
docker run -ti --rm -p 5000:5000 holi-libretranslate
