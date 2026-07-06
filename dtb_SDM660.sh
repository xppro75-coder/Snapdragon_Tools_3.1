#!/sbin/sh
dtc=/tmp/aroma/dtc
dtp=/tmp/aroma/dtp
bbox=/tmp/aroma/busybox
# magisk_boot=/tmp/aroma/magiskboot

#val1=$($bbox cat /tmp/aroma/cpu_undervolt.prop | cut -d '=' -f2)
val4=$($bbox cat /tmp/aroma/screen_refresh_rate.prop | cut -d '=' -f2)
#cpu_offset=$((($val1 - 14) * 10))

screen_refresh_rate=$(($val4 + 58))
cpu_little=$($bbox cat /tmp/aroma/cpu_little.prop | cut -d '=' -f2)
#cpu_big=$($bbox cat /tmp/aroma/cpu_big.prop | cut -d '=' -f2)
backup=$($bbox cat /tmp/aroma/backup.prop | cut -d '=' -f2)

l1843200=_0x6ddd0000_0x4040060_0x94c004c_0x03_0x08
l1958400=_0x74bad000_0x4040066_0xa520052_0x03_0x08
l2150400=_0x802c8000_0x4040070_0xb590059_0x03_0x08
l2208000=_0x839b6800_0x4040073_0xb5c005c_0x03_0x08



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

if [ "$cpu_little" = "1" ] && [ "$cpu_big" = "1" ] && [ "$val4" = "1" ]; then
	echo "Bye-bye" >> /tmp/dtp_log
	echo "error_status=0" > /tmp/aroma/status.prop
	exit 0
fi
echo "CPU voltage offset: $cpu_offset mv" >> /tmp/dtp_log

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
	dts_board_id=$($bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox grep qcom,board-id | $bbox sed -e 's/[\t]*qcom,board-id = <//g' | $bbox sed 's/>;//g')
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

# CPU overclocking!
echo "Start CPU overclocking" >> /tmp/dtp_log
#Cpu Little Adjust
echo "Cpu Little Selectbox $cpu_little" >> /tmp/dtp_log
#Restore Cpu Little
if [ "$cpu_little" = "2" ] ; then
	$bbox sed -n '2p' /tmp/aroma/sdm660.prop > /tmp/aroma/1
    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -e 's/qcom,pwrcl-speedbin0-v0/qcom,pwrcl-speedbin0-v0bak/g' -e '/qcom,pwrcl-speedbin0-v0bak/r /tmp/aroma/1' -e '/qcom,pwrcl-speedbin0-v0bak/d' > /tmp/aroma/kernel_dtb_$i.dts.bak
	
	$bbox sed -n '11p' /tmp/aroma/sdm660.prop > /tmp/aroma/1
    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts.bak | $bbox sed -e 's/qcom,cpufreq-table-0/qcom,cpufreq-table-0bak/g' -e '/qcom,cpufreq-table-0bak/r /tmp/aroma/2' -e '/qcom,cpufreq-table-0bak/d' > /tmp/aroma/kernel_dtb_$i.dts
	$bbox rm -r /tmp/aroma/2
fi
#Add Min 300mhz
if [ "$cpu_little" = "3" ] ; then
	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,cpufreq-table-0/s/<.*0x9ab00/<0x493e0_0x9ab00/' | $bbox sed '/qcom,cpufreq-table-0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
	$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
#Max 1401.6mhz
elif [ "$cpu_little" = "4" ] ; then
	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@ 0x5b8d8000.*@>;@g' > /tmp/aroma/kernel_dtb_$i.dts.bak
	$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
#Max 1536.0mhz
elif [ "$cpu_little" = "5" ] ; then
	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@ 0x68242800.*@>;@g' > /tmp/aroma/kernel_dtb_$i.dts.bak
	$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
#Max 1747.2mhz
elif [ "$cpu_little" = "6" ] ; then
	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@ 0x6ddd0000.*@>;@g' > /tmp/aroma/kernel_dtb_$i.dts.bak
	$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
fi
if [ "$cpu_little" > "6" ] ; then
	echo "Start CPU Little Overclocking" >> /tmp/dtp_log
	$bbox sed -n '15p' /tmp/aroma/sdm660.prop > /tmp/aroma/1
    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -e 's/qcom,cpufreq-table-0/qcom,cpufreq-table-0bak/g' -e '/qcom,cpufreq-table-0bak/r /tmp/aroma/1' -e '/qcom,cpufreq-table-0bak/d' | $bbox sed '/qcom,cpufreq-table-0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
	$bbox rm -r /tmp/aroma/1
	$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
	echo "CPU Little Overclock Configuration is successful " >> /tmp/dtp_log
	#Max 1958.4mhz
	if [ "$cpu_little" = "7" ] ; then
	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x6ddd0000.*/'$l1843200''$l1958400'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
	#Max 2150.4mhz
	elif [ "$cpu_little" = "8" ] ; then
	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x6ddd0000.*/'$l1843200''$l1958400''$l2150400'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
	#Max 2208.0mhz
	elif [ "$cpu_little" = "9" ] ; then
	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x6ddd0000.*/'$l1843200''$l1958400''$l2150400''$l2208000'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
	fi
	$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
	echo "Cpu Little Adjust success" >> /tmp/dtp_log
