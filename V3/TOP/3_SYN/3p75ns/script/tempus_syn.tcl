########################################
# Tempus : post-synthesis timing check
#   Run directory : V2/TOP/3_SYN
#   Input         : mapped/mcu_core_top_syn_final.v / .sdc (Genus output)
#   Corners       : same as PnR (setup SS_WORST, hold FF_BEST), see cons/mcu_core_top_tempus.mmmc.view
#   No parasitics (no placement, no SPEF): wire delay is not the post-route value,
#   so the numbers will not match Genus or Tempus post-route exactly.
########################################

file mkdir report/tempus_syn

## Initialization (same variables as 5_PNR/0_InitDesign.tcl, without pad LEF and IO file)
set init_gnd_net VSS
set init_lef_file {/GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_multibitsDFF.lef}
set init_verilog ./mapped/mcu_core_top_syn_final.v
set init_mmmc_file ./cons/mcu_core_top_tempus.mmmc.view
set init_top_cell mcu_core_top
set init_pwr_net VDD
init_design

# (If init_design is not available in your Tempus mode, use the Genus-generated form instead:
#    read_mmmc ./cons/mcu_core_top_tempus.mmmc.view
#    read_physical -lef {<same LEF files>}
#    read_netlist ./mapped/mcu_core_top_syn_final.v
#    init_design )

## Check
check_timing -verbose > report/tempus_syn/check_timing.rpt
report_analysis_coverage > report/tempus_syn/analysis_coverage.rpt
# DataCheckSetup / DataCheckHold : constant paths skipped (same as tempus.tcl)
report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const >> report/tempus_syn/analysis_coverage.rpt

## Setup / Hold
report_timing -late  -max_paths 10 > report/tempus_syn/setup.rpt
report_timing -early -max_paths 10 > report/tempus_syn/hold.rpt
report_constraint -all_violators    > report/tempus_syn/violators.rpt

exit
