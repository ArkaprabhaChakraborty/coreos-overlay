# Flatcar modifications:
# - changed files/sssd.service
# - added files/tmpfiles.d/sssd.conf
# - other ebuild modifications marked below
#
# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_7 )

inherit autotools flag-o-matic linux-info multilib-minimal python-single-r1 pam systemd toolchain-funcs

DESCRIPTION="System Security Services Daemon provides access to identity and authentication"
HOMEPAGE="https://github.com/SSSD/sssd"
SRC_URI="https://github.com/SSSD/sssd/releases/download/${PN}-${PV//./_}/${P}.tar.gz"
# Flatcar: stabilize arm64
KEYWORDS="amd64 ~arm arm64 ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sparc x86"

LICENSE="GPL-3"
SLOT="0"
IUSE="acl doc +locator +netlink nfsv4 nls +man pac python samba selinux sudo systemd test valgrind"
RESTRICT="!test? ( test )"

REQUIRED_USE="pac? ( samba )
	python? ( ${PYTHON_REQUIRED_USE} )"

# Flatcar: do not force gssapi for >=net-dns/bind-tools-9.9
# do not force winbind for net-fs/samba
DEPEND="
	>=app-crypt/mit-krb5-1.10.3
	app-crypt/p11-kit
	>=dev-libs/ding-libs-0.2
	dev-libs/glib:2
	>=dev-libs/cyrus-sasl-2.1.25-r3[kerberos]
	>=dev-libs/libpcre-8.30:=
	>=dev-libs/popt-1.16
	>=dev-libs/openssl-1.0.2:0=
	>=net-dns/bind-tools-9.9
	>=net-dns/c-ares-1.7.4
	>=net-nds/openldap-2.4.30[sasl]
	>=sys-apps/dbus-1.6
	>=sys-apps/keyutils-1.5:=
	>=sys-libs/pam-0-r1[${MULTILIB_USEDEP}]
	>=sys-libs/talloc-2.0.7
	>=sys-libs/tdb-1.2.9
	>=sys-libs/tevent-0.9.16
	>=sys-libs/ldb-1.1.17-r1:=
	virtual/libintl
	locator? (
		>=app-crypt/mit-krb5-1.12.2[${MULTILIB_USEDEP}]
		>=net-dns/c-ares-1.10.0-r1[${MULTILIB_USEDEP}]
	)
	acl? ( net-fs/cifs-utils[acl] )
	netlink? ( dev-libs/libnl:3 )
	nfsv4? ( || ( >=net-fs/nfs-utils-2.3.1-r2 net-libs/libnfsidmap ) )
	nls? ( >=sys-devel/gettext-0.18 )
	pac? (
		app-crypt/mit-krb5[${MULTILIB_USEDEP}]
		net-fs/samba
	)
	python? ( ${PYTHON_DEPS} )
	samba? ( >=net-fs/samba-4.10.2 )
	selinux? (
		>=sys-libs/libselinux-2.1.9
		>=sys-libs/libsemanage-2.1
	)
	systemd? (
		dev-libs/jansson:0=
		net-libs/http-parser:0=
		net-misc/curl:0=
	)
	"

RDEPEND="${DEPEND}
	>=sys-libs/glibc-2.17[nscd]
	selinux? ( >=sec-policy/selinux-sssd-2.20120725-r9 )
	"
# Flatcar: require only autoconf:2.69
BDEPEND="
	sys-devel/autoconf:2.69
	doc? ( app-doc/doxygen )
	test? (
		dev-libs/check
		dev-libs/softhsm:2
		dev-util/cmocka
		net-libs/gnutls[pkcs11,tools]
		sys-libs/libfaketime
		sys-libs/nss_wrapper
		sys-libs/pam_wrapper
		sys-libs/uid_wrapper
		valgrind? ( dev-util/valgrind )
	)
	man? (
		app-text/docbook-xml-dtd:4.4
		>=dev-libs/libxslt-1.1.26
		nls? ( app-text/po4a )
	)"

