`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench - MAX162 Slow Memory Mode, Two Byte Read
//
// Conditional & event-driven ADC model:
//   - Conversion starts on @(negedge adc_rd) ONLY when CS=0, HBEN=0
//   - High byte mux switches on @(posedge adc_hben) ONLY when CS=0
//   - BUSY is driven by actual conversion timing, not a hardcoded clock
//   - Works at ANY clock frequency - change CLK_PERIOD to adapt
//////////////////////////////////////////////////////////////////////////////////

module adc_tb();

    //========================================================
    // PARAMETERS  - change here to adjust frequency/timing
    //========================================================

    // System clock: 1 MHz  →  period = 1000 ns
    parameter CLK_PERIOD = 1000;

    // ADC conversion time (tCONV).
    // MAX162 typical: 3 µs @ 4 MHz internal clock.
    // We model 5 µs here so it spans several 1 MHz system cycles.
    parameter CONV_TIME = 5000;

    //========================================================
    // DUT INPUTS
    //========================================================

    reg        clk             = 1'b0;
    reg        reset           = 1'b0;
    reg        start           = 1'b0;

    // Driven by the ADC model below
    reg        adc_busy        = 1'b1;     // idle = BUSY high
    reg [7:0]  adc_data_buffer = 8'd0;    // what DUT reads as adc_data_in

    //========================================================
    // DUT OUTPUTS
    //========================================================

    wire        adc_cs;
    wire        adc_rd;
    wire        adc_hben;
    wire [11:0] nn_data_in;               // 12-bit result captured by DUT
    wire        finish;

    //========================================================
    // INTERNAL ADC STATE
    //========================================================

    // Simulated 12-bit conversion result; increments each conversion
    reg [11:0] adc_data          = 12'h330;

    // Prevents re-triggering while a conversion is in progress
    reg        conversion_active = 1'b0;

    //========================================================
    // CLOCK - 1 MHz
    //========================================================

    always #(CLK_PERIOD / 2) clk = ~clk;

    //========================================================
    // STIMULUS - triggers three successive conversions
    //========================================================

    initial
    begin
        // Hold reset
        reset = 1'b0;
        start = 1'b0;
        repeat(2) @(posedge clk);

        // Release reset
        reset = 1'b1;
        repeat(2) @(posedge clk);

        //----------------------------------------------------
        // Conversion 1
        //----------------------------------------------------
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        @(posedge finish);                  // wait for DUT to complete
        repeat(3) @(posedge clk);          // idle gap

        //----------------------------------------------------
        // Conversion 2
        //----------------------------------------------------
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        @(posedge finish);
        repeat(3) @(posedge clk);

        //----------------------------------------------------
        // Conversion 3
        //----------------------------------------------------
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        @(posedge finish);
        repeat(5) @(posedge clk);

    end

    //========================================================
    // ADC MODEL - Conditional, Event-Driven
    //
    // Accurately models MAX162 Slow Memory Mode timing:
    //
    //   RD falling + CS=0 + HBEN=0  →  conversion starts, BUSY↓
    //   After tCONV                  →  BUSY↑, low byte on bus
    //   HBEN rising  + CS=0          →  high nibble muxed onto bus
    //   HBEN falling + CS=0          →  low byte restored to bus
    //
    // RD falling while HBEN=1 is IGNORED (no new conversion).
    //========================================================

    //------------------------------------------------------------
    // CONVERSION TRIGGER
    // Responds to falling edge of RD. Checks conditions to decide
    // whether to start a new conversion - exactly as the real IC.
    //------------------------------------------------------------

    always @(negedge adc_rd)
    begin
        // Conditions from datasheet p.5:
        //   CS must be low for ADC to recognise RD and HBEN inputs.
        //   Conversion only starts when CS=0, RD=0, HBEN=0.
        //   (HBEN=1 performs second-byte read, not a new conversion.)

        if (adc_cs         == 1'b0  &&
            adc_hben       == 1'b0  &&
            conversion_active == 1'b0)
        begin
            conversion_active = 1'b1;

            // BUSY goes low: conversion in progress
            adc_busy = 1'b0;

            // Simulate new analog value arriving each conversion
            adc_data = adc_data + 12'h002;

            // --- Hold BUSY low for tCONV ---
            // This is the only place timing depends on CONV_TIME.
            // Change CONV_TIME to match your actual ADC clock rate.
            #(CONV_TIME);

            // Conversion complete:
            //   • latch low byte onto data bus
            //   • raise BUSY  (DUT WAIT_BUSY detects this rising edge)
            adc_data_buffer  = adc_data[7:0];
            adc_busy         = 1'b1;
            conversion_active = 1'b0;
        end
        // else: RD fell but HBEN=1 or conversion running → ignore
    end

    //------------------------------------------------------------
    // HIGH BYTE MUX (Datasheet Table 2, Second Read)
    // When HBEN goes high, ADC muxes DB11-DB8 onto D3/11-D0/8
    // and drives LOW onto D7-D4. (Output drivers enabled by CS=0.)
    //------------------------------------------------------------

    always @(posedge adc_hben)
    begin
        // CS must be low for output drivers to be active
        if (adc_cs == 1'b0)
            adc_data_buffer = {4'b0000, adc_data[11:8]};
    end

    //------------------------------------------------------------
    // LOW BYTE RESTORE
    // When HBEN goes low again (with CS still low), ADC puts
    // DB7-DB0 back onto D7-D0/8 (e.g. returning to IDLE).
    //------------------------------------------------------------

    always @(negedge adc_hben)
    begin
        if (adc_cs == 1'b0)
            adc_data_buffer = adc_data[7:0];
    end

    //========================================================
    // DUT INSTANTIATION
    //========================================================

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