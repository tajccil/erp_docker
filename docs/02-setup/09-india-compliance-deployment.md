---
title: India Compliance Deployment
---

# Deploy ERPNext with India Compliance (Docker)

This guide walks through a typical self-hosted deployment: build a **layered image** that includes [ERPNext](https://github.com/frappe/erpnext) and [India Compliance](https://github.com/resilient-tech/india-compliance), run the stack with **MariaDB** and **Redis**, then create a site and install the apps.

For background on custom images and compose overrides, see [Build Setup](02-build-setup.md), [Start Setup](03-start-setup.md), and [Setup Examples](06-setup-examples.md).

## Prerequisites

- Git, Docker, and Docker Compose v2 (see [Build Setup](02-build-setup.md#prerequisites))
- This repository cloned locally
- India Compliance is an ERPNext app; you need **ERPNext and India Compliance on the same major version line** (e.g. both `version-15` or both `version-16`). Sample app lists are in [`resources/`](../../resources/).

## 1. Build the custom image

The repository ships JSON lists and a helper script under `resources/`:

| File | Use case |
| ---- | -------- |
| `resources/apps-india-compliance-v16.json` | Frappe/ERPNext **v16** (matches the default branch in `images/layered/Containerfile`) |
| `resources/apps-india-compliance-v15.json` | Frappe/ERPNext **v15** |
| `resources/build-india-compliance-image.sh` | Builds the layered image |

From the repository root:

```bash
# Default: version-16, tags image as india-compliance:16
./resources/build-india-compliance-image.sh

# Or explicitly v15
./resources/build-india-compliance-image.sh 15
```

You can override the tag or apps file:

```bash
IMAGE_TAG=myregistry/india-compliance:16 APPS_JSON=/path/to/apps.json ./resources/build-india-compliance-image.sh
```

To build manually instead, encode an `apps.json` and pass `APPS_JSON_BASE64` as in [Build Setup → Define custom apps](02-build-setup.md#define-custom-apps).

> **macOS:** If you encode `apps.json` yourself, GNU `base64 -w 0` is not available; use e.g. `base64 apps.json | tr -d '\n'` and export that as `APPS_JSON_BASE64`.

## 2. Configure environment variables

Compose needs variables for the image reference and for services such as the database. Copy the template and edit it:

```bash
cp example.env .env
```

**Minimum additions for the custom image** (so Compose does not pull the stock `frappe/erpnext` image):

```env
CUSTOM_IMAGE=india-compliance
CUSTOM_TAG=16
PULL_POLICY=missing
```

Use `CUSTOM_TAG=15` if you built with `./resources/build-india-compliance-image.sh 15`.

Set at least **`DB_PASSWORD`** for MariaDB (the default in `example.env` is only suitable for local testing). See [Environment variables](04-env-variables.md) for all options (`HTTP_PUBLISH_PORT`, proxy settings, external DB/Redis, etc.).

> **Security:** Use strong passwords and restrict network access in production. For TLS and reverse proxies, see [Production](../03-production/index.md) and [Setup Examples → HTTPS](06-setup-examples.md#example-3-production-setup-with-https).

## 3. Generate the Compose file

Combine the base `compose.yaml` with MariaDB, Redis, and direct HTTP access (no external reverse proxy):

```bash
docker compose --env-file .env \
  -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  config > compose.india-compliance.yaml
```

You can commit `compose.india-compliance.yaml` to a private repo (e.g. under `gitops/`) or skip writing a file and pass the same `-f` list to `docker compose up` (see [Setup Examples](06-setup-examples.md#storing-generated-yaml-files)).

## 4. Start the stack

```bash
docker compose --env-file .env -p frappe -f compose.india-compliance.yaml up -d
```

Wait until the `db` service is healthy and the `configurator` service has finished (often within a short time; see [Start Setup](03-start-setup.md)).

## 5. Create a site and install India Compliance

Replace `<sitename>`, `<db-password>`, and `<admin-password>` with your values. `DB_PASSWORD` in `.env` should match `<db-password>` if you use the bundled MariaDB.

**Option A — install ERPNext during site creation, then India Compliance:**

```bash
docker compose -p frappe --env-file .env -f compose.india-compliance.yaml exec backend \
  bench new-site <sitename> \
  --mariadb-user-host-login-scope='%' \
  --db-root-password <db-password> \
  --admin-password <admin-password> \
  --install-app erpnext

docker compose -p frappe --env-file .env -f compose.india-compliance.yaml exec backend \
  bench --site <sitename> install-app india_compliance
```

**Option B — create an empty site, then install both apps:**

```bash
docker compose -p frappe --env-file .env -f compose.india-compliance.yaml exec backend \
  bench new-site <sitename> \
  --mariadb-user-host-login-scope='%' \
  --db-root-password <db-password> \
  --admin-password <admin-password>

docker compose -p frappe --env-file .env -f compose.india-compliance.yaml exec backend \
  bench --site <sitename> install-app erpnext

docker compose -p frappe --env-file .env -f compose.india-compliance.yaml exec backend \
  bench --site <sitename> install-app india_compliance
```

The app name on the bench CLI is `india_compliance` (underscore). For more site tasks, see [Site operations](../04-operations/01-site-operations.md).

## 6. Open the site

By default the app is exposed on port **8080** (see `overrides/compose.noproxy.yaml` and `HTTP_PUBLISH_PORT`).

- Browser: `http://localhost:8080` (or your server IP/host).
- Log in with the Administrator user and the admin password you set.

If the site name does not match the host header (e.g. you use `127.0.0.1` but the site is `mysite.local`), set `FRAPPE_SITE_NAME_HEADER` in `.env` as described in [Environment variables](04-env-variables.md).

## Troubleshooting

- **Compose still pulls `frappe/erpnext`:** Ensure `CUSTOM_IMAGE`, `CUSTOM_TAG`, and `PULL_POLICY=missing` are set and passed (`--env-file .env` or exports).
- **Wrong Frappe/ERPNext/India Compliance mix:** Rebuild the image with matching branches in `apps.json` (see [India Compliance installation](https://docs.indiacompliance.app/docs/getting-started/installation)).
- **Database connection errors:** Confirm MariaDB is healthy, `DB_PASSWORD` matches what you pass to `bench new-site`, and `--mariadb-user-host-login-scope` is appropriate for your network (see [Start Setup → MariaDB scope](03-start-setup.md#understanding-the-mariadb-user-scope)).

## See also

- [India Compliance documentation](https://docs.indiacompliance.app/)
- [Build Setup](02-build-setup.md)
- [Start Setup](03-start-setup.md)
- [Setup Examples](06-setup-examples.md)

---

**Back:** [Setup Examples ←](06-setup-examples.md)

**Next:** [Environment variables →](04-env-variables.md)
