#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Tue Nov 10 02:14:00 2026                
#                                                     
#######################################################

#@(#)CDS: Innovus v22.17-s086_1 (64bit) 09/24/2024 10:51 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: NanoRoute 22.17-s086_1 NR240905-1647/22_17-UB (database version 18.20.629) {superthreading v2.20}
#@(#)CDS: AAE 22.17-s013 (64bit) 09/24/2024 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: CTE 22.17-s017_1 () Sep 12 2024 04:53:54 ( )
#@(#)CDS: SYNTECH 22.17-s006_1 () Aug 12 2024 03:52:27 ( )
#@(#)CDS: CPE v22.17-s051
#@(#)CDS: IQuantus/TQuantus 21.2.2-s369 (64bit) Tue May 7 14:30:42 PDT 2024 (Linux 3.10.0-693.el7.x86_64)

set_global _enable_mmmc_by_default_flow      $CTE::mmmc_default
suppressMessage ENCEXT-2799
set init_gnd_net VSS
set init_lef_file {/GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_multibitsDFF.lef /GPDK045/digital/giolib045_v3.5/lef/giolib045_modify.lef}
set init_verilog ../3_SYN/mapped/mcu_pad_top_syn_final.v
set init_mmmc_file mcu_pad_top.mmmc.view
set init_io_file init.io
set init_top_cell mcu_pad_top
set init_pwr_net VDD
init_design
checkDesign -io -netlist -physicalLibrary -powerGround -tieHilo -timingLibrary -spef -floorplan -place -outdir checkDesign
floorPlan -site CoreSite -r 1 0.6 352 352 352 352
selectInst pad5
placeInstance pad5 0.0 790.0 R270
selectInst pad6
placeInstance pad6 0.0 720.0 R270
selectInst pad17
placeInstance pad17 580.0 0.0 R0
selectInst pad18
placeInstance pad18 650.0 0.0 R0
selectInst pad29
placeInstance pad29 1423.0 580.0 R90
selectInst pad30
placeInstance pad30 1423.0 650.0 R90
selectInst pad41
placeInstance pad41 790.0 1423.1 R180
selectInst pad42
placeInstance pad42 720.0 1423.1 R180
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side n
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side s
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side w
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side e
report_analysis_views
timeDesign -prePlace
saveDesign -def InitDesign
