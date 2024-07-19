FROM europe-north1-docker.pkg.dev/holi-shared/docker-hub-remote/libretranslate/libretranslate:latest

USER libretranslate

WORKDIR /app

ARG lang_codes

RUN if [ -n "$lang_codes" ]; then \
    ./venv/bin/python scripts/install_models.py --load_only_lang_codes "$lang_codes"; \
    else \
    ./venv/bin/python scripts/install_models.py; \
    fi

ENTRYPOINT [ "./venv/bin/libretranslate" ]
