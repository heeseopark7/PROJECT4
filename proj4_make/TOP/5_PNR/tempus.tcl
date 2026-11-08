
## Practice 0.

################
### SET UP #####
################
# If you open design in GUI, just type <RouteDesign_mmmc1> in the window
# Below is for the tempus shell
read_design RouteDesign.dat cmsdk_mcu ; #mmmc2 format is for -stylus

check_timing ;# Warnings are skipped
report_annotated_parasitics ; # Check if real net (complete) is 100%
report_analysis_coverage ; # Determine violated spots are all 0 

# Deal with DataCheckSetup and DataCheckHold :: Constant is skipped
report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const

##################
#### FILE OUT ####
##################
write_sdf -view FUNC_SS_WORST cmsdk_mcu_post_wst.sdf
write_sdf -view FUNC_FF_BEST cmsdk_mcu_post_bst.sdf 
exit

## Practice 1.
################
### SET UP #####
################
# If you open design in GUI, just type <RouteDesign_mmmc1> in the window
# Below is for the tempus shell
#read_design RouteDesign_for_ECO.dat cmsdk_mcu ; #mmmc2 format is for -stylus

#check_timing ;# Warnings are skipped
#report_annotated_parasitics ; # Check if real net (complete) is 100%
#report_analysis_coverage ; # Determine violated spots are all 0 

# Deal with DataCheckSetup and DataCheckHold :: Constant is skipped
#report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const

##############################
### BELOW is ECO #############
### From FIX HOLD to CHECK ###
##############################
# If your design should be fixed, Do below FIX HOLD & CHECK sections
# If your design should not be fixed, just go to FILE OUT section

#######################
### ECO 0: FIX HOLD ###
#######################
# First, Timing SI -> Debug Timing -> Browse -> Generate (Turn on ) -> Check Type (Setup OR Hold)
# Select Point -> Click Mouse Right Button -> Show Timing Path Analyzer
# Interactive ECO/WhatIf -> Add Repeater
# Evaluation Type -> Early -> New Cells -> Select Buf Cell -> Apply -> Close

# TIP : add_repeater at the last net which is connected End Point

#add_repeater -cell BUFX2 -net in_NRST
#add_repeater -cell BUFX2 -net XTAL2
#add_repeater -cell BUFX2 -net HCLKSYS

#######################
#### ECO 1 : CHECK ####
#######################

#report_analysis_coverage ; # Determine violated spots are all 0

# Deal with DataCheckSetup and DataCheckHold :: Constant is skipped
#report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const

#write_eco -format innovus -output innovus.eco; # Last action of ECO
####################################################################################

## Practice 2.
################
### SET UP #####
################
# If you open design in GUI, just type <RouteDesign_mmmc1> in the window
# Below is for the tempus shell
#read_design ChipFinish_after_ECO.dat cmsdk_mcu ; #mmmc2 format is for -stylus

#check_timing ;# Warnings are skipped
#report_annotated_parasitics ; # Check if real net (complete) is 100%
#report_analysis_coverage ; # Determine violated spots are all 0 

# Deal with DataCheckSetup and DataCheckHold :: Constant is skipped
#report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const

##################
#### FILE OUT ####
##################
#write_sdf -view FUNC_SS_WORST cmsdk_mcu_post_wst.sdf
#write_sdf -view FUNC_FF_BEST cmsdk_mcu_post_bst.sdf 
