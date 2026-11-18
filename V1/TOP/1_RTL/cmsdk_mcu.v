//------------------------------------------------------------------------------
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from ARM Limited.
//
//            (C) COPYRIGHT 2010-2015  ARM Limited or its affiliates.
//                ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from ARM Limited.
//
//  Version and Release Control Information:
//
//  File Revision       : $Revision: 275084 $
//  File Date           : $Date: 2014-03-27 15:09:11 +0000 (Thu, 27 Mar 2014) $
//
//  Release Information : Cortex-M0 DesignStart-r1p0-00rel0
//------------------------------------------------------------------------------
// Verilog-2001 (IEEE Std 1364-2001)
//------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
// Abstract : Top level for example Cortex-M0 microcontroller
//-----------------------------------------------------------------------------
//

`include "cmsdk_mcu_defs.v"

module cmsdk_mcu #(
  //-----------------------------------------
  // CPU options

  parameter BE              = 0,   // Big or little endian
  parameter BKPT            = 0,   // Number of breakpoint comparators
  parameter DBG             = 0,   // Debug configuration
  parameter NUMIRQ          = 32,  // NUM of IRQ
  parameter SMUL            = 0,   // Multiplier configuration
  parameter SYST            = 1,   // SysTick
  parameter WIC             = 0,   // Wake-up interrupt controller support
  parameter WICLINES        = 34,  // Supported WIC lines
  parameter WPT             = 0    // Number of DWT comparators

 )
 (
  input  wire          XTAL1, // input
  output wire          XTAL2, // output
// 20241203 SMKCOW :: no use of Fifo Clocks
// BACK TO ORIGINAL 
  //input  wire	       IN_fifo_CLK_50,  	// 50MHz : smkcow for FIFO and Uart
  //output wire	       OUT_fifo_CLK_50,  	// 50MHz : smkcow this is output from mcu and go to TTY's CLK input
  input  wire          NRST,  // active low reset
  //inout  wire  [15:0]  P0,
  inout  wire  [15:0]  P1,

  input  wire          nTRST,
  input  wire          SWCLKTCK,
  input  wire          TDI,
  output wire          TDO,
  // modified by smkcow : no use of output from internal codes
  //inout  wire          SWDIOTMS,
  input  wire          SWDIOTMS,

//  output wire          stx,
//  input  wire          srx,

// FLASH rom interface 
  output wire               HCLKSYS, // System clock for memory
  output wire               HRESETn, // AHB reset
  output wire               flash_hsel,
  //output wire  [31:0]       HADDR,
  output wire  [15:0]       HADDR,
  output wire  [1:0]        HTRANS,
  output wire  [2:0]        HSIZE,
  output wire               HWRITE,
  output wire  [31:0]       HWDATA,
  output wire               HREADY,
  input  wire               flash_hreadyout,
  input  wire  [31:0]       flash_hrdata,
  input  wire               flash_hresp,
//  output wire          	    out_NRST,  // active low reset

//  input  wire 	            Rom_select,
//  input  wire          	    out_stx,
//  output wire          	    in_srx,
  output wire          	    sram_hsel,
  input  wire               sram_hreadyout,
  input  wire  [31:0]       sram_hrdata,
  input  wire               sram_hresp
);

//  wire 	        in_Rom_select;
//  wire	        in_IN_fifo_CLK_50;  	// 50MHz : smkcow for FIFO and Uart
//  wire	        out_OUT_fifo_CLK_50;  	// 50MHz : smkcow this is output from mcu and go to TTY's CLK input
  wire          in_XTAL1; // input
  wire          out_XTAL2; // output
  wire          in_NRST;  // active low reset
//  wire          out_out_NRST;

//assign out_out_NRST = in_NRST;

  wire          in_nTRST;
  wire          in_TDI;
  wire          out_TDO;
  wire          in_SWDIOTMS;

  wire          in_SWCLKTCK;
//  wire 	        in_Rom_select;
//  wire          out_stx;
//  wire          in_srx;

//------------------------------------
// internal wires
  wire               SLEEPING;
  wire               APBACTIVE;
  wire               SYSRESETREQ;    // processor system reset request
  wire               WDOGRESETREQ;   // watchdog system reset request
  wire               HRESETREQ;      // Combined system reset request
  wire               cmsdk_SYSRESETREQ; // Combined system reset request
  wire               clk_ctrl_sys_reset_req;
  wire               PMUHRESETREQ;
  wire               PMUDBGRESETREQ;
  wire               LOCKUP;
  wire               LOCKUPRESET;
  wire               PMUENABLE;
  wire               SLEEPDEEP;

  wire               PORESETn;// Power on reset
//  wire               HRESETn; // AHB reset
  wire               out_HRESETn; // AHB reset
  wire               PRESETn; // APB and peripheral reset
  wire               FCLK;    // Free running system clock
  wire               HCLK;    // System clock from PMU
  wire               SCLK;
  wire               PCLK;    // Peripheral clock
  wire               PCLKG;   // Gated PCLK for APB
//  wire               HCLKSYS; // System clock for memory
  wire               PCLKEN;  // Clock divider for AHB to APB bridge
  // Common AHB signals
  wire  [31:0]       out_HADDR;
  wire  [1:0]        out_HTRANS;
  wire  [2:0]        out_HSIZE;
  wire               out_HWRITE;
  wire  [31:0]       out_HWDATA;
  wire               out_HREADY;

  // Flash memory AHB signals
  wire               out_flash_hsel;
  wire               in_flash_hreadyout;
  wire  [31:0]       in_flash_hrdata;
  wire               in_flash_hresp;

  // SRAM AHB signals
  wire               out_sram_hsel;
  wire               in_sram_hreadyout;
  wire  [31:0]       in_sram_hrdata;
  wire               in_sram_hresp;

  // internal peripheral signals
  wire               uart0_rxd;
  wire               uart0_txd;
  wire               uart0_txen;
  wire               uart1_rxd;
  wire               uart1_txd;
  wire               uart1_txen;
  wire               uart2_rxd;
  wire               uart2_txd;
  wire               uart2_txen;

  wire               timer0_extin;
  wire               timer1_extin;

  wire  [15:0]       p0_in;
  wire  [15:0]       p0_out;
  wire  [15:0]       p0_outen;
  wire  [15:0]       p0_altfunc;

  wire  [15:0]       p1_in;
  wire  [15:0]       p1_out;
  wire  [15:0]       p1_outen;
  wire  [15:0]       p1_altfunc;

// Added by smkcow
  wire      [15:0]     p0_in_from_IO;
  wire      [15:0]     p0_out_mux;
  wire      [15:0]     p0_out_en_mux;

  wire      [15:0]     p1_in_from_IO;
  wire      [15:0]     p1_out_mux;
  wire      [15:0]     p1_out_en_mux;
    
  localparam BASEADDR_GPIO0       = 32'h4001_0000;
  localparam BASEADDR_GPIO1       = 32'h4001_1000;
  localparam BASEADDR_SYSROMTABLE = 32'hF000_0000;

  // Internal Debug signals
  wire               i_trst_n;
  wire               i_swditms;
  wire               i_swclktck;
  wire               i_tdi;
  wire               i_tdo;
  wire               i_tdoen_n;
  wire               i_swdo;
  wire               i_swdoen;

  wire               TESTMODE;

// smkcow :: temp values
  assign i_tdo = 1'b1;
  assign TESTMODE = 1'b0;
  assign i_tdoen_n = 1'b1;

//----------------------------------------
// Clock and reset controller
//----------------------------------------
  // Clock controller generates reset if PMU request (PMUHRESETREQ),
  // CPU request or watchdog request (SYSRESETREQ)
  assign clk_ctrl_sys_reset_req = PMUHRESETREQ | cmsdk_SYSRESETREQ;

// 20241203 SMKCOW :: no use of CLOCK GATING
// BACK TO ORIGINAL 
// reg reset_connect;
//always@(posedge in_XTAL1 or posedge in_Rom_select)
//begin
//	if(in_Rom_select==1'b1)
//		reset_connect <= 1'b0;
//	else
//		reset_connect <= 1'b1;
//end
//
//wire ctrl_reset;
//assign ctrl_reset = in_NRST & reset_connect;

  // latch_posedge_precontrol
//  CGLPPRX8_RVT UICG(
//          .SE(SE),
//          .EN(~Rom_select),
//          .CLK(in_XTAL1), // memory clk ::sram_CLK should be positive clk so logic should be negative :: Because of Hold violation,
//			//even the function simulation
//          .GCLK(GATED_in_XTAL1)
//                                              );

// 20241203 SMKCOW :: no use of CLOCK GATING
// BACK TO ORIGINAL 
//wire GATED_in_XTAL1;
//wire SE;
//assign SE=1'b0;
//  // latch_posedge_precontrol
//TLATNTSCAX20 UICG(
//	.ECK(GATED_in_XTAL1),
//	.E(~in_Rom_select),
//	.SE(SE),
//	.CK(in_XTAL1)
//);


//PREICG_X9B_A9TR U_PREICG(
//          //.CK(in_XTAL1), 
////DFT
//          .CK(clk_muxed), 
//          //.SE(in_PI_SE),
//          .SE(SE_signal),
//          //.SE(Zero),
//          //.SE(),
//	  // Below line is original, 
//          //.E(Rom_select_or_TM), // inversion value so make 1'b1
//          // TEST!!!
//          .E(~Rom_select), // inversion value so make 1'b1
//          .ECK(GATED_in_XTAL1)
//  );

  // Clock controller to generate reset and clock signals
  cmsdk_mcu_clkctrl
   #(.CLKGATE_PRESENT(0))
   u_cmsdk_mcu_clkctrl(
     // inputs
    .XTAL1            (in_XTAL1),
    //.XTAL1            (GATED_in_XTAL1),
// 20241203 SMKCOW :: no use of Fifo Clocks
// BACK TO ORIGINAL 
    //.IN_fifo_CLK_50   (in_IN_fifo_CLK_50),  // 50MHz : smkcow for FIFO and Uart
    //.OUT_fifo_CLK_50  (out_OUT_fifo_CLK_50), // 50MHz : smkcow this is output from mcu and go to TTY's CLK input
    //.NRST             (ctrl_reset),
    .NRST             (in_NRST),

    .APBACTIVE        (APBACTIVE),
    .SLEEPING         (SLEEPING),
    .SLEEPDEEP        (SLEEPDEEP),
    .LOCKUP           (LOCKUP),
    .LOCKUPRESET      (LOCKUPRESET),
    .SYSRESETREQ      (clk_ctrl_sys_reset_req),
    .DBGRESETREQ      (PMUDBGRESETREQ),
    .CGBYPASS         (TESTMODE),
    .RSTBYPASS        (TESTMODE),

     // outputs
    .XTAL2            (out_XTAL2),

    .FCLK             (FCLK),

    .PCLK             (PCLK),
    .PCLKG            (PCLKG),
    .PCLKEN           (PCLKEN),
    .PORESETn         (PORESETn),  // for cm0 designstart
    .HRESETn          (out_HRESETn),   // for cm0 designstart
    .PRESETn          (PRESETn)
    );

//----------------------------------------
//
  // System Reset request can be from processor or watchdog
  // or when lockup happens and the control flag is set.
  assign  cmsdk_SYSRESETREQ = SYSRESETREQ | WDOGRESETREQ |
                              (LOCKUP & LOCKUPRESET);

  // Power Management Unit will not be available
  assign  HCLK = FCLK;        // connect HCLK to FCLK
  assign  SCLK = FCLK;        // connect SCLK to FCLK

  // Since there is no PMU, these signals are not used
  assign  PMUDBGRESETREQ = 1'b0;
  assign  PMUHRESETREQ   = 1'b0;

//---------------------------------------------------
// System design for example Cortex-M0 MCU
//---------------------------------------------------
  cmsdk_mcu_system
//   #(
//.BE               (BE),
//     .BASEADDR_GPIO0   (BASEADDR_GPIO0), // GPIO0 Base Address
//     .BASEADDR_GPIO1   (BASEADDR_GPIO1), // GPIO1 Base Address
//     .BKPT             (BKPT),           // Number of breakpoint comparators
//     .DBG              (DBG),            // Debug configuration
//     .NUMIRQ           (NUMIRQ),         // NUMIRQ
//     .SMUL             (SMUL),           // Multiplier configuration
//     .SYST             (SYST),           // SysTick
//     .WIC              (WIC),            // Wake-up interrupt controller support
//     .WICLINES         (WICLINES),       // Supported WIC lines
//     .WPT              (WPT),            // Number of DWT comparators
//     .BASEADDR_SYSROMTABLE (BASEADDR_SYSROMTABLE) // System ROM Table base address
//   )
    u_cmsdk_mcu_system (
    .FCLK             (FCLK),
    .HCLK             (HCLK),
    .SCLK             (SCLK),
    .HRESETn          (out_HRESETn),
    .PORESETn         (PORESETn),

    .PCLK             (PCLK),
    .PCLKG            (PCLKG),
    .PRESETn          (PRESETn),
    .PCLKEN           (PCLKEN),

    // Common AHB signals
    .HADDR            (out_HADDR),
    .HTRANS           (out_HTRANS),
    .HSIZE            (out_HSIZE),
    .HWRITE           (out_HWRITE),
    .HWDATA           (out_HWDATA),
    .HREADY           (out_HREADY),

    // Flash
    .flash_hsel       (out_flash_hsel),
    .flash_hreadyout  (in_flash_hreadyout),
    .flash_hrdata     (in_flash_hrdata),
    .flash_hresp      (in_flash_hresp),

    // SRAM
    .sram_hsel        (out_sram_hsel),
    .sram_hreadyout   (in_sram_hreadyout),
    .sram_hrdata      (in_sram_hrdata),
    .sram_hresp       (in_sram_hresp),

    // Optional boot loader
    // Only use if BOOT_MEM_TYPE is not zero
    .boot_hsel        (),
    .boot_hreadyout   (1'b0),
    .boot_hrdata      (32'h00000000),
    .boot_hresp       (1'b0),

    // Status
    .APBACTIVE        (APBACTIVE),
    .SLEEPING         (SLEEPING),
    .SYSRESETREQ      (SYSRESETREQ),
    .WDOGRESETREQ     (WDOGRESETREQ),
    .LOCKUP           (LOCKUP),
    .LOCKUPRESET      (LOCKUPRESET),
    .PMUENABLE        (PMUENABLE),
    .SLEEPDEEP        (SLEEPDEEP),

    // UART
    .uart0_rxd        (uart0_rxd),
    .uart0_txd        (uart0_txd),
    .uart0_txen       (uart0_txen),
    .uart1_rxd        (uart1_rxd),
    .uart1_txd        (uart1_txd),
    .uart1_txen       (uart1_txen),
    .uart2_rxd        (uart2_rxd),
    .uart2_txd        (uart2_txd),
    .uart2_txen       (uart2_txen),

    // Timer
    .timer0_extin     (timer0_extin),
    .timer1_extin     (timer1_extin),

    // IO Ports
    .p0_in            (p0_in),
    .p0_out           (p0_out),
    .p0_outen         (p0_outen),
    .p0_altfunc       (p0_altfunc),

    .p1_in            (p1_in),
    .p1_out           (p1_out),
    .p1_outen         (p1_outen),
    .p1_altfunc       (p1_altfunc),

    .DFTSE            (1'b0)
  );

wire out_HCLKSYS;
assign   out_HCLKSYS  = HCLK;
//assign   HCLKSYS  = HCLK;

//----------------------------------------
// Flash memory
//----------------------------------------
// Have to assign memory CEN with along to sram_CEN_o 
// SMKCOW :: move cmsdk_ahb_rom out  for CADENCE Project
// 2024-11-07
//cmsdk_ahb_rom
//  #(.MEM_TYPE(1'b1),
//    .AW(16),  // 64K bytes flash ROM
//    .filename("image.hex"),
//    .WS_N(`ARM_CMSDK_ROM_MEM_WS_N),
//    .WS_S(`ARM_CMSDK_ROM_MEM_WS_S),
//    .BE  (BE))
//   u_ahb_rom (
//    .HCLK             (HCLKSYS),
//    .IN_fifo_CLK_50   (out_OUT_fifo_CLK_50), // 50MHz : smkcow for FIFO and Uart
//    .HRESETn          (HRESETn),
//    .HSEL             (flash_hsel),  // AHB inputs
//    .HADDR            (HADDR[15:0]), // originally [15:0] 
//    .HTRANS           (HTRANS),
//    .HSIZE            (HSIZE),
//    .HWRITE           (HWRITE),
//    .HWDATA           (HWDATA),
//    .HREADY           (HREADY),
//
//    .HREADYOUT        (flash_hreadyout), // Outputs
//    .HRDATA           (flash_hrdata),
//    .HRESP            (flash_hresp),
//    .NRST		(in_NRST),		// smkcow fifo uart channel
//    .Rom_select		(Rom_select),   // smkcow fifo uart channel 
//    .stx		(out_stx),		// smkcow fifo uart channel 
//    .srx		(in_srx)		// smkcow fifo uart channel 
//  );

