set log file ./log/all.log -replace

read library -verilog -both \
	../../../../SoC/GPDK045/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
	../../../../SoC/GPDK045/digital/gsclib045_all_v4.4/gsclib045/verilog/fast_vdd1v0_basicCells.v \
	../../../../SoC/GPDK045/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v

read design ../1_RTL/mcu_pad_top.v \
	    ../1_RTL/mcu_top.v \
	    ../1_RTL/apb_bridge.v \
	    ../1_RTL/baud_gen.v \
	    ../1_RTL/interrupt_logic.v \
	    ../1_RTL/reg_block.v \
	    ../1_RTL/rx_fifo.v \
	    ../1_RTL/rx_logic.v \
	    ../1_RTL/sccpu.v \
	    ../1_RTL/scdatamem.v \
	    ../1_RTL/scinstmem.v \
	    ../1_RTL/sclk_gen.v \
	    ../1_RTL/spi_apb_top.v \
	    ../1_RTL/spi_master.v \
	    ../1_RTL/spi_regs.v \
	    ../1_RTL/spi_slave.v \
	    ../1_RTL/spi_slave_apb_top.v \
	    ../1_RTL/spis_regs.v \
	    ../1_RTL/tx_fifo.v \
	    ../1_RTL/tx_logic.v \
	    ../1_RTL/uart_ex_top.v -verilog -golden

read design ../3_SYN/mapped/mcu_pad_top_syn_final.v -verilog -revised

set system mode lec

add compare points -all

compare

report verification
report statistics
