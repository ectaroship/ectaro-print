#!/usr/bin/env bash
# Ectaro Print (ADR-0045, WMS-624 / WMS-634) — build the Windows installer from
# THIS checkout: QZ Tray v2.3.0 plus our rebrand commit, built with our
# certificates and our provision file. Nothing in the source is touched.
#
#   ectaro/build.sh --env prod|dev <output dir>
#
# Needs: ant, makensis (NSIS) on PATH, and a JDK 25 or newer — JAVA_HOME if it
# is set, otherwise `/usr/libexec/java_home -v 25+` on macOS, otherwise `java`
# on PATH. QZ 2.3.0 compiles for Java 25 (javac.target=25) and bundles its own
# Liberica JRE 25 into the installer, which it downloads (~200 MB) the first
# time — so the bench PC needs no Java.
#
# What the flags do (see ectaro/README.md):
#   authcert.use   — ectaro/certs/<env>-root.crt becomes override.crt, a root
#                    QZ trusts: our site certificate validates against it.
#   whitelist.use  — ectaro/certs/<env>-site.crt is pre-allowed at install
#                    (allowed.dat), so a signed request prints with no dialog.
#   provision.file — ectaro/provision.json (prod) / provision.dev.json: listen
#                    on 127.0.0.1 only, accept the origins listed in
#                    alloworigin only, no file access, no print-to-host/-file,
#                    no demo assets.
set -euo pipefail

usage() {
	printf 'usage: %s --env prod|dev <output dir>\n' "$0" >&2
	exit 2
}

fail() {
	printf 'ectaro/build.sh: %s\n' "$1" >&2
	exit 1
}

env_name=""
out_dir=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	--env)
		[ "$#" -ge 2 ] || usage
		env_name=$2
		shift 2
		;;
	-h | --help) usage ;;
	*)
		[ -z "$out_dir" ] || usage
		out_dir=$1
		shift
		;;
	esac
done
case "$env_name" in prod | dev) ;; *) usage ;; esac
[ -n "$out_dir" ] || usage

# All three paths are absolute: provision.file is handed raw to a forked java
# with no dir=, so a relative path would be resolved against the wrong place.
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/.." && pwd)
root_cert="$here/certs/$env_name-root.crt"
site_cert="$here/certs/$env_name-site.crt"
if [ "$env_name" = prod ]; then
	provision="$here/provision.json"
else
	provision="$here/provision.dev.json"
fi
for file in "$root_cert" "$site_cert" "$provision"; do
	[ -f "$file" ] || fail "missing $file"
done

for tool in ant makensis; do
	command -v "$tool" >/dev/null 2>&1 || fail "$tool is not on PATH (macOS: brew install $tool; Ubuntu: apt-get install ${tool/makensis/nsis})."
done

# A JDK 25 or newer. Refuse anything older loudly: QZ 2.3.0 sets
# javac.target=25 and an older javac fails half-way with an unhelpful error.
if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
	JAVA_HOME=$(/usr/libexec/java_home -v 25+ 2>/dev/null || true)
fi
if [ -n "${JAVA_HOME:-}" ]; then
	java_bin="$JAVA_HOME/bin/java"
else
	java_bin=$(command -v java || true)
fi
[ -n "$java_bin" ] && [ -x "$java_bin" ] || fail "no JDK found. Install a JDK 25 (e.g. Temurin 25) and set JAVA_HOME."
java_major=$("$java_bin" -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java\.specification\.version = \([0-9]*\).*/\1/p')
[ -n "$java_major" ] && [ "$java_major" -ge 25 ] || fail "JDK 25 or newer required, found Java ${java_major:-unknown} at $java_bin. Set JAVA_HOME to a JDK 25."
[ -n "${JAVA_HOME:-}" ] && export JAVA_HOME

mkdir -p "$out_dir"
out_dir=$(cd "$out_dir" && pwd)

# A stale installer from an earlier build would make the glob below ambiguous.
rm -f "$repo"/out/ectaro-print-*-x86_64.exe

printf 'Building the Windows installer (%s, Java %s) …\n' "$env_name" "$java_major"
(
	cd "$repo"
	ant \
		-Dauthcert.use="$root_cert" \
		-Dwhitelist.use="$site_cert" \
		-Dprovision.file="$provision" \
		-Dtarget.os=windows \
		-Dtarget.arch=x86_64 \
		nsis
)

# The version is not hard-coded: the installer is named after project.version.
shopt -s nullglob
built=("$repo"/out/ectaro-print-*-x86_64.exe)
shopt -u nullglob
[ "${#built[@]}" -eq 1 ] || fail "expected exactly one out/ectaro-print-*-x86_64.exe, found ${#built[@]}."

suffix=""
[ "$env_name" = dev ] && suffix="-dev"
target="$out_dir/ectaro-print-x86_64$suffix.exe"
cp "${built[0]}" "$target"
printf 'Built %s (from %s)\n' "$target" "$(basename "${built[0]}")"
if command -v shasum >/dev/null 2>&1; then
	shasum -a 256 "$target"
elif command -v sha256sum >/dev/null 2>&1; then
	sha256sum "$target"
fi
