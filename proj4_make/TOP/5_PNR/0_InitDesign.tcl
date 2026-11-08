
########################################
# InitDesign (Setup, Floorplan)
########################################

## Initialization
set init_gnd_net VSS
set init_lef_file {/GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_multibitsDFF.lef /GPDK045/digital/giolib045_v3.5/lef/giolib045_modify.lef}
set init_verilog ../3_SYN/mapped/mcu_pad_top_syn_final.v
set init_mmmc_file mcu_pad_top.mmmc.view
set init_io_file init.io
set init_top_cell mcu_pad_top
set init_pwr_net VDD
init_design

## Check Design
checkDesign -io -netlist -physicalLibrary -powerGround -tieHilo -timingLibrary -spef -floorplan -place -outdir checkDesign

##################################################
## Floorplan :: Below is for CHIP AREA (1370,1370)
##################################################
#floorPlan -site CoreSite -s 700 700 1425 1425 1425 1425; almost 70%
floorPlan -site CoreSite -r 1 0.6  352 352 352 352

## Move IO Cells (PADVDD, PADVSS)
selectInst pad5
placeInstance pad5 0.0 790.0 R270
selectInst pad6
placeInstance pad6 0.0 720.0 R270
selectInst pad17
placeInstance pad17 580.0 0.0 R0
selectInst pad18
placeInstance pad18 650.0 0.0 R0
selectInst pad29
placeInstance pad29 1130.0 580.0 R90
selectInst pad30
placeInstance pad30 1130.0 650.0 R90
selectInst pad41
placeInstance pad41 790.0 1130.0 R180
selectInst pad42
placeInstance pad42 720.0 1130.0 R180

## IO Filler Insertion
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side n
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side s
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side w
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side e

# Verify Timing
report_analysis_views 
timeDesign -prePlace

## If there is no error, Save Design
saveDesign -def InitDesign
exit
