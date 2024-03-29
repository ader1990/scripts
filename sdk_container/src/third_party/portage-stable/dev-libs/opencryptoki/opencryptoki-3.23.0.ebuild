# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit autotools flag-o-matic

DESCRIPTION="PKCS#11 provider cryptographic hardware"
HOMEPAGE="https://sourceforge.net/projects/opencryptoki"
SRC_URI="https://github.com/opencryptoki/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
#SRC_URI="mirror://sourceforge/opencryptoki/${PV}/${P}.tgz"
S="${WORKDIR}/${PN}-${PV}"

# Upstream is looking into relicensing it into CPL-1.0 entirely; the CCA
# token sources are under CPL-1.0 already.
LICENSE="CPL-0.5"
SLOT="0"
KEYWORDS="amd64 ~arm arm64 ~s390 ~x86"
IUSE="+tpm"

DEPEND="
	tpm? ( app-crypt/trousers )
	>=dev-libs/openssl-1.1.0:0=
	net-nds/openldap
	sys-apps/systemd
"
RDEPEND="
	${DEPEND}
"

PATCHES=(
	"${FILESDIR}"/0001-fix-double-quotes-usage.patch
)

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	# package uses ${localstatedir}/lib as the default path, so if we
	# leave it to econf, it'll create /var/lib/lib.

	# Since upstream by default seem to enable any possible token, even
	# when they don't seem to be used, we limit ourselves to the
	# software emulation token (swtok) and if the user enabled the tpm
	# USE flag, tpmtok.  The rest of the tokens seem to be hardware- or
	# software-dependent even when they build fine without their
	# requirements, but until somebody asks for those, I'd rather not
	# enable them.

	# We don't use --enable-debug because that tinkers with the CFLAGS
	# and we don't want that. Instead we append -DDEBUG which enables
	# debug information.

	econf \
		--enable-swtok --enable-icsftok --enable-ccatok --with-systemd \
		--with-pkcs-group=root --with-pkcsslotd-user=root
}

src_install() {
	default

	find "${ED}" -name '*.la' -delete || die

	# Install libopencryptoki in the standard directory for libraries.
	mv "${ED}"/usr/$(get_libdir)/opencryptoki/libopencryptoki.so* "${ED}"/usr/$(get_libdir) || die
	rm "${ED}"/usr/$(get_libdir)/pkcs11/libopencryptoki.so || die
	dosym ../libopencryptoki.so /usr/$(get_libdir)/pkcs11/libopencryptoki.so

	# Remove compatibility symlinks as we _never_ required those and
	# they seem unused even upstream.
	find "${ED}" -name 'PKCS11_*' -delete || die

	# We replace their ld.so and init files (mostly designed for RedHat
	# as far as I can tell) with our own replacements.
	rm -rf "${ED}"/etc/ld.so.conf.d "${ED}"/etc/rc.d || die

	# make sure that we don't modify the init script if the USE flags
	# are enabled for the needed services.
	cp "${FILESDIR}"/pkcsslotd.init.2 "${T}"/pkcsslotd.init || die
	use tpm || sed -i -e '/use tcsd/d' "${T}"/pkcsslotd.init
	newinitd "${T}/pkcsslotd.init" pkcsslotd

}
