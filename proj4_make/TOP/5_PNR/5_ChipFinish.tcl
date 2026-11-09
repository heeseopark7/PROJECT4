#######################
#### Chip Finish ######
#######################
restoreDesign RouteDesign.dat

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

# Netlist  file : -flat options is useful to next tool stages
saveNetlist -flat -excludeCellInst "PADVDD PADVSS PADVSSIOR PADVDDIOR" mcu_pad_top.v

# SDF OUT, but I recommend to use sdf file which is from Tempus tool
# SDF version 3.0 :: RECREM included in the SDF file
write_sdf mcu_pad_top.sdf

# SDF version 2.1
write_sdf -version 2.1 mcu_pad_top.sdf_2.1

# Write Out Constraint
writeTimingCon mcu_pad_top.sdc

# GDS file : without layermap file for GPDK045
streamOut mcu_pad_top.gds -libName DesignLib -units 2000 -mode ALL

exit
