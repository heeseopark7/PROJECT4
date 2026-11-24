set_clock_latency -source -early -max  0.2 [get_clocks {MAIN_CLOCK}]
set_clock_latency -source -late -max  0.2 [get_clocks {MAIN_CLOCK}]
set_clock_latency -source -early -max -rise  0.130218 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -early -max -fall  0.123382 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -late -max -rise  0.130218 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -late -max -fall  0.123382 [get_ports {clk}] -clock MAIN_CLOCK 
