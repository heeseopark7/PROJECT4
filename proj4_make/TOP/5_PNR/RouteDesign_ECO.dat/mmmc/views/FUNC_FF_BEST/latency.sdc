set_clock_latency -source -early -max  0.2 [get_clocks {MAIN_CLOCK}]
set_clock_latency -source -late -max  0.2 [get_clocks {MAIN_CLOCK}]
set_clock_latency -source -early -min -rise  -0.247556 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -early -min -fall  -0.302833 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -late -min -rise  -0.247556 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -late -min -fall  -0.302833 [get_ports {clk}] -clock MAIN_CLOCK 
