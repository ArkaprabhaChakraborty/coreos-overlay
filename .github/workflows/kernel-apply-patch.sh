#!/bin/bash

set -euo pipefail

# trim the 3rd part in the input semver, e.g. from 5.4.1 to 5.4
VERSION_SHORT=${VERSION_NEW%.*}
UPDATE_NEEDED=1

. .github/workflows/common.sh

prepare_git_repo

if ! checkout_branches "linux-${VERSION_NEW}-${TARGET}"; then
  UPDATE_NEEDED=0
  exit 0
fi

pushd "${SDK_OUTER_SRCDIR}/third_party/coreos-overlay" >/dev/null || exit

VERSION_OLD=$(sed -n "s/^DIST patch-\(${VERSION_SHORT}\.[0-9]*\).*/\1/p" sys-kernel/coreos-sources/Manifest)
if [[ -z "${VERSION_OLD}" ]]; then
  VERSION_OLD=$(sed -n "s/^DIST linux-\(${VERSION_SHORT}*\).*/\1/p" sys-kernel/coreos-sources/Manifest)
fi
if [[ "${VERSION_NEW}" = "${VERSION_OLD}" ]]; then
  echo "already the latest Kernel, nothing to do"
  UPDATE_NEEDED=0
  exit 0
fi

for pkg in sources modules kernel; do
  pushd "sys-kernel/coreos-${pkg}" >/dev/null || exit
  git mv "coreos-${pkg}"-*.ebuild "coreos-${pkg}-${VERSION_NEW}.ebuild"
  sed -i -e '/^COREOS_SOURCE_REVISION=/s/=.*/=""/' "coreos-${pkg}-${VERSION_NEW}.ebuild"
  popd >/dev/null || exit
done

popd >/dev/null || exit

if ! curl -sfA 'Chrome' -L 'http://www.google.com/search?hl=en&q=site%3Alwn.net+linux+'"${VERSION_NEW}" -o search.html; then
  echo 'curl failed'
  touch search.html
fi
# can't use grep -m 1 -o … to replace head -n 1, because all the links
# seem to happen in one line, so grep prints all the links in the line
URL=$({ grep -o 'https://lwn.net/Articles/[0-9]\+' search.html || true ; } | head -n 1)
if [[ ! "${URL}" ]]; then
    URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tag/?h=v${VERSION_NEW}"
fi
rm search.html

generate_update_changelog 'Linux' "${VERSION_NEW}" "${URL}" 'linux'

generate_patches sys-kernel coreos-sources Kernel

apply_patches

echo ::set-output name=VERSION_OLD::"${VERSION_OLD}"
echo ::set-output name=UPDATE_NEEDED::"${UPDATE_NEEDED}"
