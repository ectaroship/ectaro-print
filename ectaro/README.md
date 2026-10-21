# Ectaro Print — how the installer is built and released (WMS-624, WMS-634, ADR-0045)

This folder is what Ectaro adds around the QZ Tray source: our trust certificates, the
provisioning files, the build script. The repository root is the program (see
[`ECTARO-PRINT.md`](../ECTARO-PRINT.md) for what differs from upstream QZ Tray). The *why* is
ADR-0045 in the Ectaro Flow repository; the bench setup guide is `docs/guides/5-yazici-kurulumu.md`
there. **One agent serves Ectaro Flow and Ectaroship**: same agent, same site certificate, same
signing key (`QZ_SIGNING_KEY`, which therefore lives in both systems).

## What is in this folder

| File | What it is |
|---|---|
| `build.sh` | Builds the Windows x86_64 installer from the current checkout (`ant … nsis`). |
| `certs/prod-root.crt` | **Ectaro Flow Print Root** — the CA the production installer trusts. Its private key is **not** in any of our systems: Yasin keeps it offline; it is needed only to issue a new site certificate. |
| `certs/prod-site.crt` | **Ectaro Flow** — the site certificate, signed by the root. Its private key is the `QZ_SIGNING_KEY` secret of the signing servers. |
| `certs/dev-root.crt`, `certs/dev-site.crt` | The dev pair. The dev site key is **public**, so a dev build is for a developer's own machine only. |
| `provision.json` | Baked into the prod installer: listen on `127.0.0.1` only, accept only the origins in `security.wss.alloworigin`, no file access, no print-to-host / print-to-file, no demo pages. |
| `provision.dev.json` | The same with `http://localhost:5173` only. |

The provisioning files live here and **not** at the repository root: the root `.gitignore`
ignores `/provision.json`.

`build.sh` passes the three files to QZ's own build flags, as absolute paths (QZ hands
`provision.file` to a forked Java process as-is, so a relative path breaks):

- `-Dauthcert.use=ectaro/certs/<env>-root.crt` — becomes `override.crt`, a root QZ trusts, so
  our site certificate validates against it.
- `-Dwhitelist.use=ectaro/certs/<env>-site.crt` — pre-allowed at install (`allowed.dat`), so a
  request signed by our server prints with no dialog.
- `-Dprovision.file=ectaro/provision[.dev].json` — the settings above.

## Releasing

Pushing a tag `ectaro-print-*` runs `.github/workflows/release.yml`: it builds the prod and
the dev installer with `ectaro/build.sh` and publishes a GitHub Release with two assets:

| Asset | |
|---|---|
| `ectaro-print-x86_64.exe` | Production. The name is stable, so `https://github.com/ectaroship/ectaro-print/releases/latest/download/ectaro-print-x86_64.exe` always serves the newest release. This is what `PRINT_AGENT_DOWNLOAD_URL` in Ectaro Flow points at. |
| `ectaro-print-x86_64-dev.exe` | Dev build. |

The release notes carry the source commit and the SHA-256 of both installers and of every
`ectaro/certs/*.crt`.

```bash
git tag -a ectaro-print-2.3.0-3 -m "Ectaro Print 2.3.0-3: <what changed>"
git push origin ectaro-print-2.3.0-3
```

Never move or delete a published tag. To re-run one (a flaky download), use **Actions →
Release Ectaro Print → Run workflow** with the tag; the assets are replaced.

## Building locally

```bash
ectaro/build.sh --env prod ./dist     # → ./dist/ectaro-print-x86_64.exe
ectaro/build.sh --env dev ./dist      # → ./dist/ectaro-print-x86_64-dev.exe
```

Needs `ant`, `makensis` (NSIS) and a **JDK 25 or newer** (`JAVA_HOME`, or
`/usr/libexec/java_home -v 25+` on a Mac). The first build downloads QZ's bundled Java runtime
(about 200 MB); the bench PC needs no Java of its own. The installer is **not code-signed**
(Windows shows "Windows protected your PC" → *More info* → *Run anyway*), and installing needs
a local administrator.

## Adding an origin

The origins the agent accepts are baked into the installer, in `security.wss.alloworigin` of
`provision.json`: a **comma-separated list**, scheme + host (+ port), no path. Current prod
entries: `https://wms.ectaro.com` (Ectaro Flow), `https://app.ectaroship.nl` and
`https://admin.ectaroship.nl` (Ectaroship). `provision.dev.json` stays `http://localhost:5173`.

Edit `ectaro/provision.json`, tag a release, and reinstall the new installer on every bench —
the list is not read from anywhere at runtime.

## Rotating the site certificate

1. With the offline root key, issue a new `Ectaro Flow` site certificate (same subject).
2. Replace `ectaro/certs/prod-site.crt` **here**, and in the Ectaro Flow repository replace its
   copy `print-agent/certs/prod-site.crt` **and** `PROD_SITE_CERTIFICATE` in
   `packages/integrations/src/print-agent/certificates.ts`. Compare the copies with
   `shasum -a 256` — the release notes list the sha256 of each file here.
3. Tag a release, reinstall it on every bench (the pre-allowed certificate is in the installer),
   then replace the `QZ_SIGNING_KEY` secret **in both systems** and deploy. Until a bench is
   reinstalled it shows QZ's allow dialog once — tick "remember" and it prints again.

A new **root** means a new installer on every bench too (the same files, `prod-root.crt`); the
root is good until 2036.

## Licence

QZ Tray is LGPL 2.1. This repository is the complete corresponding source of every installer
we distribute. "QZ Tray" is a name of QZ Industries, LLC; Ectaro Print is not affiliated with or
endorsed by them.
