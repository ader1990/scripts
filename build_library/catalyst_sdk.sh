#!/bin/bash
set -e

source /tmp/chroot-functions.sh
source /tmp/toolchain_util.sh

echo "Double checking everything is fresh and happy."
run_merge -uDN --with-bdeps=y world

echo "Setting the default Python interpreter"
eselect python update

echo "Building cross toolchain for the SDK."
configure_crossdev_overlay / /usr/local/portage/crossdev

for cross_chost in $(get_chost_list); do
    echo "Building cross toolchain for ${cross_chost}"
    PKGDIR="$(portageq envvar PKGDIR)/crossdev" \
        install_cross_toolchain "${cross_chost}" ${clst_myemergeopts}
done

echo "Rebuilding dev-lang/rust with cross targets."
PKGDIR="$(portageq envvar PKGDIR)/crossdev" run_merge dev-lang/rust
