set -xe

time ./setup_board --board="riscv-usr" --binhost="/build/riscv-usr" --force 2>&1 | tee -a setup_board_logs
sudo bash copy_libs.sh
grep -r KEYWORDS sdk_container/src/third_party/gentoo/sys-apps/kexec-tools/ | grep "amd64" | grep -v '~amd64' | grep -v '~riscv' | awk -F: '{print $1}' | xargs sed -i 's/KEYWORDS="a.*/KEYWORDS="amd64 arm64 ~ppc64 x86 ~riscv"/g' || true
grep -r KEYWORDS sdk_container/src/third_party/gentoo/sys-fs/erofs-utils | grep "amd64" | grep -v '~amd64' | grep -v '~riscv' | awk -F: '{print $1}' | xargs sed -i 's/KEYWORDS="a.*/KEYWORDS="amd64 arm64 ~loong ~riscv"/g' || true
grep -r KEYWORDS sdk_container/src/third_party/gentoo/app-crypt/tpm2-tools | grep "amd64" | grep -v '~amd64' | grep -v '~riscv' | awk -F: '{print $1}' | xargs sed -i 's/KEYWORDS="a.*/KEYWORDS="~amd64 ~arm ~arm64 ~ppc64 ~x86 ~riscv"/g' || true
time ./build_packages --board="riscv-usr" 2>&1 | tee -a build_packages_logs
sudo sed -i '/hv_utils/d' /build/riscv-usr/usr/lib/dracut/modules.d/53ignition/module-setup.sh
time ./build_packages --board="riscv-usr" 2>&1 | tee -a build_packages_logs
time ./build_image --board="riscv-usr" 2>&1 | tee -a build_image_logs
time ./image_to_vm.sh --from=../build/images/riscv-usr/developer-latest --image_compression_formats none --board="riscv-usr" 2>&1 | tee -a image_to_vm_logs
bash ../build/images/riscv-usr/developer-latest/flatcar_production_qemu_uefi.sh
