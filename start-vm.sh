
qemu-system-riscv64 \
 -machine virt -nographic -m 2048 -smp 4 \
-bios /home/sdk/trunk/src/scripts/fw_jump.bin \
-kernel /home/sdk/trunk/src/scripts/uboot.elf \
 -device virtio-net-device,netdev=eth0 -netdev user,id=eth0 \
 -device virtio-rng-pci \
 -drive file=$1,if=virtio \
 -vnc :1 \
 -serial mon:stdio \
 -device VGA \
 -device qemu-xhci,id=xhci -device usb-kbd,bus=xhci.0
 
 
