#!/sbin/sh
dtc=/tmp/aroma/dtc
dtp=/tmp/aroma/dtp
bbox=/tmp/aroma/busybox
# magisk_boot=/tmp/aroma/magiskboot

val1=$($bbox cat /tmp/aroma/cpu_big_undervolt.prop | cut -d '=' -f2)
val2=$($bbox cat /tmp/aroma/gpu_undervolt.prop | cut -d '=' -f2)
val3=$($bbox cat /tmp/aroma/cpu_little_undervolt.prop | cut -d '=' -f2)
val4=$($bbox cat /tmp/aroma/screen_refresh_rate.prop | cut -d '=' -f2)
backup=$($bbox cat /tmp/aroma/backup.prop | cut -d '=' -f2)

l1900800=_0x714be800_0x4040063_0x94f004f_0x03_0x16
l1958400=_0x74bad000_0x4040066_0x9520052_0x03_0x16
l2035200=_0x794eb000_0x404006a_0x9550055_0x03_0x16
l2112000=_0x7de29000_0x404006e_0xa580058_0x03_0x16
l2208000=_0x839b6800_0x4040073_0xa5c005c_0x03_0x16
l2304000=_0x89544000_0x4040078_0xa600060_0x03_0x16
l2361600=_0x8cc32800_0x404007b_0xa620062_0x03_0x16
l2457600=_0x927c0000_0x4040080_0xa660066_0x03_0x16

l2457600=_0x927c0000_0x4040080_0xa660066_0x03_0x1e
b2476800=_0x93a0f800_0x4040081_0xa670067_0x03_0x1e
b2496000=_0x94c5f000_0x4040082_0xa680068_0x03_0x1e
b2553600=_0x9834d800_0x4040085_0xa6a006a_0x03_0x1e
b2572800=_0x9959d000_0x4040086_0xa6b006b_0x03_0x1e
b2592000=_0x9a7ec800_0x4040087_0xa6c006c_0x03_0x1e

cpu_big_offset=$((($val1 - 14) * 10))
cpu_little_offset=$((($val3 - 16) * 10))
gpu_offset=$((($val2 - 23) * 10))
screen_refresh_rate=$(($val4 + 58))
cpu_little=$($bbox cat /tmp/aroma/cpu_little.prop | cut -d '=' -f2)
cpu_big=$($bbox cat /tmp/aroma/cpu_big.prop | cut -d '=' -f2)

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

if [ "$cpu_big_offset" = "0" ] && [ "$cpu_little_offset" = "0" ] && [ "$gpu_offset" = "0" ] && [ "$cpu_little" = "1" ] && [ "$cpu_big" = "1" ] && [ "$val4" = "1" ]; then
	echo "Bye-bye" >> /tmp/dtp_log
	echo "error_status=0" > /tmp/aroma/status.prop
	exit 0
fi
echo "CPU High Cluster Voltage Offset: $cpu_big_offset mv" >> /tmp/dtp_log
echo "CPU LITTLE Cluster Voltage Offset: $cpu_little_offset mv" >> /tmp/dtp_log
echo "GPU voltage offset: $gpu_offset mv" >> /tmp/dtp_log

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

#$bbox cp /tmp/aroma/kernel_dtb_$i.dts /sdcard/work/log/1

