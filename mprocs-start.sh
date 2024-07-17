#!/bin/bash

docker build -t holi-libretranslate --build-arg lang_codes=en,de .
docker run -ti --rm --name holi-libretranslate -p 5000:5000 holi-libretranslate --host 0.0.0.0
