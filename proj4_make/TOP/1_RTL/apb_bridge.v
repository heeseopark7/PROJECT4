// CPU -> APB master bridge. SETUP (stall=1, PENABLE=0) then ACCESS (stall=0, PENABLE=1).
// PREADY assumed 1 (OI-10). PENABLE is high for exactly one clock per transfer.
module apb_bridge (
    input  clk,
    input  clrn,
    input  req,       // CPU is doing lw/sw to APB region
    output psel,
    output penable,
    output stall
);
    reg access;       // 1 during ACCESS phase
    always @(posedge clk or negedge clrn) begin
        if (!clrn)            access <= 1'b0;
        else if (req && !access) access <= 1'b1;   // SETUP -> ACCESS
        else                  access <= 1'b0;      // ACCESS/IDLE -> IDLE
    end
    assign psel    = req;
    assign penable = req & access;
    assign stall   = req & ~access;
endmodule