CONFIG_CHECK="~KEYS"

MULTILIB_WRAPPED_HEADERS=(
	/usr/include/ipa_hbac.h
	/usr/include/sss_idmap.h
	/usr/include/sss_nss_idmap.h
	# --with-ifp
	/usr/include/sss_sifp.h
	/usr/include/sss_sifp_dbus.h
	# from 1.15.3
	/usr/include/sss_certmap.h
)

PATCHES=(
	"${FILESDIR}"/${P}-test_ca-Look-for-libsofthsm2.so-in-usr-libdir-sofths.patch
	"${FILESDIR}"/${P}-disable-nsupdate-realm.patch
	# Flatcar: add a patch for CVE-2021-3621
	"${FILESDIR}"/${P}-CVE-2021-3621.patch
)

pkg_setup() {
	linux-info_pkg_setup
}

src_prepare() {
	sed -i 's:/var/run:/run:' \
		"${S}"/src/examples/logrotate || die

	default
	eautoreconf
	multilib_copy_sources
	if use python && multilib_is_native_abi; then
		python_setup
	fi
}

src_configure() {
	local native_dbus_cflags=$($(tc-getPKG_CONFIG) --cflags dbus-1)

	multilib-minimal_src_configure
}

multilib_src_configure() {
	local myconf=()

	myconf+=(
		--localstatedir="${EPREFIX}"/var
		--with-pid-path="${EPREFIX}"/run
		--with-plugin-path="${EPREFIX}"/usr/$(get_libdir)/sssd
		--enable-pammoddir="${EPREFIX}"/$(getpam_mod_dir)
		--with-ldb-lib-dir="${EPREFIX}"/usr/$(get_libdir)/samba/ldb
		--with-db-path="${EPREFIX}"/var/lib/sss/db
		--with-gpo-cache-path="${EPREFIX}"/var/lib/sss/gpo_cache
		--with-pubconf-path="${EPREFIX}"/var/lib/sss/pubconf
		--with-pipe-path="${EPREFIX}"/var/lib/sss/pipes
		--with-mcache-path="${EPREFIX}"/var/lib/sss/mc
		--with-secrets-db-path="${EPREFIX}"/var/lib/sss/secrets
		--with-log-path="${EPREFIX}"/var/log/sssd
		--with-os=gentoo
		--with-nscd="${EPREFIX}"/usr/sbin/nscd
		--with-unicode-lib="glib2"
		--disable-rpath
		# Flatcar: make nss lookups succeed when not running
		--enable-sss-default-nss-plugin
		# Flatcar: prevent cross-compilation error
		# when autotools does not want to compile and run the test
		$(use_with samba smb-idmap-interface-version=6)
		#
		--sbindir=/usr/sbin
		--with-crypto="libcrypto"
		--enable-local-provider
		$(multilib_native_use_with systemd kcm)
		$(multilib_native_use_with systemd secrets)
		$(use_with samba)
		--with-smb-idmap-interface-version=6
		$(multilib_native_use_enable acl cifs-idmap-plugin)
		$(multilib_native_use_with selinux)
		$(multilib_native_use_with selinux semanage)
		$(use_enable locator krb5-locator-plugin)
		$(use_enable pac pac-responder)
		$(multilib_native_use_with nfsv4 nfsv4-idmapd-plugin)
		$(use_enable nls)
		$(multilib_native_use_with netlink libnl)
		$(multilib_native_use_with man manpages)
		$(multilib_native_use_with sudo)
		$(multilib_native_with autofs)
		$(multilib_native_with ssh)
		$(use_enable valgrind)
		--without-python2-bindings
		$(multilib_native_use_with python python3-bindings)
	)

	# Annoyingly configure requires that you pick systemd XOR sysv
	if use systemd; then
		myconf+=(
			--with-initscript="systemd"
			--with-systemdunitdir=$(systemd_get_systemunitdir)
			# Flatcar: Set the systemd system
			# configuration directory explicitly through
			# _systemd_get_dir, as it will do the right
			# thing in cross-compilation environment.
			--with-systemdconfdir=$(_systemd_get_dir systemdsystemconfdir /etc/systemd/system)
		)
	else
		myconf+=(--with-initscript="sysv")
	fi

	if ! multilib_is_native_abi; then
		# work-around all the libraries that are used for CLI and server
		myconf+=(
			{POPT,TALLOC,TDB,TEVENT,LDB}_{CFLAGS,LIBS}=' '
			# ldb headers are fine since native needs it
			# ldb lib fails... but it does not seem to bother
			{DHASH,COLLECTION,INI_CONFIG_V{0,1,1_1,1_3}}_{CFLAGS,LIBS}=' '
			{PCRE,CARES,SYSTEMD_LOGIN,SASL,GLIB2,DBUS,CRYPTO,P11_KIT}_{CFLAGS,LIBS}=' '
			{NDR_NBT,SMBCLIENT,NDR_KRB5PAC}_{CFLAGS,LIBS}=' '

			# use native include path for dbus (needed for build)
			DBUS_CFLAGS="${native_dbus_cflags}"

			# non-pkgconfig checks
			ac_cv_lib_ldap_ldap_search=yes
			--without-secrets
			--without-kcm
		)
	fi

	econf "${myconf[@]}"
}

