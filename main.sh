#!/sbin/sh
bbox=/tmp/aroma/busybox
select=$($bbox cat /tmp/aroma/select.prop | cut -d '=' -f2)

$bbox touch /tmp/main_log
> /tmp/main_log

echo "CPU Select $select" >> /tmp/main_log


if [ "$select" = "1" ] ; then
	$bbox sh /tmp/aroma/dtb_MSM8953.sh
elif [ "$select" = "2" ] ; then
	$bbox sh /tmp/aroma/dtb_SDM660.sh
elif [ "$select" = "3" ] ; then
	$bbox sh /tmp/aroma/dtb_MSM8998.sh
elif [ "$select" = "4" ] ; then
	$bbox sh /tmp/aroma/common.sh
fi

$bbox cp /tmp/dtp_log /sdcard/dtp_log
