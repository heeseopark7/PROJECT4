set log file ./log/all.log -replace

read library -verilog -both \
	/GPDK045/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
	/GPDK045/digital/gsclib045_all_v4.4/gsclib045/verilog/fast_vdd1v0_basicCells.v \
	/GPDK045/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v

read design ../../3_SYN/mapped/mcu_pad_top_syn_final.v -verilog -golden

read design ../../5_PNR/mcu_pad_top.v -verilog -revised

set system mode lec

add compare points -all

compare

report verification
report statistics
