The reason for having this package in overlay is to patch the
introspection.m4 file. The patch drops `$PKG_CONFIG_SYSROOT_DIR` from paths
returned by pkg-config, because in gentoo we have a pkg-config wrapper that
already prepends the sysroot directory to the paths. Without the patch we
ended up having paths like
`/build/amd64-usr//build/amd64-usr/usr/share/gobject-introspection-1.0/Makefile.introspection`.
This error is triggered by projects using gobject-introspection with the
autotools build system. Like the old version polkit that we still have.
