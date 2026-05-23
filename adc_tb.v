`timescale 1ns / 1ps


module adc_tb();

    
    parameter CLK_PERIOD = 1000;

    .
    parameter CONV_TIME = 5000;

   

    reg        clk             = 1'b0;
    reg        reset           = 1'b0;
    reg        start           = 1'b0;

    
    reg        adc_busy        = 1'b1;    
    reg [7:0]  adc_data_buffer = 8'd0;    

    

    wire        adc_cs;
    wire        adc_rd;
    wire        adc_hben;
    wire [11:0] nn_data_in;              
    wire        finish;

   
    reg [11:0] adc_data          = 12'h330;

   
    reg        conversion_active = 1'b0;


    always #(CLK_PERIOD / 2) clk = ~clk;

    
    initial
    begin
        // Hold reset
        reset = 1'b0;
        start = 1'b0;
        repeat(2) @(posedge clk);

        // Release reset
        reset = 1'b1;
        repeat(2) @(posedge clk);

        
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        @(posedge finish);                  
        repeat(3) @(posedge clk);         

        
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        @(posedge finish);
        repeat(3) @(posedge clk);

       
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        @(posedge finish);
        repeat(5) @(posedge clk);

    end

    always @(negedge adc_rd)
    begin
        

        if (adc_cs         == 1'b0  &&
            adc_hben       == 1'b0  &&
            conversion_active == 1'b0)
        begin
            conversion_active = 1'b1;

           
            adc_busy = 1'b0;

           
            adc_data = adc_data + 12'h002;

           
            #(CONV_TIME);

           
            adc_data_buffer  = adc_data[7:0];
            adc_busy         = 1'b1;
            conversion_active = 1'b0;
        end




    always @(posedge adc_hben)
    begin

        if (adc_cs == 1'b0)
            adc_data_buffer = {4'b0000, adc_data[11:8]};
    end

   
    always @(negedge adc_hben)
    begin
        if (adc_cs == 1'b0)
            adc_data_buffer = adc_data[7:0];
    end

    

    adc_controller DUT
    (
        .clk        (clk),
        .reset      (reset),
        .start      (start),
        .adc_busy   (adc_busy),
        .adc_data_in(adc_data_buffer),
        .adc_cs     (adc_cs),
        .adc_rd     (adc_rd),
        .adc_hben   (adc_hben),
        .data_out   (nn_data_in),
        .finish     (finish)
    );

endmodule