# CPU overclocking!
echo "Start CPU overclocking" >> /tmp/dtp_log
#Cpu Little Adjust
echo "Cpu Little Selectbox $cpu_little" >> /tmp/dtp_log
if [ "$cpu_little" != "1" ] ; then
	#Restore Cpu Little
	if [ "$cpu_little" = "2" ] ; then
		$bbox sed -n '1p' /tmp/aroma/restore.prop > /tmp/aroma/1
	    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -e 's/qcom,pwrcl-speedbin0-v0/qcom,pwrcl-speedbin0-v0bak/g' -e '/qcom,pwrcl-speedbin0-v0bak/r /tmp/aroma/1' -e '/qcom,pwrcl-speedbin0-v0bak/d' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		$bbox rm -r /tmp/aroma/1

		$bbox sed -n '3p' /tmp/aroma/restore.prop > /tmp/aroma/2
	    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts.bak | $bbox sed -e 's/qcom,cpufreq-table-0/qcom,cpufreq-table-0bak/g' -e '/qcom,cpufreq-table-0bak/r /tmp/aroma/2' -e '/qcom,cpufreq-table-0bak/d' | $bbox sed '/qcom,cpufreq-table-0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts
		$bbox rm -r /tmp/aroma/2
	else
	
		#Max 1555.2mhz
		if [ "$cpu_little" = "3" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,pwrcl-speedbin0-v0/s/0x63904800.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
	
		#Max 1670.4mhz	
		elif [ "$cpu_little" = "4" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,pwrcl-speedbin0-v0/s/0x68242800.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
				
		#Max 1747.2mhz
		elif [ "$cpu_little" = "5" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,pwrcl-speedbin0-v0/s/0x6cb80800.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
			
		#Max 1824.0mhz
		elif [ "$cpu_little" = "6" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,pwrcl-speedbin0-v0/s/0x714be800.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts

		fi
	fi
	
	if [ "$cpu_little" > "6" ] ; then
		echo "Start CPU Little Overclocking" >> /tmp/dtp_log
		$bbox sed -n '1p' /tmp/aroma/overclock.prop > /tmp/aroma/1
	    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -e 's/qcom,cpufreq-table-0/qcom,cpufreq-table-0bak/g' -e '/qcom,cpufreq-table-0bak/r /tmp/aroma/1' -e '/qcom,cpufreq-table-0bak/d' | $bbox sed '/qcom,cpufreq-table-0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		$bbox rm -r /tmp/aroma/1
		$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
#		$bbox sed -i '/apc0_pwrcl_corner/,+27{/regulator-max-microvolt/s/<.*>/<0x1e>/g;/qcom,cpr-corners/s/<.*>/<0x1d>/g;/qcom,cpr-corner-fmax-map/s/0x16/0x1d/g;/qcom,cpr-speed-bin-corners/s/0x16/0x1d/g;/qcom,cpr-aging-ref-corners/<.*>/<0x1d>/g}' /tmp/aroma/kernel_dtb_$i.dts
#		$bbox sed -n '11,39p' /tmp/aroma/overclock.prop > /tmp/aroma/1
#	    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -e 's/apc0_pwrcl_corner/apc0_pwrcl_cornerbak/g' -e '/apc0_pwrcl_cornerbak/r /tmp/aroma/1' -e '/apc0_pwrcl_cornerbak/d' | $bbox sed '/Mr61sign/,+27d' > /tmp/aroma/kernel_dtb_$i.dts.bak
#		$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
#		$bbox rm -r /tmp/aroma/1
		echo "CPU Little Overclock Configuration is successful " >> /tmp/dtp_log
		#Max 1958.4mhz
		if [ "$cpu_little" = "7" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x714be800.*/'$l1900800''$l1958400'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2035.2mhz
		elif [ "$cpu_little" = "8" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x714be800.*/'$l1900800''$l1958400''$l2035200'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2112.0mhz
		elif [ "$cpu_little" = "9" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x714be800.*/'$l1900800''$l1958400''$l2035200''$l2112000'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2208.0mhz
		elif [ "$cpu_little" = "10" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x714be800.*/'$l1900800''$l1958400''$l2035200''$l2112000''$l2208000'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2304.0mhz
		elif [ "$cpu_little" = "11" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x714be800.*/'$l1900800''$l1958400''$l2035200''$l2112000''$l2208000''$l2304000'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2361.6mhz
		elif [ "$cpu_little" = "12" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x714be800.*/'$l1900800''$l1958400''$l2035200''$l2112000''$l2208000''$l2304000''$l2361600'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2457.6mhz
		elif [ "$cpu_little" = "13" ] ; then
	    		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,pwrcl-speedbin0-v0/s/0x714be800.*/'$l1900800''$l1958400''$l2035200''$l2112000''$l2208000''$l2304000''$l2361600''$l2457600'>;/' | $bbox sed '/qcom,pwrcl-speedbin0-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		fi
		$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
		if [ "$cpu_little" > "9" ] ; then
		$bbox sed -i '/qcom,pwrcl-speedbin0-v0/ s/\(.*\)0x404\(.*\)/\10x401\2/' /tmp/aroma/kernel_dtb_$i.dts
		fi
	fi
echo "Cpu Little Adjust success" >> /tmp/dtp_log	
fi

#Cpu Big Adjust
echo "Cpu Big Selectbox $cpu_big" >> /tmp/dtp_log
if [ "$cpu_big" != "1" ] ; then
	#Restore Cpu Big
	if [ "$cpu_big" = "2" ] ; then
		$bbox sed -n '2p' /tmp/aroma/restore.prop > /tmp/aroma/1	
		$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -e 's/qcom,perfcl-speedbin2-v0/qcom,perfcl-speedbin2-v0bak/g' -e '/qcom,perfcl-speedbin2-v0bak/r /tmp/aroma/1' -e '/qcom,perfcl-speedbin2-v0bak/d' | $bbox sed '/qcom,perfcl-speedbin2-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		$bbox rm -r /tmp/aroma/1
		$bbox sed -n '4p' /tmp/aroma/restore.prop > /tmp/aroma/2
		$bbox cat /tmp/aroma/kernel_dtb_$i.dts.bak | $bbox sed -e 's/qcom,cpufreq-table-4/qcom,cpufreq-table-4bak/g' -e '/qcom,cpufreq-table-4bak/r /tmp/aroma/2' -e '/qcom,cpufreq-table-4bak/d' | $bbox sed '/qcom,cpufreq-table-4/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts
		$bbox rm -r /tmp/aroma/2	
	else
		#Max 1804.8mhz
		if [ "$cpu_big" = "3" ] ; then
			$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,perfcl-speedbin2-v0/s/0x7026f000.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
		
		#Max 1958.4mhz
		elif [ "$cpu_big" = "4" ] ; then
			$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,perfcl-speedbin2-v0/s/0x794eb000.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
	
		#Max 2035.2mhz
		elif [ "$cpu_big" = "5" ] ; then
			$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,perfcl-speedbin2-v0/s/0x7de29000.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
			
		#Max 2112.0mhz
		elif [ "$cpu_big" = "6" ] ; then
			$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,perfcl-speedbin2-v0/s/0x839b6800.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
			
		#Max 2208.0mhz
		elif [ "$cpu_big" = "7" ] ; then
			$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,perfcl-speedbin2-v0/s/0x870a5000.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
			
		#Max 2265.6mhz
		elif [ "$cpu_big" = "8" ] ; then
			$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,perfcl-speedbin2-v0/s/0x8b9e3000.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
				
		#Max 2361.6mhz
		elif [ "$cpu_big" = "9" ] ; then
			$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed '/qcom,perfcl-speedbin2-v0/s/0x927c0000.*/>;/' > /tmp/aroma/kernel_dtb_$i.dts.bak
			$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
		fi
	fi
	if [ "$cpu_big" > "9" ] ; then
		echo "Start CPU Little Overclocking" >> /tmp/dtp_log
		$bbox sed -n '2p' /tmp/aroma/overclock.prop > /tmp/aroma/1
	    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -e 's/qcom,cpufreq-table-4/qcom,cpufreq-table-4bak/g' -e '/qcom,cpufreq-table-4bak/r /tmp/aroma/1' -e '/qcom,cpufreq-table-4bak/d' | $bbox sed '/qcom,cpufreq-table-4/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		$bbox rm -r /tmp/aroma/1
		$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
		$bbox sed -i '/qcom,perfcl-speedbin2-v0/ s/\(.*\)0x401\(.*\)/\10x404\2/' /tmp/aroma/kernel_dtb_$i.dts
		echo "CPU Big Overclock Configuration is successful " >> /tmp/dtp_log	
		#Max 2476.8mhz
		if [ "$cpu_big" = "10" ] ; then
		    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,perfcl-speedbin2-v0/s/0x927c0000.*/'$b2457600''$b2476800'>;/' | $bbox sed '/qcom,perfcl-speedbin2-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2496.0mhz
		elif [ "$cpu_big" = "11" ] ; then
		    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,perfcl-speedbin2-v0/s/0x927c0000.*/'$b2457600''$b2476800''$b2496000'>;/' | $bbox sed '/qcom,perfcl-speedbin2-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2553.6mhz
		elif [ "$cpu_big" = "12" ] ; then
		    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,perfcl-speedbin2-v0/s/0x927c0000.*/'$b2457600''$b2476800''$b2496000''$b2553600'>;/' | $bbox sed '/qcom,perfcl-speedbin2-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2572.8mhz
		elif [ "$cpu_big" = "13" ] ; then
		    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,perfcl-speedbin2-v0/s/0x927c0000.*/'$b2457600''$b2476800''$b2496000''$b2553600''$b2572800'>;/' | $bbox sed '/qcom,perfcl-speedbin2-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		#Max 2592.0mhz
		elif [ "$cpu_big" = "14" ] ; then
		    	$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed  '/qcom,perfcl-speedbin2-v0/s/0x927c0000.*/'$b2457600''$b2476800''$b2496000''$b2553600''$b2572800''$b2592000'>;/' | $bbox sed '/qcom,perfcl-speedbin2-v0/s@_@ @g' > /tmp/aroma/kernel_dtb_$i.dts.bak
		fi
		$bbox cp /tmp/aroma/kernel_dtb_$i.dts.bak /tmp/aroma/kernel_dtb_$i.dts
		$bbox sed -i '/qcom,perfcl-speedbin2-v0/ s/\(.*\)0x401\(.*\)/\10x404\2/' /tmp/aroma/kernel_dtb_$i.dts
	fi
echo "Cpu Big Adjust success" >> /tmp/dtp_log
fi

# apply voltage offset!

echo "- !! Undervolt ..." >> /tmp/dtp_log
gfx_cline=$($bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox grep -n 'gfx_corner' | $bbox awk '{print $1}' | $bbox sed 's/://g')
gfx_cline_=$(($gfx_cline + 25))
apc0_line=$($bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox grep -n 'apc0_pwrcl_corner' | $bbox awk '{print $1}' | $bbox sed 's/://g')
apc0_line_=$(($apc0_line + 27))
apc1_line=$($bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox grep -n 'apc1_perfcl_corner' | $bbox awk '{print $1}' | $bbox sed 's/://g')
apc1_line_=$(($apc1_line + 27))

# little cluster open-loop-voltage-fuse
$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -n "$apc0_line,$apc0_line_ p" | $bbox grep qcom,cpr-open-loop-voltage-fuse-adjustment > /tmp/aroma/filebuff_o
# big cluster open-loop-voltage-fuse
$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -n "$apc1_line,$apc1_line_ p" | $bbox grep qcom,cpr-open-loop-voltage-fuse-adjustment >> /tmp/aroma/filebuff_o
# gfx corner open-loop-voltage-fuse
$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -n "$gfx_cline,$gfx_cline_ p" | $bbox grep qcom,cpr-open-loop-voltage-fuse-adjustment >> /tmp/aroma/filebuff_o

# little cluster closed-loop-voltage-fuse
$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -n "$apc0_line,$apc0_line_ p" | $bbox grep qcom,cpr-closed-loop-voltage-fuse-adjustment >> /tmp/aroma/filebuff_o
# big cluster closed-loop-voltage-fuse
$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -n "$apc1_line,$apc1_line_ p" | $bbox grep qcom,cpr-closed-loop-voltage-fuse-adjustment >> /tmp/aroma/filebuff_o
# gfx corner closed-loop-voltage
$bbox cat /tmp/aroma/kernel_dtb_$i.dts | $bbox sed -n "$gfx_cline,$gfx_cline_ p" | $bbox grep qcom,cpr-closed-loop-voltage-adjustment >> /tmp/aroma/filebuff_o

cp /tmp/aroma/filebuff_o /tmp/aroma/filebuff_s

if [ "$cpu_little_offset" != "0" ]; then
	apc0_open_voltage_data=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==1")
	apc0_open_voltage_fuse=$(echo "$apc0_open_voltage_data" | $bbox sed -e 's/[\t]*.*<//g' | $bbox sed 's/>;//g' | $bbox sed 's/\(0x[^ ]* \)\{4\}/&\n/g' | head -n1 | sed 's/ $//g')
	new_v1=$(($(echo "$apc0_open_voltage_fuse" | $bbox awk '{print $1}') + (9 * $cpu_little_offset / 10) * 1000))
	new_v2=$(($(echo "$apc0_open_voltage_fuse" | $bbox awk '{print $2}') + (9 * $cpu_little_offset / 10) * 1000))
	new_v3=$(($(echo "$apc0_open_voltage_fuse" | $bbox awk '{print $3}') + $cpu_little_offset * 1000))
	new_v4=$(($(echo "$apc0_open_voltage_fuse" | $bbox awk '{print $4}') + $cpu_little_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 | $bbox sed 's/0xf\{8\}/0x/g')
	echo "Replacing $apc0_open_voltage_fuse with $new_v" >> /tmp/dtp_log
	$bbox sed -i "s/$apc0_open_voltage_fuse/$new_v/g" /tmp/aroma/filebuff_s
	ori_line=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==1")
	mod_line=$($bbox cat /tmp/aroma/filebuff_s | $bbox awk "NR==1")
	$bbox sed -i "s/$ori_line/$mod_line/g" /tmp/aroma/kernel_dtb_$i.dts

	apc0_closed_voltage_data=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==4")
	apc0_closed_voltage_fuse=$(echo "$apc0_closed_voltage_data" | $bbox sed -e 's/[\t]*.*<//g' | $bbox sed 's/>;//g' | $bbox sed 's/\(0x[^ ]* \)\{4\}/&\n/g' | head -n1 | sed 's/ $//g')
	new_v1=$(($(echo "$apc0_closed_voltage_fuse" | $bbox awk '{print $1}') + (9 * $cpu_little_offset / 10) * 1000))
	new_v2=$(($(echo "$apc0_closed_voltage_fuse" | $bbox awk '{print $2}') + (9 * $cpu_little_offset / 10) * 1000))
	new_v3=$(($(echo "$apc0_closed_voltage_fuse" | $bbox awk '{print $3}') + $cpu_little_offset * 1000))
	new_v4=$(($(echo "$apc0_closed_voltage_fuse" | $bbox awk '{print $4}') + $cpu_little_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 | $bbox sed 's/0xf\{8\}/0x/g')
	echo "Replacing $apc0_closed_voltage_fuse with $new_v" >> /tmp/dtp_log
	$bbox sed -i "s/$apc0_closed_voltage_fuse/$new_v/g" /tmp/aroma/filebuff_s
	ori_line=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==4")
	mod_line=$($bbox cat /tmp/aroma/filebuff_s | $bbox awk "NR==4")
	$bbox sed -i "s/$ori_line/$mod_line/g" /tmp/aroma/kernel_dtb_$i.dts
fi

if [ "$cpu_big_offset" != "0" ]; then
	apc1_open_voltage_data=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==2")
	apc1_open_voltage_fuse=$(echo "$apc1_open_voltage_data" | $bbox sed -e 's/[\t]*.*<//g' | $bbox sed 's/>;//g' | $bbox sed 's/\(0x[^ ]* \)\{4\}/&\n/g' | head -n1 | sed 's/ $//g')
	new_v1=$(($(echo "$apc1_open_voltage_fuse" | $bbox awk '{print $1}') + (9 * $cpu_big_offset / 10) * 1000))
	new_v2=$(($(echo "$apc1_open_voltage_fuse" | $bbox awk '{print $2}') + (9 * $cpu_big_offset / 10) * 1000))
	new_v3=$(($(echo "$apc1_open_voltage_fuse" | $bbox awk '{print $3}') + $cpu_big_offset * 1000))
	new_v4=$(($(echo "$apc1_open_voltage_fuse" | $bbox awk '{print $4}') + $cpu_big_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 | $bbox sed 's/0xf\{8\}/0x/g')
	echo "Replacing $apc1_open_voltage_fuse with $new_v" >> /tmp/dtp_log
	$bbox sed -i "s/$apc1_open_voltage_fuse/$new_v/g" /tmp/aroma/filebuff_s
	ori_line=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==2")
	mod_line=$($bbox cat /tmp/aroma/filebuff_s | $bbox awk "NR==2")
	$bbox sed -i "s/$ori_line/$mod_line/g" /tmp/aroma/kernel_dtb_$i.dts

	apc1_closed_voltage_data=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==5")
	apc1_closed_voltage_fuse=$(echo "$apc1_closed_voltage_data" | $bbox sed -e 's/[\t]*.*<//g' | $bbox sed 's/>;//g' | $bbox sed 's/\(0x[^ ]* \)\{4\}/&\n/g' | head -n1 | sed 's/ $//g')
	new_v1=$(($(echo "$apc1_closed_voltage_fuse" | $bbox awk '{print $1}') + (9 * $cpu_big_offset / 10) * 1000))
	new_v2=$(($(echo "$apc1_closed_voltage_fuse" | $bbox awk '{print $2}') + (9 * $cpu_big_offset / 10) * 1000))
	new_v3=$(($(echo "$apc1_closed_voltage_fuse" | $bbox awk '{print $3}') + $cpu_big_offset * 1000))
	new_v4=$(($(echo "$apc1_closed_voltage_fuse" | $bbox awk '{print $4}') + $cpu_big_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 | $bbox sed 's/0xf\{8\}/0x/g')
	echo "Replacing $apc1_closed_voltage_fuse with $new_v" >> /tmp/dtp_log
	$bbox sed -i "s/$apc1_closed_voltage_fuse/$new_v/g" /tmp/aroma/filebuff_s
	ori_line=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==5")
	mod_line=$($bbox cat /tmp/aroma/filebuff_s | $bbox awk "NR==5")
	$bbox sed -i "s/$ori_line/$mod_line/g" /tmp/aroma/kernel_dtb_$i.dts
fi

if [ "$gpu_offset" != "0" ]; then
	gfx_open_voltage_data=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==3")
	gfx_open_loop_voltage_fuse=$(echo "$gfx_open_voltage_data" | $bbox sed -e 's/[\t]*.*<//g' | $bbox sed 's/>;//g' | $bbox sed 's/\(0x[^ ]* \)\{4\}/&\n/g' | head -n1 | sed 's/ $//g')
	new_v1=$(($(echo "$gfx_open_loop_voltage_fuse" | $bbox awk '{print $1}') + (5 * $gpu_offset / 10) * 1000))
	new_v2=$(($(echo "$gfx_open_loop_voltage_fuse" | $bbox awk '{print $2}') + (6 * $gpu_offset / 10) * 1000))
	new_v3=$(($(echo "$gfx_open_loop_voltage_fuse" | $bbox awk '{print $3}') + (8 * $gpu_offset / 10) * 1000))
	new_v4=$(($(echo "$gfx_open_loop_voltage_fuse" | $bbox awk '{print $4}') + $gpu_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 | $bbox sed 's/0xf\{8\}/0x/g')
	echo "Replacing $gfx_open_loop_voltage_fuse with $new_v" >> /tmp/dtp_log
	$bbox sed -i "s/$gfx_open_loop_voltage_fuse/$new_v/g" /tmp/aroma/filebuff_s
	ori_line=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==3")
	mod_line=$($bbox cat /tmp/aroma/filebuff_s | $bbox awk "NR==3")
	$bbox sed -i "s/$ori_line/$mod_line/g" /tmp/aroma/kernel_dtb_$i.dts

	gfx_closed_voltage_data=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==6")
	gfx_closed_loop_voltage=$(echo "$gfx_closed_voltage_data" | $bbox sed -e 's/[\t]*.*<//g' | $bbox sed 's/>;//g' | $bbox sed 's/\(0x[^ ]* \)\{8\}/&\n/g' | head -n1 | sed 's/ $//g')
	new_v1=$(($(echo "$gfx_closed_loop_voltage" | $bbox awk '{print $1}') + (5 * $gpu_offset / 10) * 1000))
	new_v2=$(($(echo "$gfx_closed_loop_voltage" | $bbox awk '{print $2}') + (5 * $gpu_offset / 10) * 1000))
	new_v3=$(($(echo "$gfx_closed_loop_voltage" | $bbox awk '{print $3}') + (6 * $gpu_offset / 10) * 1000))
	new_v4=$(($(echo "$gfx_closed_loop_voltage" | $bbox awk '{print $4}') + (6 * $gpu_offset / 10) * 1000))
	new_v5=$(($(echo "$gfx_closed_loop_voltage" | $bbox awk '{print $5}') + (8 * $gpu_offset / 10) * 1000))
	new_v6=$(($(echo "$gfx_closed_loop_voltage" | $bbox awk '{print $6}') + (8 * $gpu_offset / 10) * 1000))
	new_v7=$(($(echo "$gfx_closed_loop_voltage" | $bbox awk '{print $7}') + $gpu_offset * 1000))
	new_v8=$(($(echo "$gfx_closed_loop_voltage" | $bbox awk '{print $8}') + $gpu_offset * 1000))
	new_v=$(printf "0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x\n" $new_v1 $new_v2 $new_v3 $new_v4 $new_v5 $new_v6 $new_v7 $new_v8 | $bbox sed 's/0xf\{8\}/0x/g')
	echo "Replacing $gfx_closed_loop_voltage with $new_v" >> /tmp/dtp_log
	$bbox sed -i "s/$gfx_closed_loop_voltage/$new_v/g" /tmp/aroma/filebuff_s
	ori_line=$($bbox cat /tmp/aroma/filebuff_o | $bbox awk "NR==6")
	mod_line=$($bbox cat /tmp/aroma/filebuff_s | $bbox awk "NR==6")
	$bbox sed -i "s/$ori_line/$mod_line/g" /tmp/aroma/kernel_dtb_$i.dts
fi

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
