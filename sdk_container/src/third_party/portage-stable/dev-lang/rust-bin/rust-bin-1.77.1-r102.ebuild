# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( 17 )
LLVM_OPTIONAL="yes"

inherit llvm-r1 multilib prefix rust-toolchain verify-sig multilib-minimal

MY_P="rust-${PV}"
# curl -L static.rust-lang.org/dist/channel-rust-${PV}.toml 2>/dev/null | grep "xz_url.*rust-src"
MY_SRC_URI="${RUST_TOOLCHAIN_BASEURL%/}/2024-03-28/rust-src-${PV}.tar.xz"
GENTOO_BIN_BASEURI="https://dev.gentoo.org/~arthurzam/distfiles/${CATEGORY}/${PN}" # omit leading slash

DESCRIPTION="Systems programming language from Mozilla"
HOMEPAGE="https://www.rust-lang.org/"
SRC_URI="$(rust_all_arch_uris ${MY_P})
	rust-src? ( ${MY_SRC_URI} )
"
# Keep this separate to allow easy commenting out if not yet built
SRC_URI+=" sparc? ( ${GENTOO_BIN_BASEURI}/${MY_P}-sparc64-unknown-linux-gnu.tar.xz ) "
SRC_URI+=" mips? (
	abi_mips_o32? (
		big-endian?  ( ${GENTOO_BIN_BASEURI}/${MY_P}-mips-unknown-linux-gnu.tar.xz )
		!big-endian? ( ${GENTOO_BIN_BASEURI}/${MY_P}-mipsel-unknown-linux-gnu.tar.xz )
	)
	abi_mips_n64? (
		big-endian?  ( ${GENTOO_BIN_BASEURI}/${MY_P}-mips64-unknown-linux-gnuabi64.tar.xz )
		!big-endian? ( ${GENTOO_BIN_BASEURI}/${MY_P}-mips64el-unknown-linux-gnuabi64.tar.xz )
	)
)"

LICENSE="|| ( MIT Apache-2.0 ) BSD BSD-1 BSD-2 BSD-4"
SLOT="${PV}"
KEYWORDS="amd64 arm arm64 ~loong ~mips ppc ppc64 ~riscv ~s390 sparc x86"
IUSE="big-endian clippy cpu_flags_x86_sse2 doc prefix rust-analyzer rust-src rustfmt"

RDEPEND="
	>=app-eselect/eselect-rust-20190311
	dev-libs/openssl
	sys-apps/lsb-release
	sys-devel/gcc:*
	!dev-lang/rust:stable
	!dev-lang/rust-bin:stable
"
BDEPEND="
	prefix? ( dev-util/patchelf )
	verify-sig? ( sec-keys/openpgp-keys-rust )
"

REQUIRED_USE="x86? ( cpu_flags_x86_sse2 )"

# stripping rust may break it (at least on x86_64)
# https://github.com/rust-lang/rust/issues/112286
RESTRICT="strip"

QA_PREBUILT="
	opt/${P}/bin/.*
	opt/${P}/lib/.*.so
	opt/${P}/libexec/.*
	opt/${P}/lib/rustlib/.*/bin/.*
	opt/${P}/lib/rustlib/.*/lib/.*
"

# An rmeta file is custom binary format that contains the metadata for the crate.
# rmeta files do not support linking, since they do not contain compiled object files.
# so we can safely silence the warning for this QA check.
QA_EXECSTACK="opt/${P}/lib/rustlib/*/lib*.rlib:lib.rmeta"

VERIFY_SIG_OPENPGP_KEY_PATH="/usr/share/openpgp-keys/rust.asc"

src_unpack() {
	# sadly rust-src tarball does not have corresponding .asc file
	# so do partial verification
	if use verify-sig; then
		for f in ${A}; do
			if [[ -f ${DISTDIR}/${f}.asc ]]; then
				verify-sig_verify_detached "${DISTDIR}/${f}" "${DISTDIR}/${f}.asc"
			fi
		done
	fi

	default_src_unpack

	mv "${WORKDIR}/${MY_P}-$(rust_abi)" "${S}" || die
}

patchelf_for_bin() {
	local filetype=$(file -b ${1})
	if [[ ${filetype} == *ELF*interpreter* ]]; then
		einfo "${1}'s interpreter changed"
		patchelf ${1} --set-interpreter ${2} || die
	elif [[ ${filetype} == *script* ]]; then
		hprefixify ${1}
	fi
}