//----------------------------------------
// SRAM
//----------------------------------------
// SMKCOW :: move cmsdk_ahb_ram out  for CADENCE Project
// 2024-11-07
//cmsdk_ahb_ram
//  #(.MEM_TYPE(1'b1),
//    .AW(16),  // 64K bytes SRAM
//    .WS_N(`ARM_CMSDK_RAM_MEM_WS_N),
//    .WS_S(`ARM_CMSDK_RAM_MEM_WS_S))
//   u_ahb_ram (
//    .HCLK             (HCLKSYS),
//    .HRESETn          (HRESETn),
//    .HSEL             (sram_hsel),  // AHB inputs
//    .HADDR            (HADDR[15:0]), // originally [15:0]
//    .HTRANS           (HTRANS),
//    .HSIZE            (HSIZE),
//    .HWRITE           (HWRITE),
//    .HWDATA           (HWDATA),
//    .HREADY           (HREADY),
//
//    .HREADYOUT        (sram_hreadyout), // Outputs
//    .HRDATA           (sram_hrdata),
//    .HRESP            (sram_hresp)
//  );

assign p0_in_from_IO = 16'h0000;

//----------------------------------------
// I/O port pin muxing and tristate
//----------------------------------------
  cmsdk_mcu_pin_mux
    u_pin_mux (
    // UART
    .uart0_rxd        (uart0_rxd),
    .uart0_txd        (uart0_txd),
    .uart0_txen       (uart0_txen),
    .uart1_rxd        (uart1_rxd),
    .uart1_txd        (uart1_txd),
    .uart1_txen       (uart1_txen),
    .uart2_rxd        (uart2_rxd),
    .uart2_txd        (uart2_txd),
    .uart2_txen       (uart2_txen),

    // Timer
    .timer0_extin     (timer0_extin),
    .timer1_extin     (timer1_extin),

    // IO Ports
    .p0_in            (p0_in),
    .p0_out           (p0_out),
    .p0_outen         (p0_outen),
    .p0_altfunc       (p0_altfunc),

    .p1_in            (p1_in),
    .p1_out           (p1_out),
    .p1_outen         (p1_outen),
    .p1_altfunc       (p1_altfunc),

    // Debug
    .i_trst_n         (i_trst_n),
    .i_swditms        (i_swditms),
    .i_swclktck       (i_swclktck),
    .i_tdi            (i_tdi),
    .i_tdo            (i_tdo),
    .i_tdoen_n        (i_tdoen_n),
    .i_swdo           (i_swdo),
    .i_swdoen         (i_swdoen),

    // IO pads modified by smkcow
//    .P0               (P0),
//    .P1               (P1),

// 2024.11.10 CADENCE project : P0 is erased by smkcow because of lack of IO port
    .p0_in_from_IO	(p0_in_from_IO),
//    .p0_out_mux		(p0_out_mux),
//    .p0_out_en_mux	(p0_out_en_mux),
    //.p0_in_from_IO	(),
    .p0_out_mux		(),
    .p0_out_en_mux	(),

    .p1_in_from_IO	(p1_in_from_IO),
    .p1_out_mux		(p1_out_mux),
    .p1_out_en_mux	(p1_out_en_mux),

    .nTRST            (in_nTRST),  // Not needed if serial-wire debug is used
    .TDI              (in_TDI),    // Not needed if serial-wire debug is used
    .SWDIOTMS         (in_SWDIOTMS),
    .SWCLKTCK         (in_SWCLKTCK),
    .TDO              (out_TDO)     // Not needed if serial-wire debug is used

  );


