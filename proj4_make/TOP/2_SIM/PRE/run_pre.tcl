# -timescale : To mention the time unit and time precision
# -access : Passed to the elaborator to provide read access to simulation objects
# -gui : To invoke the xrun in gui mode
# -mess : To display all to the messages in detail
# -define : To provide SDF definition present in the testbench file
# -v : To provide library in ".v" format
# +libext : library extention
# +libext+.v -y : xrun would compile .v files automatically in the specific folder decribed with -y option 

# HEX file is defined at ../TESTBENCH/tb_cmsdk_mcu.v 
cp ../../3_SYN/mapped/mcu_pad_top_syn_final.v .
cp ../../3_SYN/mapped/mcu_pad_top_delays.sdf .

xrun -64bit \
     +max_err_count+50 \
     +define+sdf_gate \
     -access +rwc \
     -profile \
     -profthread \
     -gui \
     +libext+.v \
     ../TESTBENCH/tb_mcu_top.v \
     mcu_pad_top_syn_final.v \
     /GPDK045/digital/giolib045_v3.5/vlog/pads_FF_s1vg.v \
     /GPDK045/digital//gsclib045_all_v4.4/gsclib045_svt_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
     -l pre_sim.log
