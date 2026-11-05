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
#set STD_LIB  slow_vdd1v0_basicCells.lib:slow_vdd1v0
set STD_LIB_slow  slow_vdd1v0_basicCells.lib:slow_vdd1v0
set STD_LIB_fast  fast_vdd1v0_basicCells.lib:fast_vdd1v0

set_units -capacitance 1000.0fF
set_units -time 1000.0ps

#############################
reset_design
#############################
# Below is CLOCK SPEED 
# Original Speed is 10ns and 80% adoptation is needed to ensure the stability of the chip
create_clock -period 8 -name MAIN_CLOCK [get_ports XTAL1]

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

#############################
# REFERENCE 
#set_clock_latency -source -max 0.3 [all_clocks]
#set_clock_latency -max 0.2 [all_clocks]
#set_clock_uncertainty -setup 0.3 [all_clocks]
#set_clock_uncertainty -hold 0.2 [all_clocks]
#set_clock_transition -max -rise 0.3 [all_clocks]
#set_clock_transition -max -fall 0.3 [all_clocks]
#set_clock_transition -min -rise 0.2 [all_clocks]
#set_clock_transition -min -fall 0.2 [all_clocks]

##############################
##### input, output delay ####
##############################
set_input_delay -max 0.1 -clock MAIN_CLOCK [all_inputs]
set_input_delay -min 0.01 -clock MAIN_CLOCK [all_inputs]

remove_input_delay [get_ports "XTAL1"]

set_output_delay -max 0.1 -clock MAIN_CLOCK [all_outputs]
set_output_delay -min -0.01 -clock MAIN_CLOCK [all_outputs]

##############################
#   DESIGN AREA              #
##############################
# Below is no use in Genus tool
#set_max_area 0

#############################
##### Select this point! ####
#############################
#set_driving_cell -lib_cell DFFHQX1 -pin Q [remove_from_collection [all_inputs] [get_ports clk]]

#set_driving_cell -lib_cell PADDI -pin Y -library [get_libs $STD_LIB_slow] [remove_from_collection [all_inputs] [get_ports XTAL1]]
set_driving_cell -lib_cell PADDI -pin Y -library [get_libs $STD_LIB_slow] [remove_from_collection [all_inputs] [get_ports XTAL1]]

#set_load [load_of $STD_LIB/PADDO/A] [get_ports {TDO XTAL2}]
set_load [load_of PADDO/A] [all_outputs]

##############################
##### Operating Condition ####
##############################

#set_operating_conditions PVT_1P1V_0C -library [get_libs $STD_LIB_fast] -analysis_type single
#set_operating_conditions PVT_0P9V_125C -library [get_libs $STD_LIB_slow] -analysis_type single
#set_operating_conditions -max_library PVT_0P9V_125C -min_library PVT_1P1V_0C

#set_operating_conditions  -max_library [get_libs slow_vdd1v0_basicCells.lib:slow_vdd1v0] -max PVT_0P9V_125C -min_library [get_libs slow_vdd1v0_basicCells.lib:slow_vdd1v0] -min PVT_0P9V_125C
#set_operating_conditions  -max_library [get_libs slow_vdd1v0_basicCells.lib:slow_vdd1v0] -max PVT_0P9V_125C -min_library [get_libs fast_vdd1v0_basicCells.lib:fast_vdd1v0] -min PVT_1P1V_0C

########################
# smkcow
########################
# operating conditions are define automatically when genus reads libraries with the command 'read_libs'
# So, below command is no useful in case of the single analysis type
set_operating_conditions  -max_library [get_libs slow_vdd1v0_basicCells.lib:slow_vdd1v0] -max PVT_0P9V_125C -min_library [get_libs fast_vdd1v0_basicCells.lib:fast_vdd1v0] -min PVT_1P1V_0C


###################################
#                                 #
#   ETC ATTRIBUTES                #
#                                 #
###################################

set_dont_touch u_cmsdk_mcu_system
set_dont_touch pad1 
set_dont_touch pad2 
set_dont_touch pad3 
set_dont_touch pad4 
set_dont_touch pad75 

# Below is no use in Genus tool
#set_isolate_ports [all_outputs]

set_ideal_network [get_ports "XTAL1 NRST"]
#set_ideal_network [get_pins u_cmsdk_mcu_clkctrl/hrst_reg_reg/Q]
#set_ideal_network [get_pins u_cmsdk_mcu_clkctrl/prst_reg_reg/Q]

# no through pass assign syntax => insert buffers
# Below is no use in Genus tool
#set_fix_multiple_port_nets -all -buffer_constants -feedthroughs -constants

