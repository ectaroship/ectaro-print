# Ectaro Print

Ectaro Print is the print agent that Ectaro Flow (Ectaro B.V.'s warehouse management system) and
Ectaroship install on warehouse bench computers. It lets their web apps send label PDFs straight to
a local printer.

It is a rebranded build of [QZ Tray](https://github.com/qzind/tray) by QZ Industries, LLC,
distributed under the GNU Lesser General Public License v2.1 (see `LICENSE.txt`). This repository is
the complete corresponding source for every Ectaro Print installer Ectaro distributes.

## What differs from upstream

Base: QZ Tray **v2.3.0** (`b98daff5201c48cfc18e4d37e43e30de266e0daf`). Changes, made 20-21 October 2026:

- `ant/project.properties`: product name, file name, data directory and vendor details
  (Ectaro Print, Ectaro B.V.).
- `src/qz/common/Constants.java`: About-box name, company, address, links, brand colour; the update
  check points at this repository's releases instead of upstream's; `PROPS_FILE` and `DATA_DIR`
  renamed (see below).
- `src/qz/ui/SiteManagerDialog.java`: the demo-keypair dialog links here instead of qz.io.
- Icons: application, installer and tray icons replaced with the Ectaro mark. The sources and the
  script that renders them are in `branding/` (`branding/make-icons.sh`).

No printing, security or protocol code is changed.

### Values that must be changed together

Some values exist twice, once in the build (`ant/project.properties`) and once in the code
(`Constants.java`). The installer builds file names, the startup shortcut and the silent-install
flag from one side and the program looks them up by the other, so a mismatch does not fail the build:
it fails on the PC (for example, the startup shortcut points at an executable that does not exist
and the agent does not come back after a reboot).

| `ant/project.properties` | `Constants.java` | Used for |
|---|---|---|
| `project.filename=ectaro-print` | `PROPS_FILE = "ectaro-print"` | jar, launcher exe, shortcut, `.properties` file |
| `vendor.name=ectaro-print` | `DATA_DIR = "ectaro-print"` | `%PROGRAMDATA%\ectaro-print`, registry key, `<name>_silent` install flag |
| `project.name=Ectaro Print` | `ABOUT_TITLE = "Ectaro Print"` | window titles, Programs list, probe response |

`project.datadir` is set to the same `ectaro-print`.

## Building

The installer is built here, by `ectaro/build.sh` (locally) and `.github/workflows/release.yml`
(on every `ectaro-print-*` tag, published as a GitHub Release — see `ectaro/README.md`). It passes
the trust certificates and a provisioning file, both in `ectaro/`, to the standard QZ Tray build:

```
ant -Dauthcert.use=<root.crt> -Dwhitelist.use=<site.crt> -Dprovision.file=<provision.json> \
    -Dtarget.os=windows -Dtarget.arch=x86_64 nsis
```

Those certificates are public; no private key is part of this repository or the installer.

"QZ Tray" is a name of QZ Industries, LLC. Ectaro Print is not affiliated with or endorsed by them.
