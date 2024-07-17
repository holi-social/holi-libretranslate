#!/bin/bash

docker build -t holi-libretranslate .
docker run -ti --rm --name holi-libretranslate -p 5000:5000 holi-libretranslate --host 0.0.0.0