///////////////////////
//     Left side     //
///////////////////////

//// begin

// Input Buffer
PADDI pad1(
	.PAD(nTRST), 
	.Y(in_nTRST)
);

// Input Buffer
PADDI pad2(
	.PAD(TDI), 
	.Y(in_TDI)
);

// Input Buffer
PADDI pad3(
	.PAD(SWDIOTMS), 
	.Y(in_SWDIOTMS)
);

// Input Buffer
PADDI pad4(
	.PAD(SWCLKTCK), 
	.Y(in_SWCLKTCK)
);

// Output Driver
PADDO pad5(
	.A(out_TDO), 
	.PAD(TDO)
);


// Input Buffer
PADDI pad6(
	.PAD(XTAL1), 
	.Y(in_XTAL1)
);

//PADVSS    pad7();
//PADVSSIOR pad8();

// Output Driver
PADDO pad9(
	.A(out_XTAL2), 
	.PAD(XTAL2)
);

//PADVSSIOR pad10();

//PADVDD    pad11();
//PADVSS    pad12();
//PADVDDIOR pad13();
//PADVSSIOR pad14();

// Input Buffer
PADDI pad15(
	.PAD(NRST), 
	.Y(in_NRST)
);

// Output Driver
PADDO pad16(
	.A(out_HRESETn), 
	.PAD(HRESETn)
);

