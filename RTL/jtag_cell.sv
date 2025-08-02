`define IR_LENGTH   4
`define DR_LENGTH   4
`define DFTR_LENGTH 4

module jtag_cell(
    input TCK,
    input TRST,
    input TMS,
    input TDI,
    output TDO
    );

    logic ff_TDO;
    logic [`IR_LENGTH-1   : 0] jtag_ir;
    logic [`IR_LENGTH-1   : 0] jtag_ir_shadow;
    logic [`DR_LENGTH-1   : 0] jtag_dr;
    logic [`DFTR_LENGTH-1 : 0] jtag_dft;
    logic jtag_ir_shift_en, jtag_ir_shift_hold, jtag_ir_shadow_update, jtag_ir_exit1, jtag_ir_pause, jtag_ir_exit2;
    logic jtag_dr_shift_en, jtag_dr_shift_hold, jtag_dr_shadow_update, jtag_dr_exit1, jtag_dr_pause, jtag_dr_exit2;

    typedef enum{
        TEST_LOGIC_RESET,
        RUN_TEST_IDLE,
        DR_SELECT_SCAN,
        DR_CAPTURE,
        DR_SHIFT,
        DR_EXIT_1,
        DR_PAUSE,
        DR_EXIT_2,
        DR_UPDATE,
        IR_SELECT_SCAN,
        IR_CAPTURE,
        IR_SHIFT,
        IR_EXIT_1,
        IR_PAUSE,
        IR_EXIT_2,
        IR_UPDATE
    }TAP_FSM;
    TAP_FSM cur_state;

    logic tms_q1, tms_q2, tms_q3, tms_q4, tms_reset;

    always@(posedge TCK)
    begin
        tms_q1 <= TMS;
        tms_q2 <= tms_q1;
        tms_q3 <= tms_q2;
        tms_q4 <= tms_q3;
    end

    assign tms_reset = TMS & tms_q1 & tms_q2 & tms_q3 & tms_q4; // JTAG reset after 5 consecutives TMS=1

    always@(posedge TCK or negedge TRST)
    begin
        if(~TRST | tms_reset)
        begin
            cur_state <= TEST_LOGIC_RESET;
        end
        else
        begin
            case(cur_state)
                TEST_LOGIC_RESET : cur_state <= TMS ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
                RUN_TEST_IDLE    : cur_state <= TMS ? DR_SELECT_SCAN   : RUN_TEST_IDLE;
                DR_SELECT_SCAN   : cur_state <= TMS ? IR_SELECT_SCAN   : DR_CAPTURE;
                DR_CAPTURE       : cur_state <= TMS ? DR_EXIT_1        : DR_SHIFT;
                DR_SHIFT         : cur_state <= TMS ? DR_EXIT_1        : DR_SHIFT;
                DR_EXIT_1        : cur_state <= TMS ? DR_UPDATE        : DR_PAUSE;
                DR_PAUSE         : cur_state <= TMS ? DR_EXIT_2        : DR_PAUSE;
                DR_EXIT_2        : cur_state <= TMS ? DR_UPDATE        : DR_SHIFT;
                DR_UPDATE        : cur_state <= TMS ? DR_SELECT_SCAN   : RUN_TEST_IDLE;
                IR_SELECT_SCAN   : cur_state <= TMS ? TEST_LOGIC_RESET : IR_CAPTURE;
                IR_CAPTURE       : cur_state <= TMS ? IR_EXIT_1        : IR_SHIFT;
                IR_SHIFT         : cur_state <= TMS ? IR_EXIT_1        : IR_SHIFT;
                IR_EXIT_1        : cur_state <= TMS ? IR_UPDATE        : IR_PAUSE;
                IR_PAUSE         : cur_state <= TMS ? IR_EXIT_2        : IR_PAUSE;
                IR_EXIT_2        : cur_state <= TMS ? IR_UPDATE        : IR_SHIFT;
                IR_UPDATE        : cur_state <= TMS ? IR_SELECT_SCAN   : RUN_TEST_IDLE;
                default          : cur_state <= TEST_LOGIC_RESET;
            endcase
        end
    end

    always@(cur_state)
    begin
        case(cur_state)
            TEST_LOGIC_RESET :
                begin
                    ff_TDO = 0;

                    jtag_ir_shift_en = 1;
                    jtag_ir_shift_hold = 1;
                    jtag_ir_shadow_update = 0;
                    jtag_ir_exit1 = 0;
                    jtag_ir_exit2 = 0;

                    jtag_dr_shift_en = 1;
                    jtag_dr_shift_hold = 1;
                    jtag_dr_shadow_update = 0;
                    jtag_dr_exit1 = 0;
                    jtag_dr_exit2 = 0;
                end
//            RUN_TEST_IDLE    :
            IR_SELECT_SCAN   : jtag_ir_shift_en = 0;
            IR_CAPTURE       : jtag_ir_shift_en = 0; 
            IR_SHIFT         : 
                begin
                jtag_ir_shift_en = 1;
                jtag_ir_shift_hold = 0;
                end
            IR_EXIT_1        :
                begin
                jtag_ir_shift_hold = 1;
                jtag_ir_exit1 = 1;
                end
            IR_PAUSE         :
                begin
                jtag_ir_pause = (jtag_ir_exit1 | jtag_ir_pause) ? 1 : 0;
                end
            IR_EXIT_2        :
                begin
                jtag_ir_exit2 = jtag_ir_pause ? 1 : 0;
                end
            IR_UPDATE        : jtag_ir_shadow_update = (jtag_ir_exit1 | jtag_ir_exit2) ? 1 : 0;
            default          :
                begin
                    ff_TDO = 0;

                    jtag_ir_shift_en = 1;
                    jtag_ir_shift_hold = 1;
                    jtag_ir_shadow_update = 0;
                    jtag_ir_exit1 = 0;
                    jtag_ir_exit2 = 0;

                    jtag_dr_shift_en = 1;
                    jtag_dr_shift_hold = 1;
                    jtag_dr_shadow_update = 0;
                    jtag_dr_exit1 = 0;
                    jtag_dr_exit2 = 0;
                end
        endcase
    end

//-------------------------------------------------------
//  INSTRUCTION REGISTER
//-------------------------------------------------------
    always@(posedge TCK or negedge jtag_ir_shift_en)
    begin
        if(~jtag_ir_shift_en)
        begin
            jtag_ir <= `IR_LENGTH'b1010;
        end
        else
        begin
            jtag_ir <= jtag_ir_shift_hold ? jtag_ir : {jtag_ir[`IR_LENGTH-1:1] , TDI}; 
            jtag_ir_shadow <= jtag_ir_shadow_update ? jtag_ir : jtag_ir_shadow;
        end
    end

//-------------------------------------------------------
//  DATA REGISTER
//-------------------------------------------------------
    always@(posedge TCK or negedge jtag_dr_shift_en)
    begin
        if(~jtag_dr_shift_en)
        begin
            jtag_dr <= `DR_LENGTH'b1010;
        end
        else
        begin
            jtag_dr <= jtag_dr_shift_hold ? jtag_dr : {jtag_dr[`DR_LENGTH-1:1] , TDI}; 
        end
    end

    assign TDO = ff_TDO;

endmodule