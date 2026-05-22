`timescale 1ns / 1ps


    input clk,
    input reset,             
    input start,

    input adc_busy,
    input [7:0] adc_data_in,

    output reg adc_cs,
    output reg adc_rd,
    output reg adc_hben,

    output reg [11:0] data_out,
    output reg finish
);

   

    parameter [2:0]
        IDLE        = 3'b000,
        START_CONV  = 3'b001,
        WAIT_BUSY   = 3'b010,
        READ_LOW    = 3'b011,
        SWITCH_HIGH = 3'b100,
        WAIT_HIGH   = 3'b101,   
        READ_HIGH   = 3'b110;

   

    reg [2:0] state         = IDLE;
    reg       prev_adc_busy = 1'b1;

    

    always @(posedge clk)
    begin
        prev_adc_busy <= adc_busy;
    end

   
    always @(posedge clk)
    begin

        

        if (!reset)
        begin
            state    <= IDLE;
            adc_cs   <= 1'b1;
            adc_rd   <= 1'b1;
            adc_hben <= 1'b0;
            data_out <= 12'd0;
            finish   <= 1'b0;
        end

        

        else
        begin

            finish <= 1'b0;

            case (state)

            

            IDLE:
            begin
                adc_cs   <= 1'b1;
                adc_rd   <= 1'b1;
                adc_hben <= 1'b0;
                if (start)
                    state <= START_CONV;
            end

            

            START_CONV:
            begin
                adc_cs   <= 1'b0;
                adc_rd   <= 1'b0;
                adc_hben <= 1'b0;
                state    <= WAIT_BUSY;
            end

           

            WAIT_BUSY:
            begin
                if (prev_adc_busy == 1'b0 && adc_busy == 1'b1)
                    state <= READ_LOW;
                
            end

           

            READ_LOW:
            begin
                data_out[7:0] <= adc_data_in;   
                adc_cs        <= 1'b1;
                adc_rd        <= 1'b1;
                state         <= SWITCH_HIGH;
            end

           

            SWITCH_HIGH:
            begin
                adc_hben <= 1'b1;
                adc_cs   <= 1'b0;
                adc_rd   <= 1'b0;
                state    <= WAIT_HIGH;
            end

            

            WAIT_HIGH:
            begin
                state <= READ_HIGH;
            end

            

            READ_HIGH:
            begin
                data_out[11:8] <= adc_data_in[3:0];  
                adc_cs         <= 1'b1;
                adc_rd         <= 1'b1;
                adc_hben       <= 1'b0;
                finish         <= 1'b1;
                state          <= IDLE;
            end

           

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
