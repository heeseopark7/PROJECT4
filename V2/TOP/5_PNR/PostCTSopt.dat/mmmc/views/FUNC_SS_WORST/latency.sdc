set_clock_latency -source -early -max  0.2 [get_clocks {MAIN_CLOCK}]
set_clock_latency -source -late -max  0.2 [get_clocks {MAIN_CLOCK}]
set_clock_latency -source -early -max -rise  0.12367 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -early -max -fall  0.116595 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -late -max -rise  0.12367 [get_ports {clk}] -clock MAIN_CLOCK 
set_clock_latency -source -late -max -fall  0.116595 [get_ports {clk}] -clock MAIN_CLOCK 
