# -timescale : To mention the time unit and time precision
# -access : Passed to the elaborator to provide read access to simulation objects
# -gui : To invoke the xrun in gui mode
# -mess : To display all to the messages in detail
# -define : To provide SDF definition present in the testbench file
# -v : To provide library in ".v" format
# +libext : library extention
# +libext+.v -y : xrun would compile .v files automatically in the specific folder decribed with -y option

# Target : mcu_top (CPU + memories + APB bridge) with ../TESTBENCH/tb_mcu_top.v
# The test program is written inside tb_mcu_top.v (no HEX file is needed).
# The RTL files are in ../../1_RTL. UART, SPI master and SPI slave are
# connected in mcu_top.v, so their files are listed below.
xrun -64bit \
     +max_err_count+50 \
     +define+function_sim \
     -access +rwc \
     -profile \
     -profthread \
     -gui \
     +libext+.v \
     -incdir ../../1_RTL \
     -incdir ../TESTBENCH \
     -top tb_mcu_top \
     ../TESTBENCH/tb_mcu_top.v \
     ../../1_RTL/mcu_top.v \
     ../../1_RTL/sccpu.v \
     ../../1_RTL/scinstmem.v \
     ../../1_RTL/scdatamem.v \
     ../../1_RTL/apb_bridge.v \
     ../../1_RTL/uart_ex_top.v \
     ../../1_RTL/baud_gen.v \
     ../../1_RTL/tx_fifo.v \
     ../../1_RTL/rx_fifo.v \
     ../../1_RTL/tx_logic.v \
     ../../1_RTL/rx_logic.v \
     ../../1_RTL/reg_block.v \
     ../../1_RTL/interrupt_logic.v \
     ../../1_RTL/spi_apb_top.v \
     ../../1_RTL/spi_regs.v \
     ../../1_RTL/sclk_gen.v \
     ../../1_RTL/spi_master.v \
     ../../1_RTL/spi_slave_apb_top.v \
     ../../1_RTL/spis_regs.v \
     ../../1_RTL/spi_slave.v \
     /GPDK045/digital/giolib045_v3.5/vlog/pads_FF_s1vg.v \
     /GPDK045/digital/gsclib045_all_v4.4/gsclib045_svt_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
     -l func_sim.log
