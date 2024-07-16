FROM libretranslate/libretranslate:latest

USER libretranslate

WORKDIR /app

RUN ./venv/bin/python scripts/install_models.py

ENTRYPOINT [ "./venv/bin/libretranslate" ]