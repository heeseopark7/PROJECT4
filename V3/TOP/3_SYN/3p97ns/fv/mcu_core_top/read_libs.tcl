add_search_path /GPDK045/digital/gsclib045_all_v4.4/gsclib045/timing /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef /GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/qrc/qx -library -both
read_library -liberty -both \
    /GPDK045/digital/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_basicCells.lib \
    /GPDK045/digital/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_multibitsDFF.lib \
    /GPDK045/digital/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_basicCells.lib \
    /GPDK045/digital/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_multibitsDFF.lib