fi

# Screen refresh rate adjust

if [ "$val4" != "1" ] ; then
	rate=$(printf %x $screen_refresh_rate)
	$bbox sed -i "/qcom,mdss-dsi-panel-framerate/s/<.*>/<0x$rate>/g" /tmp/aroma/kernel_dtb_$i.dts
	$bbox sed -i "/qcom,mdss-dsi-max-refresh-rate/s/<.*>/<0x$rate>/g" /tmp/aroma/kernel_dtb_$i.dts	
	echo "Set Screen refresh rate To $screen_refresh_rate Hz" >> /tmp/dtp_log
fi

# apply voltage offset!
if [ "$cpu_offset" = "0" ]; then
echo "Voltage unchanged." >> /tmp/dtp_log
else
echo "- !! Undervolt ..." >> /tmp/dtp_log

$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox grep qcom,cpr-open-loop-voltage-fuse-adjustment > /tmp/aroma/filebuff_o
$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox grep qcom,cpr-closed-loop-voltage-fuse-adjustment >> /tmp/aroma/filebuff_o

cp /tmp/aroma/filebuff_o /tmp/aroma/filebuff_s
o_line=$($bbox cat /tmp/aroma/filebuff_o | $bbox sed -e 's/[\t]*.*<//g' | $bbox sed 's/>;//g' | wc -l)

j=1
while [ $j -le $o_line ]; do
	line=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==$j")
	open_loop_voltage_=$(echo "$line" | $bbox sed -e 's/[\t]*.*<//g' | $bbox sed 's/>;//g' | $bbox sed 's/\(0x[^ ]* \)\{4\}/&\n/g')
	first_line=$(echo "$open_loop_voltage_" | $bbox sed -n '1p')
	second_line=$(echo "$open_loop_voltage_" | $bbox sed -n '2p')
	fourth_line=$(echo "$open_loop_voltage_" | $bbox sed -n '4p')

	loop_adjust=$(echo "$fourth_line" | $bbox sed 's/ $//g')
	new_v1=$(($(echo "$loop_adjust" | awk '{print $1}') + (9 * $cpu_offset / 10) * 1000))
	new_v2=$(($(echo "$loop_adjust" | awk '{print $2}') + (9 * $cpu_offset / 10) * 1000))
	new_v3=$(($(echo "$loop_adjust" | awk '{print $3}') + $cpu_offset * 1000))
	new_v4=$(($(echo "$loop_adjust" | awk '{print $4}') + $cpu_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 | $bbox sed 's/0xf\{8\}/0x/g')
	$bbox sed -i "s/$loop_adjust/$new_v/g" /tmp/aroma/filebuff_s
	loop_adjust=$(echo "$second_line" | $bbox sed 's/ $//g')
	new_v1=$(($(echo "$loop_adjust" | awk '{print $1}') + (9 * $cpu_offset / 10) * 1000))
	new_v2=$(($(echo "$loop_adjust" | awk '{print $2}') + (9 * $cpu_offset / 10) * 1000))
	new_v3=$(($(echo "$loop_adjust" | awk '{print $3}') + $cpu_offset * 1000))
	new_v4=$(($(echo "$loop_adjust" | awk '{print $4}') + $cpu_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 | $bbox sed 's/0xf\{8\}/0x/g')
	$bbox sed -i "s/$loop_adjust/$new_v/g" /tmp/aroma/filebuff_s
	loop_adjust=$(echo "$first_line" | $bbox sed 's/ $//g')
	new_v1=$(($(echo "$loop_adjust" | awk '{print $1}') + (9 * $cpu_offset / 10) * 1000))
	new_v2=$(($(echo "$loop_adjust" | awk '{print $2}') + (9 * $cpu_offset / 10) * 1000))
	new_v3=$(($(echo "$loop_adjust" | $bbox awk '{print $3}') + $cpu_offset * 1000))
	new_v4=$(($(echo "$loop_adjust" | $bbox awk '{print $4}') + $cpu_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 | $bbox sed 's/0xf\{8\}/0x/g')
	echo "Replacing $loop_adjust with $new_v" >> /tmp/dtp_log
	$bbox sed -i "s/$loop_adjust/$new_v/g" /tmp/aroma/filebuff_s
	ori_line=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==$j")
	mod_line=$($bbox cat /tmp/aroma/filebuff_s | $bbox awk "NR==$j")
	$bbox sed -i "s/$ori_line/$mod_line/g" /tmp/aroma/kernel_dtb_$i.dts
	$bbox cp /tmp/aroma/kernel_dtb_$i.dts /sdcard/Android/backup.dts
	
	case $? in
	1)
		echo "! Unable to patched kernel_dtb_$i.dts" >> /tmp/dtp_log
		exit 1
	;;
	esac
	j=$((j + 1))
done
fi

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
