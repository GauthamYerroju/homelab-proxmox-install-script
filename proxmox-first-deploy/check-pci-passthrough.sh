echo "========== Read GRUB kernel params =========="
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub
echo ""
echo "============= Read VFIO modules ============="
echo "------------ /etc/modules-load.d ------------"
ls /etc/modules-load.d
echo ""
echo "------- /etc/modules-load.d/vfio.conf -------"
cat /etc/modules-load.d/vfio.conf
echo ""
echo "============== /etc/modprobe.d =============="
ls /etc/modprobe.d
echo ""
echo "----------- Read vfio-pci binding -----------"
cat /etc/modprobe.d/vfio-pci.conf
echo ""
echo "---------- Read blacklisted drivers ---------"
cat /etc/modprobe.d/blacklist-passthrough.conf
