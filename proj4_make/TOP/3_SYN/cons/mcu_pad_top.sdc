#==============================================================================
# SDC : mcu_pad_top (chip top with pads)
#   clock : clk (pad2), reset : clrn (pad3, async, active-low)
#   Based on the cmsdk_mcu SDC of the course; port and pad names changed.
#==============================================================================

#STD_LIB_slow slow_vdd1v0_basicCells.lib:slow_vdd1v0
#   operating_conditions (PVT_0P9V_125C) {
#    process : 1;
#    temperature : 125;
#    voltage : 0.9;
#  }
#STD_LIB_fast fast_vdd1v0_basicCells.lib:fast_vdd1v0
#  operating_conditions (PVT_1P1V_0C) {
#    process : 1;
#    temperature : 0;
#    voltage : 1.1;
#}
set STD_LIB_slow  slow_vdd1v0_basicCells.lib:slow_vdd1v0
set STD_LIB_fast  fast_vdd1v0_basicCells.lib:fast_vdd1v0

set_units -capacitance 1000.0fF
set_units -time 1000.0ps

#############################
reset_design
#############################
# Clock period in ns. The CPU is single-cycle with asynchronous memories
# (pc -> ROM -> decode -> ALU -> RAM/APB mux -> register file is one path),
# so start relaxed and tighten it after looking at the timing report.
set CLK_PERIOD 5

create_clock -period $CLK_PERIOD -name MAIN_CLOCK [get_ports clk]

# External clock source and network latency is 0.2ns
set_clock_latency -source -max 0.2 [get_clocks MAIN_CLOCK]
set_clock_latency -max 0.2 [get_clocks MAIN_CLOCK]

# 60ps skew (+300ps and -300ps)
# 20ps jitter
# 20ps setup margin;
# This equals 0.1 ns of total uncertainty.
set_clock_uncertainty -setup 0.1 [get_clocks MAIN_CLOCK]

# The maximum clock transition is 0.1ns
set_clock_transition 0.1 [get_clocks MAIN_CLOCK]

##############################
##### input, output delay ####
##############################
set_input_delay -max 0.1 -clock MAIN_CLOCK [all_inputs]
set_input_delay -min 0.01 -clock MAIN_CLOCK [all_inputs]

remove_input_delay [get_ports "clk"]

set_output_delay -max 0.1 -clock MAIN_CLOCK [all_outputs]
set_output_delay -min -0.01 -clock MAIN_CLOCK [all_outputs]

##############################
##### driving cell / load ####
##############################

#chip input pins are driven from outside the pad. Assume an external driver
# with a 0.1 ns transition (same as the clock transition) instead of the
# PADDI cell, which cannot drive the large pad input load (~2.4 pF).
set_driving_cell -lib_cell PADDI -pin Y -library [get_libs $STD_LIB_slow] [remove_from_collection [all_inputs] [get_ports clk]]
#set_input_transition 0.1 [remove_from_collection [all_inputs] [get_ports clk]]
set_load [load_of PADDO/A] [all_outputs]

##############################
##### Operating Condition ####
##############################
# operating conditions are define automatically when genus reads libraries with the command 'read_libs'
set_operating_conditions  -max_library [get_libs slow_vdd1v0_basicCells.lib:slow_vdd1v0] -max PVT_0P9V_125C -min_library [get_libs fast_vdd1v0_basicCells.lib:fast_vdd1v0] -min PVT_1P1V_0C

###################################
#   ETC ATTRIBUTES                #
###################################
# Pad cells (see mcu_pad_top.v). The power / ground pads of "add_pad" are
# commented out until PnR, so they are not listed here.
#   left   : pad2 clk, pad3 clrn, pad4 UARTRXD, pad7 UARTTXD
#   bottom : pad14 SPISCLK, pad15 SPIMOSI, pad16 SPIMISO, pad19 SPICSN
#   right  : pad26 SLVSCLK, pad27 SLVMOSI, pad28 SLVMISO, pad31 SLVCSN
#   top    : pad38 UARTINTR, pad39 SPIINTR, pad40 SLVINTR
set_dont_touch pad2
set_dont_touch pad3
set_dont_touch pad4
set_dont_touch pad7
set_dont_touch pad14
set_dont_touch pad15
set_dont_touch pad16
set_dont_touch pad19
set_dont_touch pad26
set_dont_touch pad27
set_dont_touch pad28
set_dont_touch pad31
set_dont_touch pad38
set_dont_touch pad39
set_dont_touch pad40

set_ideal_network [get_ports "clk clrn"]
