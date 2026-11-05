# -timescale : To mention the time unit and time precision
# -access : Passed to the elaborator to provide read access to simulation objects
# -gui : To invoke the xrun in gui mode
# -mess : To display all to the messages in detail
# -define : To provide SDF definition present in the testbench file
# -v : To provide library in ".v" format
# +libext : library extention
# +libext+.v -y : xrun would compile .v files automatically in the specific folder decribed with -y option 

# HEX file is defined at ../TESTBENCH/tb_cmsdk_mcu.v 
xrun -64bit \
     +max_err_count+50 \
     +define+function_sim \
     -access +rwc \
     -profile \
     -profthread \
     -gui \
     +libext+.v \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_apb_timer/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_apb_dualtimers/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_apb_uart/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_apb_watchdog/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_apb_slave_mux/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_apb_subsystem/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_ahb_slave_mux/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_ahb_default_slave/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_ahb_gpio/verilog \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_ahb_to_apb/verilog \
     -incdir ../../../../cortexm0_designstart/logical/models/clkgate \
     -incdir ../../../../cortexm0_designstart/logical/cmsdk_iop_gpio/verilog \
     -incdir ../../../../cortexm0_designstart/cores/cortexm0_designstart_r1p0/logical/cortexm0_integration/verilog \
     -incdir ../../../../cortexm0_designstart/cores/cortexm0_designstart_r1p0/logical/cortexm0_dap/verilog \
     -incdir ../../../../cortexm0_designstart/cores/cortexm0_designstart_r1p0/logical/models/cells \
     -incdir ../../../../cortexm0_designstart/cores/cortexm0_designstart_r1p0/logical/cortexm0ds/verilog \
     -incdir ../../../../SoC_make_G45/TOP/RTL/memories_smkcow_1 \
     -incdir ../../../../SoC_make_G45/TOP/RTL/verilog_smkcow \
     -incdir ../../../../SoC_make_G45/TOP/RTL \
     -incdir ../TESTBENCH \
     -y ../../../../cortexm0_designstart/logical/cmsdk_apb_timer/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_apb_dualtimers/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_apb_uart/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_apb_watchdog/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_apb_slave_mux/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_apb_subsystem/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_ahb_slave_mux/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_ahb_default_slave/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_ahb_gpio/verilog \
     -y ../../../../cortexm0_designstart/logical/cmsdk_ahb_to_apb/verilog \
     -y ../../../../cortexm0_designstart/logical/models/clkgate \
     -y ../../../../cortexm0_designstart/logical/cmsdk_iop_gpio/verilog \
     -y ../../../../cortexm0_designstart/cores/cortexm0_designstart_r1p0/logical/cortexm0ds/verilog \
     -y ../../../../cortexm0_designstart/cores/cortexm0_designstart_r1p0/logical/cortexm0_integration/verilog \
     -y ../../../../cortexm0_designstart/cores/cortexm0_designstart_r1p0/logical/cortexm0_dap/verilog \
     -y ../../../../cortexm0_designstart/cores/cortexm0_designstart_r1p0/logical/models/cells \
     -y ../../../../GPDK045/digital/giolib045_v3.5/vlog \
     -y ../../../../GPDK045/digital//gsclib045_all_v4.4/gsclib045_svt_v4.4/gsclib045/verilog \
     -y ../../../../GPDK045/digital \
     -y ../../../../SoC_make_G45/TOP/RTL/verilog_smkcow \
     -y ../../../../SoC_make_G45/TOP/RTL \
     ../TESTBENCH/tb_cmsdk_mcu.v \
     ../../../../SoC_make_G45/TOP/RTL/cmsdk_mcu.v \
     ../../RTL/memories_smkcow_1/cmsdk_ahb_ram.v \
     ../../RTL/memories_smkcow_1/cmsdk_ahb_ram_beh.v \
     ../../RTL/memories_smkcow_1/cmsdk_ahb_rom.v \
     ../../RTL/memories_smkcow_1/cmsdk_ahb_rom_beh.v \
     ../../../../GPDK045/digital/giolib045_v3.5/vlog/pads_FF_s1vg.v \
     ../../../../GPDK045/digital/gsclib045_all_v4.4/gsclib045_svt_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
     -l func_sim.log
