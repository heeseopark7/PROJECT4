################################################################################
#
# Init setup file
# Created by Genus(TM) Synthesis Solution on 11/10/2026 00:24:47
#
################################################################################
if { ![is_common_ui_mode] } { error "ERROR: This script requires common_ui to be active."}

read_physical -lef {/GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_tech.lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef /GPDK045/digital/giolib045_v3.5/lef/giolib045.lef}

read_netlist ./mapped/mcu_pad_top_mapped.v

init_design
