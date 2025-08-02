`timescale 1ns/1ps
`define T 5000  // system clock @10k
`define TCK (3*`T)

module testbench();
    logic clock;    // @100kHz
    logic nreset;
    logic tck;
    logic scan_en;

    logic jtag_TMS;
    logic jtag_TDI;
    logic jtag_TDO;
   
    always
    begin
        #`T clock <= ~clock;
    end

    always
    begin
        #`TCK tck <= ~tck;
    end

    
    initial
    begin
        clock = 0;
        tck = 0;
        nreset = 0;
        scan_en = 0;
        jtag_TDI = 0;
        #(10*`TCK) nreset = 1;
//        #(5*`T) scan_en = 1;
//        #(100*`T) scan_en = 0;
//        #(100*`T) scan_en = 1;

// reach shift IR
        #(2*`TCK) jtag_TMS = 0; // idle
        #(2*`TCK) jtag_TMS = 1; // select DR
        #(2*`TCK) jtag_TMS = 1; // select IR
        #(2*`TCK) jtag_TMS = 0; // capture IR
        #(2*`TCK) jtag_TMS = 0; // shift IR
// shift data through TDI
        #(2*`TCK) jtag_TDI = 1;
        #(2*`TCK) jtag_TDI = 1;
        #(2*`TCK) jtag_TDI = 0;
        #(2*`TCK) jtag_TDI = 0;
// reach update IR
        #(2*`TCK) jtag_TMS = 1; // exit1 IR
        #(2*`TCK) jtag_TMS = 1; // update IR

        #10000000
        $finish;
    end

//    top i_top(
//        .nreset,
//        .sysclk(clock),
//        .tck,
//        .scan_en
//        );
    

    jtag_cell u_jtag_cell(
    .TCK(tck),
    .TRST(nreset),
    .TMS(jtag_TMS),
    .TDI(jtag_TDI),
    .TDO(jtag_TDO)
    );

endmodule // testbench
