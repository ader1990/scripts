# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit go-module

DESCRIPTION="Generate a Software Bill of Materials from container images and filesystems"
HOMEPAGE="https://www.anchore.com"
SRC_URI="https://github.com/anchore/syft/archive/v${PV}.tar.gz -> ${P}.tar.gz"
SRC_URI+=" https://dev.gentoo.org/~williamh/dist/${P}-deps.tar.xz"

LICENSE="Apache-2.0"
SLOT="0"
# Flatcar: keyword for arm64 ~riscv and amd64
KEYWORDS="amd64 arm64 ~riscv"

src_compile() {
	# Flatcar: add ldflags to set version
	ego build -o bin/syft -ldflags "-X github.com/anchore/syft/internal/version.version=${PV}" ./cmd/syft
}

src_install() {
	dobin bin/*
}
