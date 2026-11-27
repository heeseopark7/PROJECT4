#==============================================================================
# SDC : mcu_core_top (core-only track, NO pads)
#   Identical to V1 (mcu_pad_top.sdc) except the pad-related lines.
#   Frozen for all versions; only the clock period may change (clock sweep).
#   clock : clk, reset : clrn (async, active-low)
#==============================================================================

set STD_LIB_slow  slow_vdd1v0_basicCells.lib:slow_vdd1v0
set STD_LIB_fast  fast_vdd1v0_basicCells.lib:fast_vdd1v0

set_units -capacitance 1000.0fF
set_units -time 1000.0ps

#############################
reset_design
#############################
create_clock -period 4.25 -name MAIN_CLOCK [get_ports clk]

# Same clock model as the pad track (source/network latency 0.2 ns,
# uncertainty 0.1 ns, transition 0.1 ns)
set_clock_latency -source -max 0.2 [get_clocks MAIN_CLOCK]
set_clock_latency -max 0.2 [get_clocks MAIN_CLOCK]
set_clock_uncertainty -setup 0.1 [get_clocks MAIN_CLOCK]
set_clock_transition 0.1 [get_clocks MAIN_CLOCK]

##############################
##### input, output delay ####
##############################
# Same as V1 (mcu_pad_top.sdc).
set_input_delay -max 0.1 -clock MAIN_CLOCK [all_inputs]
set_input_delay -min 0.01 -clock MAIN_CLOCK [all_inputs]

remove_input_delay [get_ports "clk"]

set_output_delay -max 0.1 -clock MAIN_CLOCK [all_outputs]
set_output_delay -min -0.01 -clock MAIN_CLOCK [all_outputs]

##############################
##### driving cell / load ####
##############################
# PAD-RELATED (the only part that cannot be identical to V1):
#   V1 : set_driving_cell -lib_cell PADDI ... (active line; V1 comment says an
#        external 0.1 ns transition was intended) and set_load [load_of PADDO/A]
#   V2 : no pad cells and the pad library is not read, so PADDI/PADDO cannot be
#        referenced.
# Inputs : external transition 0.1 ns (the value V1's own comment describes).
# Outputs: 3.0 fF = pin cap of PADDO/A as reported by V1
#          (V1/TOP/3_SYN/report/02_report_port.rpt, External Loads: 3.0 for all
#          8 outputs; unit assumed fF, set_units -capacitance is 1000fF = 1 pF).
set_input_transition 0.1 [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.003 [all_outputs]

##############################
##### Operating Condition ####
##############################
set_operating_conditions  -max_library [get_libs slow_vdd1v0_basicCells.lib:slow_vdd1v0] -max PVT_0P9V_125C -min_library [get_libs fast_vdd1v0_basicCells.lib:fast_vdd1v0] -min PVT_1P1V_0C

set_ideal_network [get_ports "clk clrn"]
