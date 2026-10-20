# e-flow print

e-flow print is the print agent that Ectaro Flow (Ectaro B.V.'s warehouse management system)
installs on warehouse bench computers. It lets the Ectaro Flow web app send label PDFs straight to
a local printer.

It is a rebranded build of [QZ Tray](https://github.com/qzind/tray) by QZ Industries, LLC,
distributed under the GNU Lesser General Public License v2.1 (see `LICENSE.txt`). This repository is
the complete corresponding source for every e-flow print installer Ectaro distributes.

## What differs from upstream

Base: QZ Tray **v2.3.0** (`b98daff5201c48cfc18e4d37e43e30de266e0daf`). Changes, made 20 October 2026:

- `ant/project.properties`: product name, file name and vendor details (e-flow print, Ectaro B.V.).
- `src/qz/common/Constants.java`: About-box name, company, address, links, brand colour; update
  check points at this repository's releases instead of upstream's.
- Icons: application, installer and tray icons replaced with the Ectaro Flow mark
  (`assets/branding/*`, `ant/windows/nsis/uninstall.ico`, `src/qz/ui/resources/qz-*.png`).

No printing, security or protocol code is changed.

## Building

The installer is built by Ectaro Flow's `print-agent/build.sh`, which checks out a tag of this
repository and passes the trust certificates and a provisioning file to the standard QZ Tray build:

```
ant -Dauthcert.use=<root.crt> -Dwhitelist.use=<site.crt> -Dprovision.file=<provision.json> \
    -Dtarget.os=windows -Dtarget.arch=x86_64 nsis
```

Those certificates are public; no private key is part of this repository or the installer.

"QZ Tray" is a name of QZ Industries, LLC. e-flow print is not affiliated with or endorsed by them.
