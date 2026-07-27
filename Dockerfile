# LITELLM_IMAGE: ghcr.io/berriai/litellm (Lagoon/docker-compose) or
# ghcr.io/berriai/litellm-database (helm chart default). Both are alpine,
# run as root, and ship litellm in site-packages, so patching is identical.
ARG LITELLM_IMAGE=ghcr.io/berriai/litellm
ARG LITELLM_VERSION=v1.93.0
FROM ${LITELLM_IMAGE}:${LITELLM_VERSION}

# Apply patch/*.patch onto the installed litellm package. Only litellm/*
# paths are applied — tests/ and ui/ sources in a patch are skipped (the
# image ships prebuilt UI assets, so ui/ source changes are inert anyway).
# With no *.patch files present this is a no-op and the image is a 1-to-1
# copy of upstream.
COPY patch/ /tmp/patch/
RUN set -e; \
    if ls /tmp/patch/*.patch >/dev/null 2>&1; then \
        apk add --no-cache git; \
        cd "$(python -c 'import site; print(site.getsitepackages()[0])')"; \
        for p in /tmp/patch/*.patch; do \
            echo "=== applying $p ==="; \
            git apply --verbose --include='litellm/*' "$p"; \
        done; \
        find litellm -name __pycache__ -type d -prune -exec rm -rf {} +; \
        python -m compileall -q litellm; \
        apk del git; \
    fi; \
    rm -rf /tmp/patch