multilib_src_install() {
	if multilib_is_native_abi; then

	# start native abi install
	pushd "${S}" >/dev/null || die
	local analysis std
	analysis="$(grep 'analysis' ./components)"
	std="$(grep 'std' ./components)"
	local components="rustc,cargo,rust-demangler-preview,${std}"
	use doc && components="${components},rust-docs"
	use clippy && components="${components},clippy-preview"
	use rustfmt && components="${components},rustfmt-preview"
	use rust-analyzer && components="${components},rust-analyzer-preview,${analysis}"
	# Rust component 'rust-src' is extracted from separate archive
	if use rust-src; then
		einfo "Combining rust and rust-src installers"
		mv -v "${WORKDIR}/rust-src-${PV}/rust-src" "${S}" || die
		echo rust-src >> ./components || die
		components="${components},rust-src"
	fi
	./install.sh \
		--components="${components}" \
		--disable-verify \
		--prefix="${ED}/opt/${P}" \
		--mandir="${ED}/opt/${P}/man" \
		--disable-ldconfig \
		|| die

	if use prefix; then
		local interpreter=$(patchelf --print-interpreter "${EPREFIX}"/bin/bash)
		ebegin "Changing interpreter to ${interpreter} for Gentoo prefix at ${ED}/opt/${P}/bin"
		find "${ED}/opt/${P}/bin" -type f -print0 | \
			while IFS=  read -r -d '' filename; do
				patchelf_for_bin ${filename} ${interpreter} \; || die
			done
		eend ${PIPESTATUS[0]}
	fi

	local symlinks=(
		cargo
		rustc
		rustdoc
		rust-demangler
		rust-gdb
		rust-gdbgui
		rust-lldb
	)

	use clippy && symlinks+=( clippy-driver cargo-clippy )
	use rustfmt && symlinks+=( rustfmt cargo-fmt )
	use rust-analyzer && symlinks+=( rust-analyzer )

	einfo "installing eselect-rust symlinks and paths"
	local i
	for i in "${symlinks[@]}"; do
		# we need realpath on /usr/bin/* symlink return version-appended binary path.
		# so /usr/bin/rustc should point to /opt/rust-bin-<ver>/bin/rustc-<ver>
		local ver_i="${i}-bin-${PV}"
		ln -v "${ED}/opt/${P}/bin/${i}" "${ED}/opt/${P}/bin/${ver_i}" || die
		dosym "../../opt/${P}/bin/${ver_i}" "/usr/bin/${ver_i}"
	done

	# symlinks to switch components to active rust in eselect
	dosym "../../../opt/${P}/lib" "/usr/lib/rust/lib-bin-${PV}"
	dosym "../../../opt/${P}/man" "/usr/lib/rust/man-bin-${PV}"
	dosym "../../opt/${P}/lib/rustlib" "/usr/lib/rustlib-bin-${PV}"
	dosym "../../../opt/${P}/share/doc/rust" "/usr/share/doc/${P}"

	# make all capital underscored variable
	local CARGO_TRIPLET="$(rust_abi)"
	CARGO_TRIPLET="${CARGO_TRIPLET//-/_}"
	CARGO_TRIPLET="${CARGO_TRIPLET^^}"
	cat <<-_EOF_ > "${T}/50${P}"
		MANPATH="${EPREFIX}/usr/lib/rust/man-bin-${PV}"
	$(usev elibc_musl "CARGO_TARGET_${CARGO_TRIPLET}_RUSTFLAGS=\"-C target-feature=-crt-static\"")
	_EOF_
	doenvd "${T}/50${P}"

	# note: eselect-rust adds EROOT to all paths below
	cat <<-_EOF_ > "${T}/provider-${P}"
	/usr/bin/cargo
	/usr/bin/rustdoc
	/usr/bin/rust-demangler
	/usr/bin/rust-gdb
	/usr/bin/rust-gdbgui
	/usr/bin/rust-lldb
	/usr/lib/rustlib
	/usr/lib/rust/lib
	/usr/lib/rust/man
	/usr/share/doc/rust
	_EOF_

	if use clippy; then
		echo /usr/bin/clippy-driver >> "${T}/provider-${P}"
		echo /usr/bin/cargo-clippy >> "${T}/provider-${P}"
	fi
	if use rustfmt; then
		echo /usr/bin/rustfmt >> "${T}/provider-${P}"
		echo /usr/bin/cargo-fmt >> "${T}/provider-${P}"
	fi
	if use rust-analyzer; then
		echo /usr/bin/rust-analyzer >> "${T}/provider-${P}"
	fi

	insinto /etc/env.d/rust
	doins "${T}/provider-${P}"
	popd >/dev/null || die
	#end native abi install

	else
		local rust_target
		rust_target="$(rust_abi $(get_abi_CHOST ${v##*.}))"
		dodir "/opt/${P}/lib/rustlib"
		cp -vr "${WORKDIR}/rust-${PV}-${rust_target}/rust-std-${rust_target}/lib/rustlib/${rust_target}"\
			"${ED}/opt/${P}/lib/rustlib" || die
	fi

	# BUG: installs x86_64 binary on other arches
	rm -f "${ED}/opt/${P}/lib/rustlib/"*/bin/rust-llvm-dwp || die
}

pkg_postinst() {
	eselect rust update

	if has_version dev-debug/gdb || has_version llvm-core/lldb; then
		elog "Rust installs helper scripts for calling GDB and LLDB,"
		elog "for convenience they are installed under /usr/bin/rust-{gdb,lldb}-${PV}."
	fi

	if has_version app-editors/emacs; then
		elog "install app-emacs/rust-mode to get emacs support for rust."
	fi

	if has_version app-editors/gvim || has_version app-editors/vim; then
		elog "install app-vim/rust-vim to get vim support for rust."
	fi
}

pkg_postrm() {
	eselect rust cleanup
}
