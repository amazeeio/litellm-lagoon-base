# litellm-lagoon-base

Republishes the upstream [LiteLLM](https://github.com/BerriAI/litellm) proxy
images with our pending upstream patches applied and the proprietary
`enterprise/` code removed — nothing else. LiteLLM is MIT-licensed **except**
the enterprise components, whose license forbids redistribution without a
BerriAI subscription, so the published images contain MIT-licensed code only.
With an empty `patch/` dir the output is a 1-to-1 copy of upstream minus
those enterprise components.

Two packages, mirroring the upstream image variants, tagged with the upstream
release (e.g. `v1.93.0`) plus `latest`:

| Package | Upstream base | Consumed by |
| --- | --- | --- |
| `ghcr.io/amazeeio/litellm-lagoon-base` | `ghcr.io/berriai/litellm` | [litellm-lagoon](https://github.com/amazeeio/litellm-lagoon) (Lagoon / docker-compose) |
| `ghcr.io/amazeeio/litellm-lagoon-base-database` | `ghcr.io/berriai/litellm-database` | litellm helm chart in [amazeeai-k0rdent-catalog](https://github.com/amazeeio/amazeeai-k0rdent-catalog) |

## How it works

- `Dockerfile` starts `FROM ${LITELLM_IMAGE}:${LITELLM_VERSION}`, removes the
  enterprise code (`litellm-enterprise` package + `/app/enterprise` — all
  litellm imports of it are ImportError-guarded and features are dormant
  without `LITELLM_LICENSE`, so nothing functional is lost), and applies
  every `patch/*.patch` onto the installed `litellm` site-package with
  `git apply --include='litellm/*'` (tests/UI-source paths in a patch are
  skipped — the images ship prebuilt UI assets). A final
  `import litellm.proxy.proxy_server` smoke-checks the result.
- `.github/workflows/build.yml` runs once a day, resolves the latest
  **stable** (non-prerelease) LiteLLM release, and builds/pushes both variants
  if not already published. Pushes to `main` touching `Dockerfile` or `patch/`
  republish the current version. `workflow_dispatch` accepts an explicit
  version.
- If a build fails (usually: patch no longer applies to a new release), a
  single message is posted to Slack — repeat failures stay quiet until a run
  succeeds again.

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
publish unpatched copies of upstream (still enterprise-stripped) — consumers
keep working unchanged.

## Consuming the internal packages

The packages stay **internal**, so every pull needs auth against ghcr.io with
`read:packages`:

- **Lagoon builds** (litellm-lagoon): `.lagoon.yml` declares a
  `container-registries` entry for ghcr.io; create the referenced Lagoon
  variables (`GHCR_USERNAME`, `GHCR_PULL_TOKEN` — a fine-grained PAT or classic
  PAT with `read:packages`) on each project:
  `lagoon add variable -p <project> -N GHCR_PULL_TOKEN -V <token> -S container_registry`
- **Kubernetes / k0rdent**: create a `kubernetes.io/dockerconfigjson` pull
  secret for ghcr.io in the target namespace and reference it via the chart's
  `litellm-helm.imagePullSecrets`.
- **Local dev**: `docker login ghcr.io` with your GitHub username + PAT.

## One-time setup

- Grant the org-level `SLACK_BOT_TOKEN` secret access to this repo (org
  settings → secrets → repository access), and set the `SLACK_CHANNEL_ID`
  **repository variable** to the alerts channel ID. The Slack app must be a
  member of that channel.
