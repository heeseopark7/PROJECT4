
########################################
# InitDesign (Setup, Floorplan)
########################################

## Initialization
set init_gnd_net VSS
set init_lef_file {/GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_multibitsDFF.lef}
set init_verilog ../3_SYN/mapped/mcu_core_top_syn_final.v
set init_mmmc_file mcu_core_top.mmmc.view
set init_top_cell mcu_core_top
set init_pwr_net VDD
init_design

## Check Design
checkDesign -io -netlist -physicalLibrary -powerGround -tieHilo -timingLibrary -spef -floorplan -place -outdir checkDesign

########################################################
## Floorplan :: CORE ONLY (no pad ring)
## utilization 0.6 (same as V1), margins fit the core power ring (about 20 um)
########################################################
floorPlan -site CoreSite -r 1 0.6  30 30 30 30

## IO Pin Placement (V1 pad sides: left clk/clrn/UART, bottom SPI master, right SPI slave, top interrupts)
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Left   -layer 3 -spreadType center -spacing 10.0 -pin {clk clrn UARTRXD UARTTXD}
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Bottom -layer 4 -spreadType center -spacing 10.0 -pin {SPISCLK SPIMOSI SPIMISO SPICSN}
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Right  -layer 3 -spreadType center -spacing 10.0 -pin {SLVSCLK SLVMOSI SLVMISO SLVCSN}
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Top    -layer 4 -spreadType center -spacing 10.0 -pin {UARTINTR SPIINTR SLVINTR}
setPinAssignMode -pinEditInBatch false

# Verify Timing
report_analysis_views 
timeDesign -prePlace

## If there is no error, Save Design
saveDesign -def InitDesign

fit
gui_dump_picture snap/0_floorplan.png -format PNG
#exit
