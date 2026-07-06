#!/sbin/sh
dtc=/tmp/aroma/dtc
dtp=/tmp/aroma/dtp
bbox=/tmp/aroma/busybox
# magisk_boot=/tmp/aroma/magiskboot


val4=$($bbox cat /tmp/aroma/screen_refresh_rate.prop | cut -d '=' -f2)
backup=$($bbox cat /tmp/aroma/backup.prop | cut -d '=' -f2)


screen_refresh_rate=$(($val4 + 58))

$bbox touch /tmp/dtp_log
> /tmp/dtp_log

# error_status: 
# 0 or 1: OK
# 2: Something goes wrong 
$bbox touch /tmp/aroma/status.prop
echo "error_status=2" > /tmp/aroma/status.prop

if [ "$backup" = "1" ]; then
	$bbox mkdir /sdcard/bootimage
	$bbox cp /tmp/aroma/boot.img /sdcard/bootimage/boot-backup-$(date "+%Y-%m-%d-%H-%M-%S").img
	echo "Backup finished." >> /tmp/dtp_log
fi

if [ "$cpu_big_offset" = "0" ] && [ "$cpu_little_offset" = "0" ] && [ "$gpu_offset" = "0" ] && [ "$cpu_little" = "1" ] && [ "$cpu_big" = "1" ] && [ "$screen_refresh_rate" = "1" ]; then
	echo "Bye-bye" >> /tmp/dtp_log
	echo "error_status=0" > /tmp/aroma/status.prop
	exit 0
fi

echo "Screen refresh rate adjust: $screen_refresh_rate Hz" >> /tmp/dtp_log

$dtp -i kernel_dtb
if [ "$?" != "0" ]; then
	echo "Split dtb file error." >> /tmp/dtp_log
	exit 1
fi

# decompile dtb

echo "- Decompile adapted kernel_dtb..." >> /tmp/dtp_log
dtb_count=$(ls -lh kernel_dtb-* | wc -l)
board_id=$($bbox cat /proc/device-tree/qcom,board-id | $bbox xxd -p | $bbox xargs echo | $bbox sed 's/ //g' | $bbox sed 's/.\{8\}/&\n/g' | $bbox sed 's/^0\{6\}/0x/g' | $bbox sed 's/^0\{5\}/0x/g' | $bbox sed 's/^0\{4\}/0x/g' | $bbox sed 's/^0\{3\}/0x/g' | $bbox sed 's/^0\{2\}/0x/g' | $bbox sed 's/^0\{1\}x*/0x/g' | $bbox tr '\n' ' ' | $bbox sed 's/ *$/\n/g')
msm_id=$($bbox cat /proc/device-tree/qcom,msm-id | $bbox xxd -p | $bbox xargs echo | $bbox sed 's/ //g' | $bbox sed 's/.\{8\}/&\n/g' | $bbox sed 's/^0\{6\}/0x/g' | $bbox sed 's/^0\{5\}/0x/g' | $bbox sed 's/^0\{4\}/0x/g' | $bbox sed 's/^0\{3\}/0x/g' | $bbox sed 's/^0\{2\}/0x/g' | $bbox sed 's/^0\{1\}x*/0x/g' | $bbox tr '\n' ' ' | $bbox sed 's/ *$/\n/g')
echo "Device board_id: $board_id, msm_id: $msm_id" >> /tmp/dtp_log

i=0
while [ $i -lt $dtb_count ]; do
	$dtc -q -I dtb -O dts kernel_dtb-$i -o /tmp/aroma/kernel_dtb_$i.dts
	dts_board_id=$($bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox grep board-id | $bbox sed -e 's/[\t]*qcom,board-id = <//g' | $bbox sed 's/>;//g')
	dts_msm_id=$($bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox grep qcom,msm-id | $bbox sed -e 's/[\t]*qcom,msm-id = <//g' | $bbox sed 's/>;//g')
	echo "kernel_dtb_$i.dts board_id: $dts_board_id, msm_id: $dts_msm_id" >> /tmp/dtp_log
	if [ "$dts_board_id" = "$board_id" ] && [ "$dts_msm_id" = "$msm_id" ]; then
		echo "got it, let's patch kernel_dtb_$i.dts" >> /tmp/dtp_log
		break
	fi
	$bbox rm -f /tmp/aroma/kernel_dtb_$i.dts
	i=$((i + 1))
done
case $i in
$dtb_count)
	echo "! Unable to found matching kernel_dtb.dts" >> /tmp/dtp_log
	exit 1
;;
esac

# Screen refresh rate adjust

if [ "$val4" != "1" ] ; then
	rate=$(printf %x $screen_refresh_rate)
	$bbox sed -i "/qcom,mdss-dsi-panel-framerate/s/<.*>/<0x$rate>/g" /tmp/aroma/kernel_dtb_$i.dts
	$bbox sed -i "/qcom,mdss-dsi-max-refresh-rate/s/<.*>/<0x$rate>/g" /tmp/aroma/kernel_dtb_$i.dts	
	echo "Set Screen refresh rate To $screen_refresh_rate Hz" >> /tmp/dtp_log
fi

case $? in
1)
	echo "! Unable to patched kernel_dtb_$i.dts" >> /tmp/dtp_log
	exit 1
;;
esac


# compile dts to dtb
$dtc -q -I dts -O dtb /tmp/aroma/kernel_dtb_$i.dts -o kernel_dtb-$i

# generate new dtb
i=0
echo "Generating new kernel_dtb.." >> /tmp/dtp_log
> kernel_dtb
while [ $i -lt $dtb_count ]; do
	$bbox cat kernel_dtb-$i >> kernel_dtb
	i=$((i + 1))
done

echo "Done." >> /tmp/dtp_log
echo "error_status=1" > /tmp/aroma/status.prop
exit 0
