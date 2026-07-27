# litellm-lagoon-base

Republishes the upstream [LiteLLM](https://github.com/BerriAI/litellm) proxy
image with our pending upstream patches applied — nothing else. Consumed by
[litellm-lagoon](https://github.com/amazeeio/litellm-lagoon) as its base image.

Images: `ghcr.io/amazeeio/litellm-lagoon-base:<litellm-version>` (e.g.
`v1.93.0`) plus `latest`. With an empty `patch/` dir the output is a 1-to-1
copy of `ghcr.io/berriai/litellm:<version>`.

## How it works

- `Dockerfile` starts `FROM ghcr.io/berriai/litellm:${LITELLM_VERSION}` and
  applies every `patch/*.patch` onto the installed `litellm` site-package with
  `git apply --include='litellm/*'` (tests/UI-source paths in a patch are
  skipped — the image ships prebuilt UI assets).
- `.github/workflows/build.yml` runs every 6 hours, resolves the latest
  **stable** (non-prerelease) LiteLLM release, and builds/pushes it if not
  already published. Pushes to `main` touching `Dockerfile` or `patch/`
  republish the current version. `workflow_dispatch` accepts an explicit
  version.
- If the build fails (usually: patch no longer applies to a new release),
  a message is posted to Slack via the `SLACK_WEBHOOK_URL` repo secret.

## Current patches

- `0001-litellm-pr31618-budget-threshold-webhook-alerts.patch` —
  [BerriAI/litellm#31618](https://github.com/BerriAI/litellm/pull/31618),
  rebased onto v1.93.0 (the raw PR diff is based on newer `main` and does not
  apply to the stable tag as-is).

## Refreshing a patch after upstream drift

```sh
git clone --depth 1 --branch <version> --filter=blob:none --sparse https://github.com/BerriAI/litellm /tmp/litellm
cd /tmp/litellm && git sparse-checkout set litellm
gh pr diff 31618 --repo BerriAI/litellm > /tmp/pr.diff
git apply --include='litellm/*' /tmp/pr.diff   # fix rejects by hand if any
git diff > <this-repo>/patch/0001-litellm-pr31618-budget-threshold-webhook-alerts.patch
```

## When the PR merges upstream

Delete `patch/*.patch` (keep `patch/.gitkeep`) and push. Builds continue and
publish unpatched 1-to-1 copies of upstream — `litellm-lagoon` keeps working
unchanged.

## One-time setup

- Repo secret `SLACK_WEBHOOK_URL` — incoming-webhook URL for the alerts channel.
- After the first push to GHCR, set the `litellm-lagoon-base` package
  visibility to **public** (org packages default to private; Lagoon builds
  pull this image unauthenticated).
