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
| `build.sh` | Builds the Windows x86_64 installer (`ant … nsis`) or a macOS `.pkg` (`ant … pkgbuild`, arm64 or x86_64) from the current checkout. |
| `certs/prod-root.crt` | **Ectaro Flow Print Root** — the CA the production installer trusts. Its private key is **not** in any of our systems: Yasin keeps it offline; it is needed only to issue a new site certificate. |
| `certs/prod-site.crt` | **Ectaro Flow** — the site certificate, signed by the root. Its private key is the `QZ_SIGNING_KEY` secret of the signing servers. |
| `certs/dev-root.crt`, `certs/dev-site.crt` | The dev pair. The dev site key is **public**, so a dev build is for a developer's own machine only. |
| `provision.json` | Baked into the prod installer: listen on `127.0.0.1` only, `security.wss.httpsonly=true` (no insecure `ws://` port 8182 — every prod origin is https and uses `wss://` on 8181), accept only the origins in `security.wss.alloworigin`, no file access, no print-to-host / print-to-file, no demo pages. |
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
the dev installers with `ectaro/build.sh` and publishes a GitHub Release with six assets. Two jobs:
Ubuntu builds and creates the release with the Windows installers; a macOS job then builds the
four packages, uploads them and rewrites the release notes.

| Asset | |
|---|---|
| `ectaro-print-x86_64.exe` | Windows, production. The name is stable, so `https://github.com/ectaroship/ectaro-print/releases/latest/download/ectaro-print-x86_64.exe` always serves the newest release. |
| `ectaro-print-macos-arm64.pkg` | macOS on Apple Silicon (M1 and later), production. |
| `ectaro-print-macos-x86_64.pkg` | macOS on Intel, production. |
| `ectaro-print-x86_64-dev.exe`, `ectaro-print-macos-arm64-dev.pkg`, `ectaro-print-macos-x86_64-dev.pkg` | Dev builds. |

These names are a contract: Ectaro Flow's `PRINT_AGENT_RELEASE_URL` points at the directory they
sit in (`…/releases/latest/download/`) and builds the three production links from the names.
Do not rename them without changing Ectaro Flow.

The release notes carry the source commit and the SHA-256 of every installer and of every
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

# macOS — on a Mac only (pkgbuild and productbuild)
ectaro/build.sh --env prod --os mac --arch aarch64 ./dist   # → ./dist/ectaro-print-macos-arm64.pkg
ectaro/build.sh --env prod --os mac --arch x86_64 ./dist    # → ./dist/ectaro-print-macos-x86_64.pkg
ectaro/build.sh --env dev --os mac --arch aarch64 ./dist    # → ./dist/ectaro-print-macos-arm64-dev.pkg
```

`--os` defaults to `windows` and `--arch` to `x86_64` (Windows is x86_64 only). A Mac build
bundles one Java runtime per architecture, so there is no universal package; either arch can be
built on either kind of Mac.

Needs `ant`, `makensis` (NSIS, Windows build only) and a **JDK 25 or newer** (`JAVA_HOME`, or
`/usr/libexec/java_home -v 25+` on a Mac). The first build downloads QZ's bundled Java runtime
(about 200 MB); the bench PC needs no Java of its own. The installer is **not code-signed**
(Windows shows "Windows protected your PC" → *More info* → *Run anyway*), and installing needs
a local administrator. The macOS package is not signed or notarised either: macOS refuses it at
first, and the way through is *System Settings → Privacy & Security → Open Anyway*; installing
asks for the Mac's administrator password. Once installed it starts when the user logs in (a
LaunchAgent). Signing and notarisation need an Apple Developer ID and are a later ticket.

macOS limit: two printers with the same name are seen as one — rename or remove the old one in
*System Settings → Printers*.

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
