FROM python:3.11.9-slim-bullseye

RUN pip install libretranslate

ENTRYPOINT [ "libretranslate"]