if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name SS_Max_0p90v_125c\
   -timing\
    [list ${::IMEX::libVar}/mmmc/slow_vdd1v0_basicCells.lib\
    ${::IMEX::libVar}/mmmc/slow_vdd1v0_multibitsDFF.lib\
    ${::IMEX::libVar}/mmmc/pads_SS_s1vg.lib]
create_library_set -name FF_Min_1p10v_0c\
   -timing\
    [list ${::IMEX::libVar}/mmmc/fast_vdd1v0_basicCells.lib\
    ${::IMEX::libVar}/mmmc/fast_vdd1v0_multibitsDFF.lib\
    ${::IMEX::libVar}/mmmc/pads_FF_s1vg.lib]
create_rc_corner -name BEST\
   -cap_table ${::IMEX::libVar}/mmmc/cln28hpl_1p10m+alrdl_5x2yu2yz_typical.capTbl\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0\
   -T 0\
   -qx_tech_file ${::IMEX::libVar}/mmmc/BEST/gpdk045.tch
create_rc_corner -name WORST\
   -cap_table ${::IMEX::libVar}/mmmc/cln28hpl_1p10m+alrdl_5x2yu2yz_typical.capTbl\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0\
   -T 125\
   -qx_tech_file ${::IMEX::libVar}/mmmc/BEST/gpdk045.tch
create_delay_corner -name FF_BEST\
   -library_set FF_Min_1p10v_0c\
   -rc_corner BEST
create_delay_corner -name SS_WORST\
   -library_set SS_Max_0p90v_125c\
   -rc_corner WORST
create_constraint_mode -name FUNC\
   -sdc_files\
    [list ${::IMEX::libVar}/mmmc/mcu_pad_top_syn_final.sdc]
create_analysis_view -name FUNC_SS_WORST -constraint_mode FUNC -delay_corner SS_WORST
create_analysis_view -name FUNC_FF_BEST -constraint_mode FUNC -delay_corner FF_BEST
set_analysis_view -setup [list FUNC_SS_WORST] -hold [list FUNC_FF_BEST]