multilib_src_compile() {
	if multilib_is_native_abi; then
		# Flatcar: add runstatedir to make commands to avoid configure error
		default runstatedir="${EPREFIX}"/run
		use doc && emake docs
		if use man || use nls; then
			emake update-po
		fi
	else
		emake libnss_sss.la pam_sss.la
		use locator && emake sssd_krb5_locator_plugin.la
		use pac && emake sssd_pac_plugin.la
	fi
}

multilib_src_install() {
	if multilib_is_native_abi; then
		# Flatcar: add runstatedir, sysconfdir
		emake -j1 DESTDIR="${D}" runstatedir="${EPREFIX}"/run \
			sysconfdir="/usr/share" "${_at_args[@]}" install
		if use python; then
			python_optimize
			python_fix_shebang "${ED}"
		fi

	else
		# easier than playing with automake...
		dopammod .libs/pam_sss.so

		into /
		dolib.so .libs/libnss_sss.so*

		if use locator; then
			exeinto /usr/$(get_libdir)/krb5/plugins/libkrb5
			doexe .libs/sssd_krb5_locator_plugin.so
		fi

		if use pac; then
			exeinto /usr/$(get_libdir)/krb5/plugins/authdata
			doexe .libs/sssd_pac_plugin.so
		fi
	fi
}

multilib_src_install_all() {
	einstalldocs
	find "${ED}" -type f -name '*.la' -delete || die

	# Flatcar: store on /usr
	insinto /usr/share/sssd
	doins "${S}"/src/examples/sssd-example.conf

	# Flatcar: delete, remove /var files taken care of by tmpfiles

	# Flatcar: add tmpfile directive and remove /etc/rc.d
	systemd_dotmpfilesd "${FILESDIR}/tmpfiles.d/sssd.conf"
	rm -rf "${D}/etc/rc.d"
	# strip empty dirs
	if ! use doc ; then
		rm -r "${ED}"/usr/share/doc/"${PF}"/doc || die
		rm -r "${ED}"/usr/share/doc/"${PF}"/{hbac,idmap,nss_idmap,sss_simpleifp}_doc || die
	fi

	rm -r "${ED}"/run || die
}

multilib_src_test() {
	multilib_is_native_abi && emake check
}

pkg_postinst() {
	elog "You must set up sssd.conf (default installed into /etc/sssd)"
	elog "and (optionally) configuration in /etc/pam.d in order to use SSSD"
	elog "features. Please see howto in	https://sssd.io/docs/design_pages/smartcard_authentication_require.html"
}