//PADVSSIOR pad17();
//PADVSSIOR pad18();

// Output Driver
PADDO pad19(
	.A(out_HCLKSYS), 
	.PAD(HCLKSYS)
);

//PADVSSIOR pad20();
//PADVDD    pad21();
//PADVDD    pad22();
//PADVSS    pad23();
//PADVDDIOR pad24();
//PADVSSIOR pad25();


// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad26(
	.A(p1_out_mux[0]), 
	.OEN(~p1_out_en_mux[0]), // Output Enable Negative : 0 is for output
	.PAD(P1[0]), 
	.Y(p1_in_from_IO[0])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad27(
	.A(p1_out_mux[1]), 
	.OEN(~p1_out_en_mux[1]), // Output Enable Negative : 0 is for output
	.PAD(P1[1]), 
	.Y(p1_in_from_IO[1])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad28(
	.A(p1_out_mux[2]), 
	.OEN(~p1_out_en_mux[2]), // Output Enable Negative : 0 is for output
	.PAD(P1[2]), 
	.Y(p1_in_from_IO[2])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad29(
	.A(p1_out_mux[3]), 
	.OEN(~p1_out_en_mux[3]), // Output Enable Negative : 0 is for output
	.PAD(P1[3]), 
	.Y(p1_in_from_IO[3])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad30(
	.A(p1_out_mux[4]), 
	.OEN(~p1_out_en_mux[4]), // Output Enable Negative : 0 is for output
	.PAD(P1[4]), 
	.Y(p1_in_from_IO[4])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad31(
	.A(p1_out_mux[5]), 
	.OEN(~p1_out_en_mux[5]), // Output Enable Negative : 0 is for output
	.PAD(P1[5]), 
	.Y(p1_in_from_IO[5])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad32(
	.A(p1_out_mux[6]), 
	.OEN(~p1_out_en_mux[6]), // Output Enable Negative : 0 is for output
	.PAD(P1[6]), 
	.Y(p1_in_from_IO[6])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad33(
	.A(p1_out_mux[7]), 
	.OEN(~p1_out_en_mux[7]), // Output Enable Negative : 0 is for output
	.PAD(P1[7]), 
	.Y(p1_in_from_IO[7])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad34(
	.A(p1_out_mux[8]), 
	.OEN(~p1_out_en_mux[8]), // Output Enable Negative : 0 is for output
	.PAD(P1[8]), 
	.Y(p1_in_from_IO[8])
);

//PADVDD    pad35();
//PADVSS    pad36();
//PADVDDIOR pad37();
//PADVSSIOR pad38();

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad39(
	.A(p1_out_mux[9]), 
	.OEN(~p1_out_en_mux[9]), // Output Enable Negative : 0 is for output
	.PAD(P1[9]), 
	.Y(p1_in_from_IO[9])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad40(
	.A(p1_out_mux[10]), 
	.OEN(~p1_out_en_mux[10]), // Output Enable Negative : 0 is for output
	.PAD(P1[10]), 
	.Y(p1_in_from_IO[10])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad41(
	.A(p1_out_mux[11]), 
	.OEN(~p1_out_en_mux[11]), // Output Enable Negative : 0 is for output
	.PAD(P1[11]), 
	.Y(p1_in_from_IO[11])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad42(
	.A(p1_out_mux[12]), 
	.OEN(~p1_out_en_mux[12]), // Output Enable Negative : 0 is for output
	.PAD(P1[12]), 
	.Y(p1_in_from_IO[12])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad43(
	.A(p1_out_mux[13]), 
	.OEN(~p1_out_en_mux[13]), // Output Enable Negative : 0 is for output
	.PAD(P1[13]), 
	.Y(p1_in_from_IO[13])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad44(
	.A(p1_out_mux[14]), 
	.OEN(~p1_out_en_mux[14]), // Output Enable Negative : 0 is for output
	.PAD(P1[14]), 
	.Y(p1_in_from_IO[14])
);

// Bi-directional Cell
// PAD to Y
// A to PAD
PADDB pad45(
	.A(p1_out_mux[15]), 
	.OEN(~p1_out_en_mux[15]), // Output Enable Negative : 0 is for output
	.PAD(P1[15]), 
	.Y(p1_in_from_IO[15])
);

//PADVDD    pad46();
//PADVSS    pad47();
//PADVDDIOR pad48();
//PADVSSIOR pad49();
//PADVSSIOR pad50();
///////////////////////
//    Bottom side    //
///////////////////////

// Output Driver
PADDO pad51(
	.A(out_HADDR[0]), 
	.PAD(HADDR[0])
);
PADDO pad52(
	.A(out_HADDR[1]), 
	.PAD(HADDR[1])
);
PADDO pad53(
	.A(out_HADDR[2]), 
	.PAD(HADDR[2])
);

PADDO pad54(
	.A(out_HADDR[3]), 
	.PAD(HADDR[3])
);
PADDO pad55(
	.A(out_HADDR[4]), 
	.PAD(HADDR[4])
);
PADDO pad56(
	.A(out_HADDR[5]), 
	.PAD(HADDR[5])
);
PADDO pad57(
	.A(out_HADDR[6]), 
	.PAD(HADDR[6])
);
PADDO pad58(
	.A(out_HADDR[7]), 
	.PAD(HADDR[7])
);

PADDO pad59(
	.A(out_HADDR[8]), 
	.PAD(HADDR[8])
);
PADDO pad60(
	.A(out_HADDR[9]), 
	.PAD(HADDR[9])
);
PADDO pad61(
	.A(out_HADDR[10]), 
	.PAD(HADDR[10])
);
PADDO pad62(
	.A(out_HADDR[11]), 
	.PAD(HADDR[11])
);
PADDO pad63(
	.A(out_HADDR[12]), 
	.PAD(HADDR[12])
);
PADDO pad64(
	.A(out_HADDR[13]), 
	.PAD(HADDR[13])
);
PADDO pad65(
	.A(out_HADDR[14]), 
	.PAD(HADDR[14])
);
PADDO pad66(
	.A(out_HADDR[15]), 
	.PAD(HADDR[15])
);

//PADVDD    pad67();
//PADVSS    pad68();
//PADVDDIOR pad69();
//PADVSSIOR pad70();

PADDO pad71(
	.A(out_HTRANS[0]), 
	.PAD(HTRANS[0])
);
PADDO pad72(
	.A(out_HTRANS[1]), 
	.PAD(HTRANS[1])
);

PADDO pad73(
	.A(out_HSIZE[0]), 
	.PAD(HSIZE[0])
);
PADDO pad74(
	.A(out_HSIZE[1]), 
	.PAD(HSIZE[1])
);
PADDO pad75(
	.A(out_HSIZE[2]), 
	.PAD(HSIZE[2])
);
PADDO pad76(
	.A(out_HWRITE), 
	.PAD(HWRITE)
);
PADDO pad77(
	.A(out_HREADY), 
	.PAD(HREADY)
);

//PADVSSIOR pad78();
PADDO pad79(
	.A(out_HWDATA[0]), 
	.PAD(HWDATA[0])
);
PADDO pad80(
	.A(out_HWDATA[1]), 
	.PAD(HWDATA[1])
);
PADDO pad81(
	.A(out_HWDATA[2]), 
	.PAD(HWDATA[2])
);
PADDO pad82(
	.A(out_HWDATA[3]), 
	.PAD(HWDATA[3])
);
PADDO pad83(
	.A(out_HWDATA[4]), 
	.PAD(HWDATA[4])
);
PADDO pad84(
	.A(out_HWDATA[5]), 
	.PAD(HWDATA[5])
);
PADDO pad85(
	.A(out_HWDATA[6]), 
	.PAD(HWDATA[6])
);
PADDO pad86(
	.A(out_HWDATA[7]), 
	.PAD(HWDATA[7])
);

//PADVDD    pad87();
//PADVSS    pad88();
//PADVDDIOR pad89();
//PADVSSIOR pad90();

PADDO pad91(
	.A(out_HWDATA[8]), 
	.PAD(HWDATA[8])
);
PADDO pad92(
	.A(out_HWDATA[9]), 
	.PAD(HWDATA[9])
);
PADDO pad93(
	.A(out_HWDATA[10]), 
	.PAD(HWDATA[10])
);
PADDO pad94(
	.A(out_HWDATA[11]), 
	.PAD(HWDATA[11])
);
PADDO pad95(
	.A(out_HWDATA[12]), 
	.PAD(HWDATA[12])
);
PADDO pad96(
	.A(out_HWDATA[13]), 
	.PAD(HWDATA[13])
);

PADDO pad97(
	.A(out_HWDATA[14]), 
	.PAD(HWDATA[14])
);
PADDO pad98(
	.A(out_HWDATA[15]), 
	.PAD(HWDATA[15])
);
PADDO pad99(
	.A(out_HWDATA[16]), 
	.PAD(HWDATA[16])
);
PADDO pad100(
	.A(out_HWDATA[17]), 
	.PAD(HWDATA[17])
);

///////////////////////
//    Right side     //
///////////////////////

PADDO pad101(
	.A(out_HWDATA[18]), 
	.PAD(HWDATA[18])
);
PADDO pad102(
	.A(out_HWDATA[19]), 
	.PAD(HWDATA[19])
);
PADDO pad103(
	.A(out_HWDATA[20]), 
	.PAD(HWDATA[20])
);
PADDO pad104(
	.A(out_HWDATA[21]), 
	.PAD(HWDATA[21])
);
PADDO pad105(
	.A(out_HWDATA[22]), 
	.PAD(HWDATA[22])
);
PADDO pad106(
	.A(out_HWDATA[23]), 
	.PAD(HWDATA[23])
);
PADDO pad107(
	.A(out_HWDATA[24]), 
	.PAD(HWDATA[24])
);
PADDO pad108(
	.A(out_HWDATA[25]), 
	.PAD(HWDATA[25])
);

PADDO pad109(
	.A(out_HWDATA[26]), 
	.PAD(HWDATA[26])
);
PADDO pad110(
	.A(out_HWDATA[27]), 
	.PAD(HWDATA[27])
);
PADDO pad111(
	.A(out_HWDATA[28]), 
	.PAD(HWDATA[28])
);
PADDO pad112(
	.A(out_HWDATA[29]), 
	.PAD(HWDATA[29])
);
PADDO pad113(
	.A(out_HWDATA[30]), 
	.PAD(HWDATA[30])
);
PADDO pad114(
	.A(out_HWDATA[31]), 
	.PAD(HWDATA[31])
);

// Input Buffer
PADDI pad115(
	.PAD(flash_hreadyout), 
	.Y(in_flash_hreadyout)
);

// Input Buffer
PADDI pad116(
	.PAD(flash_hresp), 
	.Y(in_flash_hresp)
);

PADDO pad117(
	.A(out_flash_hsel), 
	.PAD(flash_hsel)
);

//PADVDD    pad118();
//PADVSS    pad119();
//PADVDDIOR pad120();
//PADVSSIOR pad121();

PADDI pad122(
	.PAD(flash_hrdata[0]), 
	.Y(in_flash_hrdata[0])
);

PADDI pad123(
	.PAD(flash_hrdata[1]), 
	.Y(in_flash_hrdata[1])
);

PADDI pad124(
	.PAD(flash_hrdata[2]), 
	.Y(in_flash_hrdata[2])
);

PADDI pad125(
	.PAD(flash_hrdata[3]), 
	.Y(in_flash_hrdata[3])
);

PADDI pad126(
	.PAD(flash_hrdata[4]), 
	.Y(in_flash_hrdata[4])
);

PADDI pad127(
	.PAD(flash_hrdata[5]), 
	.Y(in_flash_hrdata[5])
);

PADDI pad128(
	.PAD(flash_hrdata[6]), 
	.Y(in_flash_hrdata[6])
);

PADDI pad129(
	.PAD(flash_hrdata[7]), 
	.Y(in_flash_hrdata[7])
);

PADDI pad130(
	.PAD(flash_hrdata[8]), 
	.Y(in_flash_hrdata[8])
);

PADDI pad131(
	.PAD(flash_hrdata[9]), 
	.Y(in_flash_hrdata[9])
);

PADDI pad132(
	.PAD(flash_hrdata[10]), 
	.Y(in_flash_hrdata[10])
);

PADDI pad133(
	.PAD(flash_hrdata[11]), 
	.Y(in_flash_hrdata[11])
);

PADDI pad134(
	.PAD(flash_hrdata[12]), 
	.Y(in_flash_hrdata[12])
);

PADDI pad135(
	.PAD(flash_hrdata[13]), 
	.Y(in_flash_hrdata[13])
);

PADDI pad136(
	.PAD(flash_hrdata[14]), 
	.Y(in_flash_hrdata[14])
);

PADDI pad137(
	.PAD(flash_hrdata[15]), 
	.Y(in_flash_hrdata[15])
);

//PADVDD    pad138();
//PADVSS    pad139();
//PADVDDIOR pad140();
//PADVSSIOR pad141();

PADDI pad142(
	.PAD(flash_hrdata[16]), 
	.Y(in_flash_hrdata[16])
);
PADDI pad143(
	.PAD(flash_hrdata[17]), 
	.Y(in_flash_hrdata[17])
);
PADDI pad144(
	.PAD(flash_hrdata[18]), 
	.Y(in_flash_hrdata[18])
);
PADDI pad145(
	.PAD(flash_hrdata[19]), 
	.Y(in_flash_hrdata[19])
);
PADDI pad146(
	.PAD(flash_hrdata[20]), 
	.Y(in_flash_hrdata[20])
);
PADDI pad147(
	.PAD(flash_hrdata[21]), 
	.Y(in_flash_hrdata[21])
);
PADDI pad148(
	.PAD(flash_hrdata[22]), 
	.Y(in_flash_hrdata[22])
);
PADDI pad149(
	.PAD(flash_hrdata[23]), 
	.Y(in_flash_hrdata[23])
);
PADDI pad150(
	.PAD(flash_hrdata[24]), 
	.Y(in_flash_hrdata[24])
);

///////////////////////
//     TOP side      //
///////////////////////

PADDI pad151(
	.PAD(flash_hrdata[25]), 
	.Y(in_flash_hrdata[25])
);
PADDI pad152(
	.PAD(flash_hrdata[26]), 
	.Y(in_flash_hrdata[26])
);
PADDI pad153(
	.PAD(flash_hrdata[27]), 
	.Y(in_flash_hrdata[27])
);
PADDI pad154(
	.PAD(flash_hrdata[28]), 
	.Y(in_flash_hrdata[28])
);
PADDI pad155(
	.PAD(flash_hrdata[29]), 
	.Y(in_flash_hrdata[29])
);
PADDI pad156(
	.PAD(flash_hrdata[30]), 
	.Y(in_flash_hrdata[30])
);
PADDI pad157(
	.PAD(flash_hrdata[31]), 
	.Y(in_flash_hrdata[31])
);

// Output Driver
PADDO pad158(
	.A(out_sram_hsel), 
	.PAD(sram_hsel)
);

PADDI pad159(
	.PAD(sram_hreadyout), 
	.Y(in_sram_hreadyout)
);

//PADVDD    pad160();
//PADVSS    pad161();
//PADVDDIOR pad162();
//PADVSSIOR pad163();

PADDI pad164(
	.PAD(sram_hresp), 
	.Y(in_sram_hresp)
);

PADDI pad165(
	.PAD(sram_hrdata[0]), 
	.Y(in_sram_hrdata[0])
);

PADDI pad166(
	.PAD(sram_hrdata[1]), 
	.Y(in_sram_hrdata[1])
);
PADDI pad167(
	.PAD(sram_hrdata[2]), 
	.Y(in_sram_hrdata[2])
);
PADDI pad168(
	.PAD(sram_hrdata[3]), 
	.Y(in_sram_hrdata[3])
);
PADDI pad169(
	.PAD(sram_hrdata[4]), 
	.Y(in_sram_hrdata[4])
);
PADDI pad170(
	.PAD(sram_hrdata[5]), 
	.Y(in_sram_hrdata[5])
);
PADDI pad171(
	.PAD(sram_hrdata[6]), 
	.Y(in_sram_hrdata[6])
);
PADDI pad172(
	.PAD(sram_hrdata[7]), 
	.Y(in_sram_hrdata[7])
);
PADDI pad173(
	.PAD(sram_hrdata[8]), 
	.Y(in_sram_hrdata[8])
);
PADDI pad174(
	.PAD(sram_hrdata[9]), 
	.Y(in_sram_hrdata[9])
);
PADDI pad175(
	.PAD(sram_hrdata[10]), 
	.Y(in_sram_hrdata[10])
);
PADDI pad176(
	.PAD(sram_hrdata[11]), 
	.Y(in_sram_hrdata[11])
);
PADDI pad177(
	.PAD(sram_hrdata[12]), 
	.Y(in_sram_hrdata[12])
);
PADDI pad178(
	.PAD(sram_hrdata[13]), 
	.Y(in_sram_hrdata[13])
);
PADDI pad179(
	.PAD(sram_hrdata[14]), 
	.Y(in_sram_hrdata[14])
);
PADDI pad180(
	.PAD(sram_hrdata[15]), 
	.Y(in_sram_hrdata[15])
);

//PADVDD    pad181();
//PADVSS    pad182();
//PADVDDIOR pad183();
//PADVSSIOR pad184();

PADDI pad185(
	.PAD(sram_hrdata[16]), 
	.Y(in_sram_hrdata[16])
);

PADDI pad186(
	.PAD(sram_hrdata[17]), 
	.Y(in_sram_hrdata[17])
);
PADDI pad187(
	.PAD(sram_hrdata[18]), 
	.Y(in_sram_hrdata[18])
);
PADDI pad188(
	.PAD(sram_hrdata[19]), 
	.Y(in_sram_hrdata[19])
);
PADDI pad189(
	.PAD(sram_hrdata[20]), 
	.Y(in_sram_hrdata[20])
);
PADDI pad190(
	.PAD(sram_hrdata[21]), 
	.Y(in_sram_hrdata[21])
);
PADDI pad191(
	.PAD(sram_hrdata[22]), 
	.Y(in_sram_hrdata[22])
);
PADDI pad192(
	.PAD(sram_hrdata[23]), 
	.Y(in_sram_hrdata[23])
);
PADDI pad193(
	.PAD(sram_hrdata[24]), 
	.Y(in_sram_hrdata[24])
);
PADDI pad194(
	.PAD(sram_hrdata[25]), 
	.Y(in_sram_hrdata[25])
);
PADDI pad195(
	.PAD(sram_hrdata[26]), 
	.Y(in_sram_hrdata[26])
);
PADDI pad196(
	.PAD(sram_hrdata[27]), 
	.Y(in_sram_hrdata[27])
);
PADDI pad197(
	.PAD(sram_hrdata[28]), 
	.Y(in_sram_hrdata[28])
);
PADDI pad198(
	.PAD(sram_hrdata[29]), 
	.Y(in_sram_hrdata[29])
);
PADDI pad199(
	.PAD(sram_hrdata[30]), 
	.Y(in_sram_hrdata[30])
);
PADDI pad200(
	.PAD(sram_hrdata[31]), 
	.Y(in_sram_hrdata[31])
);
















































endmodule
