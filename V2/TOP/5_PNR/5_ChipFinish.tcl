#######################
#### Chip Finish ######
#######################
#restoreDesign RouteDesign.dat

# Add Filler
getFillerMode -quiet
addFiller -cell FILL1 FILL8 FILL64 FILL4 FILL32 FILL2 FILL16 -prefix FILLER

# DRC
verify_drc

# LVS : Connectivity 
verifyConnectivity -type all -geomConnect -error 1000 -warning 50

# Error Browser
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer

# Extraction 
extractRC

# If there is no error, save Design
saveDesign -rc -def ChipFinish

## Snapshot after save (needs the GUI; catch keeps the script running without it)
file mkdir snap
catch {fit}
catch {gui_dump_picture snap/5_chipfinish.png -format PNG}

#####################
#### Write Out ######
#####################
# Write Out Files

# Netlist  file : NO -flat option. A hierarchical netlist keeps the instance names the same as the SDF (hierarchy divider "/"),
#                 so the SDF can be back-annotated in the post-layout simulation.
saveNetlist mcu_core_top.v

# SDF OUT, but I recommend to use sdf file which is from Tempus tool
# SDF version 3.0 :: RECREM included in the SDF file
write_sdf mcu_core_top.sdf

# SDF version 2.1
write_sdf -version 2.1 mcu_core_top.sdf_2.1

# Write Out Constraint
writeTimingCon mcu_core_top.sdc

# GDS file : without layermap file for GPDK045
streamOut mcu_core_top.gds -libName DesignLib -units 2000 -mode ALL

#exit
