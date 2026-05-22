# 12-bit ADC Interface Controller using Verilog

## Description

This project implements a behavioral FPGA interface controller for a 12-bit ADC using Verilog HDL. The design models the MAX162/MAX7572 Slow Memory Mode two-byte read operation and reproduces datasheet-style timing behavior using an event-driven ADC model.

The controller demonstrates how an FPGA communicates with an external ADC using active-low control signals such as CS̅, RD̅, and BUSY̅, along with HBEN-based byte selection. The project focuses on digital interfacing, conversion timing, multi-byte data transfer, and protocol-aware FSM design.

The ADC provides a 12-bit output over an 8-bit data bus using two successive read cycles.

---

## ADC Interface Operation

The ADC output is transferred over an 8-bit data bus in two reads.

### First Read — Lower Byte
- HBEN = 0
- D7–D0 contain DB7–DB0

### Second Read — Upper Nibble
- HBEN = 1
- D3–D0 contain DB11–DB8
- D7–D4 are driven LOW

The controller models:
- Active-low BUSY conversion timing
- Datasheet-based read sequencing
- HBEN-controlled byte selection
- Event-driven ADC bus behavior
- 1 MHz clock timing

---

## FSM Operation

### IDLE
Controller waits for start signal.

### START_CONV
CS̅ and RD̅ go LOW, triggering ADC conversion.

### WAIT_BUSY
ADC keeps BUSY LOW during conversion.
The controller waits for the BUSY rising edge indicating conversion completion.

### READ_LOW
Lower 8 bits are captured from the ADC data bus.

### SWITCH_HIGH
HBEN goes HIGH to switch ADC output mux to upper nibble.

### WAIT_HIGH
Wait state allowing ADC bus to settle before sampling upper nibble.

### READ_HIGH
Upper 4 bits are captured and combined with the lower byte to reconstruct the full 12-bit ADC result.

---

## Inputs and Outputs

### Inputs
- `clk` : 1 MHz system clock
- `reset` : Active-low reset
- `start` : Start conversion signal
- `adc_busy` : ADC BUSY signal
- `adc_data_in[7:0]` : ADC data bus

### Outputs
- `adc_cs` : Active-low chip select
- `adc_rd` : Active-low read signal
- `adc_hben` : High-byte enable signal
- `data_out[11:0]` : Final reconstructed ADC output
- `finish` : Conversion complete flag

---

## Example ADC Read

For ADC output:

```text
0x330
```

### First Read
```text
HBEN = 0
DATA = 0x30
```

### Second Read
```text
HBEN = 1
DATA = 0x03
```

Final reconstructed ADC output:

```text
0x330
```

---

## Verification

The design was verified using a Verilog testbench in Xilinx Vivado.

The ADC model is fully conditional and event-driven:

- Conversion starts on `@(negedge adc_rd)` only when:
  - `CS̅ = 0`
  - `HBEN = 0`

- BUSY remains LOW during conversion time (`tCONV`)

- BUSY returns HIGH after conversion completion

- HBEN rising edge switches ADC output mux to upper nibble

Behavioral simulation and waveform analysis confirmed:
- Correct two-byte ADC read operation
- Proper BUSY timing behavior
- Accurate HBEN-controlled data multiplexing
- Datasheet-style ADC timing implementation

Waveforms were simulated using a 1 MHz system clock.

---

## Tools Used

- Verilog HDL
- Xilinx Vivado (Behavioral Simulation)

---

## Files

- `adc_controller.v`
- `adc_tb.v`

---

## Author

Prakriti Chandra
