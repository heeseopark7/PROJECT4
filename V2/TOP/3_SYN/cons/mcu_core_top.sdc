#==============================================================================
# SDC : mcu_core_top (core-only track, NO pads)
#   Frozen for all versions (v1-core, v2, v3 ...). Only the clock period
#   (CLK_PERIOD) may change, and only for the clock sweep.
#   clock : clk, reset : clrn (async, active-low)
#==============================================================================

set STD_LIB_slow  slow_vdd1v0_basicCells.lib:slow_vdd1v0
set STD_LIB_fast  fast_vdd1v0_basicCells.lib:fast_vdd1v0

set_units -capacitance 1000.0fF
set_units -time 1000.0ps

#############################
reset_design
#############################
set CLK_PERIOD 10
create_clock -period $CLK_PERIOD -name MAIN_CLOCK [get_ports clk]

# Same clock model as the pad track (source/network latency 0.2 ns,
# uncertainty 0.1 ns, transition 0.1 ns)
set_clock_latency -source -max 0.2 [get_clocks MAIN_CLOCK]
set_clock_latency -max 0.2 [get_clocks MAIN_CLOCK]
set_clock_uncertainty -setup 0.1 [get_clocks MAIN_CLOCK]
set_clock_transition 0.1 [get_clocks MAIN_CLOCK]

##############################
##### input, output delay ####
##############################
# Port-based I/O timing (no pad cells). Fixed absolute values so that the
# clock sweep changes only the period. All 7 inputs except clk are async to
# the core (2-FF synchronizers), so these only bound the synchronizer paths.
set IN_DLY_MAX  1.0
set IN_DLY_MIN  0.1
set OUT_DLY_MAX 1.0
set OUT_DLY_MIN 0.0

set_input_delay  -max $IN_DLY_MAX  -clock MAIN_CLOCK [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay  -min $IN_DLY_MIN  -clock MAIN_CLOCK [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -max $OUT_DLY_MAX -clock MAIN_CLOCK [all_outputs]
set_output_delay -min $OUT_DLY_MIN -clock MAIN_CLOCK [all_outputs]

##############################
##### driving cell / load ####
##############################
# Inputs come from outside the chip: external transition 0.1 ns
# (same fix as the 2.5 ns pad-track SDC). Outputs: fixed 20 fF load.
set_input_transition 0.1 [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.02 [all_outputs]

##############################
##### Operating Condition ####
##############################
set_operating_conditions  -max_library [get_libs slow_vdd1v0_basicCells.lib:slow_vdd1v0] -max PVT_0P9V_125C -min_library [get_libs fast_vdd1v0_basicCells.lib:fast_vdd1v0] -min PVT_1P1V_0C

set_ideal_network [get_ports "clk clrn"]
