# LITELLM_IMAGE: ghcr.io/berriai/litellm (Lagoon/docker-compose) or
# ghcr.io/berriai/litellm-database (helm chart default). Both are alpine,
# run as root, and ship litellm in site-packages, so patching is identical.
ARG LITELLM_IMAGE=ghcr.io/berriai/litellm
ARG LITELLM_VERSION=v1.97.0
FROM ${LITELLM_IMAGE}:${LITELLM_VERSION}

# 1. Strip the proprietary enterprise code (enterprise/LICENSE.md forbids
#    redistribution without a BerriAI subscription; everything else is MIT,
#    which allows republishing). All litellm imports of litellm_enterprise
#    are ImportError-guarded, and we never set LITELLM_LICENSE, so nothing
#    is lost. This runs even with an empty patch/ dir — republishing the
#    unmodified image would otherwise still redistribute enterprise code.
# 2. Apply patch/*.patch onto the installed litellm package. Only litellm/*
#    paths are applied — tests/ and ui/ sources in a patch are skipped (the
#    image ships prebuilt UI assets, so ui/ source changes are inert anyway).
# 3. Import the proxy server as a smoke test that the image still boots
#    without the enterprise code and with the patches applied.
COPY patch/ /tmp/patch/
RUN set -e; \
    cd "$(python -c 'import site; print(site.getsitepackages()[0])')"; \
    rm -rf /app/enterprise litellm_enterprise litellm_enterprise-*.dist-info; \
    python -c 'import importlib.util; assert importlib.util.find_spec("litellm_enterprise") is None, "litellm_enterprise still importable"'; \
    if ls /tmp/patch/*.patch >/dev/null 2>&1; then \
        apk add --no-cache git; \
        for p in /tmp/patch/*.patch; do \
            echo "=== applying $p ==="; \
            git apply --verbose --include='litellm/*' "$p"; \
        done; \
        find litellm -name __pycache__ -type d -prune -exec rm -rf {} +; \
        python -m compileall -q litellm; \
        apk del git; \
    fi; \
    rm -rf /tmp/patch; \
    python -c 'import litellm.proxy.proxy_server' \
        && echo "proxy_server imports OK without enterprise code"
