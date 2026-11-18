#######################################################
#                                                     
#  Tempus Timing Solution Command Logging File                     
#  Created on Wed Nov 11 04:38:37 2026                
#                                                     
#######################################################

#@(#)CDS: Tempus Timing Solution v22.17-s087_1 (64bit) 10/01/2024 11:02 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: NanoRoute 22.17-s087_1 NR240905-1647/22_17-UB (database version 18.20.629) {superthreading v2.20}
#@(#)CDS: AAE 22.17-s014 (64bit) 10/01/2024 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: CTE 22.17-s017_1 () Sep 12 2024 04:53:54 ( )
#@(#)CDS: SYNTECH 22.17-s006_1 () Aug 12 2024 03:52:27 ( )
#@(#)CDS: CPE v22.17-s051

::stop_gui -keepDgui
read_design RouteDesign.dat mcu_pad_top
check_timing 
report_annotated_parasitics
report_analysis_coverage 
report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const
write_sdf -view FUNC_SS_WORST mcu_pad_top_post_wst.sdf
write_sdf -view FUNC_FF_BEST mcu_pad_top_post_bst.sdf
exit
