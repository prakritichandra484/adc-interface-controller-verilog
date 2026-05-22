`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ADC Controller - MAX162 Slow Memory Mode, Two Byte Read
//////////////////////////////////////////////////////////////////////////////////
module adc_controller(

    input clk,
    input reset,              // ACTIVE LOW RESET
    input start,

    input adc_busy,
    input [7:0] adc_data_in,

    output reg adc_cs,
    output reg adc_rd,
    output reg adc_hben,

    output reg [11:0] data_out,
    output reg finish
);

    //========================================================
    // STATE DEFINITIONS  (3-bit, 7 states)
    //========================================================

    parameter [2:0]
        IDLE        = 3'b000,
        START_CONV  = 3'b001,
        WAIT_BUSY   = 3'b010,
        READ_LOW    = 3'b011,
        SWITCH_HIGH = 3'b100,
        WAIT_HIGH   = 3'b101,   // Pipeline wait: let ADC mux high nibble onto bus
        READ_HIGH   = 3'b110;

    //========================================================
    // INTERNAL REGISTERS
    //========================================================

    reg [2:0] state         = IDLE;
    reg       prev_adc_busy = 1'b1;

    //========================================================
    // BUSY EDGE DETECTOR
    //========================================================

    always @(posedge clk)
    begin
        prev_adc_busy <= adc_busy;
    end

    //========================================================
    // MAIN FSM
    //========================================================

    always @(posedge clk)
    begin

        //----------------------------------------------------
        // RESET (active low)
        //----------------------------------------------------

        if (!reset)
        begin
            state    <= IDLE;
            adc_cs   <= 1'b1;
            adc_rd   <= 1'b1;
            adc_hben <= 1'b0;
            data_out <= 12'd0;
            finish   <= 1'b0;
        end

        //----------------------------------------------------
        // FSM
        //----------------------------------------------------

        else
        begin

            finish <= 1'b0;

            case (state)

            //------------------------------------------------
            // IDLE
            //------------------------------------------------

            IDLE:
            begin
                adc_cs   <= 1'b1;
                adc_rd   <= 1'b1;
                adc_hben <= 1'b0;
                if (start)
                    state <= START_CONV;
            end

            //------------------------------------------------
            // START CONVERSION
            // CS=0, RD=0, HBEN=0 - falling edge of RD triggers
            // conversion start inside the ADC (see datasheet p.5)
            //------------------------------------------------

            START_CONV:
            begin
                adc_cs   <= 1'b0;
                adc_rd   <= 1'b0;
                adc_hben <= 1'b0;
                state    <= WAIT_BUSY;
            end

            //------------------------------------------------
            // WAIT FOR CONVERSION COMPLETE
            // Hold CS=0, RD=0. ADC keeps BUSY low during tCONV.
            // We detect the rising edge of BUSY (low→high).
            //------------------------------------------------

            WAIT_BUSY:
            begin
                if (prev_adc_busy == 1'b0 && adc_busy == 1'b1)
                    state <= READ_LOW;
                // else: stay, CS/RD remain low (held from START_CONV)
            end

            //------------------------------------------------
            // READ LOWER BYTE (HBEN=0)
            // Datasheet Table 2, First Read:
            //   D7-D0 = DB7-DB0
            //------------------------------------------------

            READ_LOW:
            begin
                data_out[7:0] <= adc_data_in;   // capture DB7-DB0
                adc_cs        <= 1'b1;
                adc_rd        <= 1'b1;
                state         <= SWITCH_HIGH;
            end

            //------------------------------------------------
            // SWITCH TO HIGH BYTE
            // Assert HBEN=1 with CS=0, RD=0.
            // The ADC muxes DB11-DB8 onto D3/11-D0/8 (d4-d7=LOW).
            // RD falls here - ADC model detects @negedge adc_rd
            // but HBEN=1 so NO new conversion starts.
            //------------------------------------------------

            SWITCH_HIGH:
            begin
                adc_hben <= 1'b1;
                adc_cs   <= 1'b0;
                adc_rd   <= 1'b0;
                state    <= WAIT_HIGH;
            end

            //------------------------------------------------
            // WAIT HIGH  ← KEY FIX
            // Hold for one cycle so the ADC model has time to
            // update adc_data_buffer with the high nibble after
            // it sees HBEN go high. Without this, READ_HIGH
            // samples the stale low-byte value.
            //------------------------------------------------

            WAIT_HIGH:
            begin
                state <= READ_HIGH;
            end

            //------------------------------------------------
            // READ HIGH BYTE (HBEN=1)
            // Datasheet Table 2, Second Read:
            //   D7-D4 = LOW, D3/11-D0/8 = DB11-DB8
            // We read adc_data_in[3:0] = DB11-DB8
            //------------------------------------------------

            READ_HIGH:
            begin
                data_out[11:8] <= adc_data_in[3:0];  // capture DB11-DB8
                adc_cs         <= 1'b1;
                adc_rd         <= 1'b1;
                adc_hben       <= 1'b0;
                finish         <= 1'b1;
                state          <= IDLE;
            end

            //------------------------------------------------
            // DEFAULT
            //------------------------------------------------

            default:
            begin
                state    <= IDLE;
                adc_cs   <= 1'b1;
                adc_rd   <= 1'b1;
                adc_hben <= 1'b0;
            end

            endcase
        end
    end

endmodule