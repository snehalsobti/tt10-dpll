`default_nettype none

module tt_um_DPLL (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  //assign uo_out[7:4]  = 5'b0;
  assign uo_out[7] = 1'b0; 
  assign uio_out = 7'b0;
  assign uio_oe  = 7'b0;

  DPLL_top dpll(.clk_ref(clk), .rst_n(rst_n), .pll_out(uo_out[0]), .locked(uo_out[1]), .up(uo_out[2]), .down(uo_out[3]), .scan_en_top(uo_out[4]), 
	.scan_in_top(uo_out[5]), .scan_out_top(uo_out[6]));

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule

module DPLL_top(
	input logic clk_ref,       // Reference clock (10MHz)
	input logic rst_n,         // Active-low reset
	output logic pll_out,      // PLL output clock (100MHz)
	output logic locked,        // Lock indicator
	output logic up,
	output logic down,
	input logic scan_in_top,		//DFT and Debug Ports
	input logic scan_en_top,
	output logic scan_out_top
);

	// Internal wiring
	logic clk_fb;
	logic signed [15:0] control;
	logic up;
	logic down;
	logic pll_clk;
	logic enable;   //indicator for DCO

	logic scan_chain_connection_1, scan_chain_connection_2, scan_chain_connection_3;	//continuous scan chain
	
	/* Altera PLL IP for 100MHz
 	in case of actual asic implementation, replace it with DCO cell
  
	DCO_0002 u1(
		.refclk(clk_ref),
		.rst(!rst_n),
		.outclk_0(pll_clk),
		.locked()
	);
 
 	This is only for FPGA validation!
 	*/
	
	//Phase Frequency Detector
	PFD u2 (
		.clk(pll_clk),
		.rst_n(rst_n),
		.clk_ref(clk_ref),
		.clk_fb(clk_fb),
		.up(up),
		.down(down),
		.scan_en(scan_en_top),
		.scan_in(scan_in_top),
		.scan_out(scan_chain_connection_1)
	);

	// Low Pass Filter
	LPF u3 (
		.clk(pll_clk),
		.rst_n(rst_n),
		.up(up),
		.down(down),
		.filtered_control_signal(control),
		.scan_en(scan_en_top),
		.scan_in(scan_chain_connection_1),
		.scan_out(scan_chain_connection_2)
	);

	// N-Divide for Feedback Clock
	N_divide u4 (
		.clk_out(pll_out), 
		.rst_n(rst_n), 
		.clk_fb(clk_fb),
		.scan_en(scan_en_top),
		.scan_in(scan_chain_connection_2),
		.scan_out(scan_chain_connection_3)
	);

	// Lock indicator
	always_ff @(posedge pll_clk or negedge rst_n) begin
		if (!rst_n) begin
			locked <= 1'b0;
		end else if(scan_en_top)begin
			locked <= scan_chain_connection_3;
		end else if (!up && !down) begin
			locked <= 1'b1;
		end else begin
			locked <= 1'b0;
		end
	end
	
	assign enable = ~rst_n;

	assign pll_out = pll_clk;
	
	assign scan_out_top = locked;
	
endmodule
