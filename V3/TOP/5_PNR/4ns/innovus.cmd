#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Thu Nov 26 00:28:21 2026                
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
win
set enc_check_rename_command_name 1
set init_gnd_net VSS
set init_lef_file {/GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_multibitsDFF.lef}
set init_verilog ../../3_SYN/4ns/mapped/mcu_core_top_syn_final.v
set init_mmmc_file mcu_core_top.mmmc.view
set init_top_cell mcu_core_top
set init_pwr_net VDD
init_design
checkDesign -io -netlist -physicalLibrary -powerGround -tieHilo -timingLibrary -spef -floorplan -place -outdir checkDesign
floorPlan -site CoreSite -r 1 0.6 30 30 30 30
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Left -layer 3 -spreadType center -spacing 10.0 -pin {clk clrn UARTRXD UARTTXD}
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Bottom -layer 4 -spreadType center -spacing 10.0 -pin {SPISCLK SPIMOSI SPIMISO SPICSN}
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Right -layer 3 -spreadType center -spacing 10.0 -pin {SLVSCLK SLVMOSI SLVMISO SLVCSN}
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Top -layer 4 -spreadType center -spacing 10.0 -pin {UARTINTR SPIINTR SLVINTR}
setPinAssignMode -pinEditInBatch false
report_analysis_views
timeDesign -prePlace
saveDesign -def InitDesign
fit
gui_dump_picture snap/0_floorplan.png -format PNG
globalNetConnect VDD -type pgpin -pin VDD -instanceBasename *
globalNetConnect VSS -type pgpin -pin VSS -instanceBasename *
globalNetConnect VDD -type tiehi -instanceBasename *
globalNetConnect VSS -type tielo -instanceBasename *
setTieHiLoMode -reset
setTieHiLoMode -cell {  TIELO TIEHI } -honorDontTouch false -createHierPort false
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top Metal11 bottom Metal11 left Metal10 right Metal10} -width {top 5 bottom 5 left 5 right 5} -spacing {top 5 bottom 5 left 5 right 5} -offset {top 5 bottom 5 left 5 right 5} -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None
setSrouteMode -viaConnectToShape { noshape }
sroute -connect { corePin } -layerChangeRange { Metal1(1) Metal11(11) } -blockPinTarget { nearestTarget } -corePinTarget { firstAfterRowEnd } -allowJogging 1 -crossoverViaLayerRange { Metal1(1) Metal11(11) } -nets { VDD VSS } -allowLayerChange 1 -targetViaLayerRange { Metal1(1) Metal11(11) }
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring } -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape   }
addStripe -nets {VDD VSS} -layer Metal10 -direction vertical -width 5 -spacing 5 -set_to_set_distance 100 -start_from left -start_offset 10 -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal11 -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring } -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape   }
addStripe -nets {VDD VSS} -layer Metal10 -direction vertical -width 5 -spacing 5 -set_to_set_distance 100 -start_from left -start_offset 50 -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal11 -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring } -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape   }
addStripe -nets {VDD VSS} -layer Metal11 -direction horizontal -width 5 -spacing 5 -set_to_set_distance 100 -start_from bottom -start_offset 50 -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal11 -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None
set_verify_drc_mode -area {0 0 0 0}
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false -use_min_spacing_on_block_obs auto -report mcu_core_top.drc.rpt -limit 1000
verify_drc
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer
verifyConnectivity -type all -noOpen -noAntenna -noWeakConnect -noUnConnPin -noUnroutedNet -error 1000 -warning 50
verifyConnectivity -type special -error 1000 -warning 50 -report mcu_core_top.pgconn.rpt
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer
saveDesign -def PowerPlan
fit
gui_dump_picture snap/1_powerplan.png -format PNG
violationBrowser -all -no_display_false -displayByLayer
violationBrowserClose
zoomBox 3.91150 278.69850 87.94650 196.93500
setPlaceMode -place_global_cong_effort high
place_design
checkPlace mcu_core_top.checkPlace
setRouteMode -earlyGlobalMinRouteLayer 1 -earlyGlobalMaxRouteLayer 11 -earlyGlobalHonorMsvRouteConstraint false -earlyGlobalRoutePartitionPinGuide true
earlyGlobalRoute
reportCongestion -hotSpot
reportCongestion -overflow
setDrawView place
setLayerPreference densityMap -isVisible 1
setLayerPreference densityMap -isVisible 0
setLayerPreference pinDensityMap -isVisible 1
setLayerPreference pinDensityMap -isVisible 0
place_opt_design
earlyGlobalRoute
reportCongestion -hotSpot
reportCongestion -overflow
timeDesign -preCTS -outDir reports/timing/preCTS
checkDesign -place
saveDesign -def PlaceOpt
fit
gui_dump_picture snap/2_placement.png -format PNG
report_timing -max_paths 1 > reports/timing/preCTS_worst.rpt
highlight 0x7f2940d1c240 -index 4
highlight 0x7f2940d1c7e0 -index 3
highlight 0x7f2940d1c6c0 -index 13
highlight 0x7f2940d1ca20 -index 6
highlight 0x7f2940d1d9e0 -index 15
highlight 0x7f2940d1d9e0 -index 31
highlight 0x7f2940d1d560 -index 5
highlight 0x7f2940d1c900 -index 1
setLayerPreference densityMap -isVisible 1
dehighlight {0x7f2940d1c7e0 0x7f2940d1ca20 0x7f2940d1c6c0 0x7f2940d1d560 0x7f2940d1d9e0 0x7f2940d1c900}
fit
dehighlight 0x7f2940d1c240
setLayerPreference densityMap -isVisible 0
reportCongestion -overflow
report_timing -max_paths 1 > reports/timing/preCTS_worst.rpt
report_timing -max_paths 10 -format {endpoint slack} > reports/timing/preCTS_top10.rpt
report_timing -max_paths 10 > reports/timing/preCTS_top10.rpt
set_ccopt_property target_skew 0.01
create_ccopt_clock_tree_spec
ccopt_design
all_constraint_modes -active
set_interactive_constraint_modes [all_constraint_modes -active] 
set_propagated_clock [all_clocks]
timeDesign -postCTS -outDir reports/timing/postCTS
report_ccopt_clock_trees -file reports/clock/clock_trees.rpt
report_ccopt_skew_groups -file reports/clock/skew_groups.rpt
report_clock_timing -type skew -nworst 5 > reports/clock/skew.rpt
optDesign -postCTS
optDesign -postCTS -hold
timeDesign -postCTS -outDir reports/timing/postCTS
timeDesign -postCTS -outDir reports/timing/postCTS -hold
saveDesign -def PostCTSopt
fit
gui_dump_picture snap/3_cts.png -format PNG
report_timing -max_paths 1 > reports/timing/postCTS_worst.rpt
report_timing -max_paths 10 > reports/timing/postCTS_top10.rpt
ctd_win -side none -id ctd_window
setNanoRouteMode -quiet -drouteFixAntenna 1
setNanoRouteMode -quiet -routeInsertAntennaDiode 0
setNanoRouteMode -quiet -routeWithTimingDriven 1
setNanoRouteMode -quiet -routeWithEco 0
setNanoRouteMode -quiet -routeWithLithoDriven 0
setNanoRouteMode -quiet -droutePostRouteLithoRepair 0
setNanoRouteMode -quiet -routeWithSiDriven 1
setNanoRouteMode -quiet -routeTdrEffort 8
setNanoRouteMode -quiet -drouteAutoStop 0
setNanoRouteMode -quiet -routeSelectedNetOnly 0
setNanoRouteMode -quiet -routeTopRoutingLayer 11
setNanoRouteMode -quiet -routeBottomRoutingLayer 1
setNanoRouteMode -quiet -drouteEndIteration 5
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
routeDesign -globalDetail
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false -use_min_spacing_on_block_obs auto -report mcu_core_top.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
setAnalysisMode -analysisType onChipVariation
optDesign -postRoute -drv
verifyConnectivity -type all -geomConnect -error 1000 -warning 50
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer
extractRC
setDelayCalMode -SIAware false
setAnalysisMode -analysisType bcwc -checkType setup
optDesign -postRoute -setup
setAnalysisMode -analysisType bcwc -checkType hold
optDesign -postRoute -hold
timeDesign -postRoute
timeDesign -postRoute -hold
saveDesign -rc -def RouteDesign
fit
gui_dump_picture snap/4_route.png -format PNG
set_power_analysis_mode -reset
set_power_analysis_mode -method static -analysis_view FUNC_SS_WORST -corner max -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true
globalNetConnect VDD -type pgpin -pin VDD -instanceBasename *
globalNetConnect VSS -type pgpin -pin VSS -instanceBasename *
globalNetConnect VDD -type tiehi -instanceBasename *
globalNetConnect VSS -type tielo -instanceBasename *
set_power_output_dir -reset
set_power_output_dir ./run1
set_dynamic_power_simulation -reset
set_default_switching_activity -reset
set_default_switching_activity -input_activity 0.2 -period 8.0
read_activity_file -reset
set_power -reset
set_powerup_analysis -reset
report_power -rail_analysis_format VS -outfile ./run1/mcu_core_top.rpt
violationBrowser -all -no_display_false -displayByLayer
violationBrowserClose
zoomBox 102.48250 220.10150 125.64900 202.38600
zoomBox 111.89300 216.39850 123.37150 208.06650
zoomBox 113.77900 216.15250 121.33700 210.56900
zoomBox 114.77650 215.22800 120.98500 211.08250
zoomBox 115.50750 215.05850 120.83250 210.60100
zoomBox 116.76700 211.10500 120.61450 214.54950
zoomBox 117.25900 211.36250 120.52950 214.29050
zoomBox 118.03250 211.76750 120.39600 213.88350
zoomBox 114.70500 210.02500 120.97150 215.63500
zoomBox 115.50650 210.44450 120.83300 215.21300
zoomBox 116.18700 210.80100 120.71500 214.85450
zoomBox 115.17250 210.43650 121.43950 216.04700
panPage 1 0
panPage 1 0
panPage 0 -1
panPage -1 0
zoomBox 117.97500 209.73600 121.82450 213.18200
zoomBox 118.54200 210.33900 120.90600 212.45550
panPage 0 1
panPage 0 1
zoomBox 118.38200 211.43900 121.16400 213.92950
panPage 0 -1
zoomBox 118.19450 210.49250 121.46750 213.42250
panPage 0 1
fit
getMultiCpuUsage -localCpu
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false -use_min_spacing_on_block_obs auto -report mcu_core_top.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
verifyConnectivity -type all -noOpen -noWeakConnect -noUnConnPin -noUnroutedNet -geomConnect -error 1000 -warning 50
getFillerMode -quiet
addFiller -cell FILL1 FILL8 FILL64 FILL4 FILL32 FILL2 FILL16 -prefix FILLER
verify_drc
verifyConnectivity -type all -geomConnect -error 1000 -warning 50
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer
extractRC
saveDesign -rc -def ChipFinish
fit
gui_dump_picture snap/5_chipfinish.png -format PNG
saveNetlist mcu_core_top.v
write_sdf mcu_core_top.sdf
write_sdf -version 2.1 mcu_core_top.sdf_2.1
writeTimingCon mcu_core_top.sdc
streamOut mcu_core_top.gds -libName DesignLib -units 2000 -mode ALL
violationBrowser -all -no_display_false -displayByLayer
violationBrowserClose
fit
zoomBox 101.11950 216.46750 124.74050 201.02300
zoomBox 99.48000 196.79150 127.26950 221.66900
