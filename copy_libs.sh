#set -x
SYSROOT="/usr/riscv64-cros-linux-gnu"
ROOT="/build/riscv-usr"

for d in "${SYSROOT}"/{,usr/}{bin,sbin,lib*}; do
        if [[ ! -d ${d} ]]; then
                echo "${d} folder does not exist"
                continue
        fi
        files=( "${d}"/* )
        if [[ ${#files[@]} -gt 0 ]]; then
                f=${d##*/}
                sudo mkdir "${ROOT}/usr/${f}"
                sudo cp -at "${ROOT}/usr/${f}" "${files[@]}"
                echo "copy to ${ROOT}/usr/${f}: ${files[@]}"
        fi
done
echo "copy to ${ROOT}/usr: ${SYSROOT}/usr/include"
sudo mkdir "${ROOT}"/usr
sudo cp -at "${ROOT}"/usr "${SYSROOT}"/usr/include 
