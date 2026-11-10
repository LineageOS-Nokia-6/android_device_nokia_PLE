#!/system/bin/sh

# Preserve one complete USB snapshot outside the recovery ramdisk. This is
# temporary bring-up instrumentation and must not modify any block contents.
sleep 20

mount -t ext4 /dev/block/bootdevice/by-name/cache /cache 2>/dev/null
mkdir -p /cache/recovery/lineage-usbdiag
diag=/cache/recovery/lineage-usbdiag

cat /proc/cmdline > "${diag}/cmdline.txt" 2>&1
cat /proc/mounts > "${diag}/mounts.txt" 2>&1
dmesg > "${diag}/dmesg.txt" 2>&1
getprop > "${diag}/getprop.txt" 2>&1
ps -AZ > "${diag}/ps-az.txt" 2>&1
logcat -b all -d > "${diag}/logcat-all.txt" 2>&1
ls -laR /sys/class/udc > "${diag}/udc.txt" 2>&1
ls -laR /sys/devices/platform/soc/78db000.usb > "${diag}/usb-sysfs.txt" 2>&1
ls -laR /config/usb_gadget > "${diag}/configfs.txt" 2>&1
cp /tmp/recovery.log "${diag}/recovery.log" 2>/dev/null

mkdir -p /data
mount -t ext4 /dev/block/bootdevice/by-name/userdata /data 2>"${diag}/data-mount.txt"
if [ -d /data/media/0 ]; then
    mkdir -p /data/media/0/Download/lineage-usbdiag
    cp "${diag}"/* /data/media/0/Download/lineage-usbdiag/
fi

sync
