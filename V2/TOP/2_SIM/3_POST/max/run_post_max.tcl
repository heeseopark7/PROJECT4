
# HEX file is defined at ../TESTBENCH/tb_cmsdk_mcu.v 

cp ../../../5_PNR/mcu_core_top.v ./
cp ../../../5_PNR/mcu_core_top_post_wst.sdf ./

xrun -64bit \
     +max_err_count+50 \
     +define+sdf_post_wst \
     -access +rwc \
     -profile \
     -profthread \
     -gui \
     +libext+.v \
     ../../4_TESTBENCH/tb_mcu_top.v \
     mcu_core_top.v \
     /GPDK045/digital/gsclib045_all_v4.4/gsclib045_svt_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
     -l post_sim_max.log

