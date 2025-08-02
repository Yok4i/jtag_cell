module top(
    input nreset,
    input sysclk,   //@100k
    input tck,
    input scan_en
    );
    
    logic w_clk10k;
    logic tcb_occ_enable;

    clock_gen#(.DIV(5)) i_clock_gen(
        .nreset,
        .sysclk,
        .tck,
        .scan_en,
        .tcb_occ_enable(1'b1),
        .clk10k(w_clk10k)
    );

endmodule
