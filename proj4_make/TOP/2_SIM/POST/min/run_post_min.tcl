
# HEX file is defined at ../TESTBENCH/tb_cmsdk_mcu.v 

cp ../../../5_PNR/mcu_pad_top.v ./
cp ../../../5_PNR/mcu_pad_top_post_bst.sdf ./

xrun -64bit \
     +max_err_count+50 \
     +define+sdf_post_bst \
     -access +rwc \
     -profile \
     -profthread \
     -gui \
     +libext+.v \
     ../../TESTBENCH/tb_mcu_top.v \
     mcu_pad_top.v \
     /GPDK045/digital/gsclib045_all_v4.4/gsclib045_svt_v4.4/gsclib045/verilog/fast_vdd1v0_basicCells.v \
     /GPDK045/digital/giolib045_v3.5/vlog/pads_FF_s1vg.v \
     -l post_sim_min.log

