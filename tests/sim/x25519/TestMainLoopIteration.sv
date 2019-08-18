`timescale 1ns/1ps
`default_nettype none

module TestMainLoopIteration();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clocking

	logic	clk = 0;
	logic	ready = 0;

	initial begin
		#100;
		ready = 1;
	end

	always begin
		#5;
		clk = 0;
		#5;
		clk = ready;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	logic			en = 0;
	logic[511:0]	xzm1_in 	= 0;
	logic[511:0]	xzm_in		= 0;
	logic			b			= 0;
	logic[263:0]	work_low	= 0;

	wire			out_valid;
	wire[511:0]		xzm_out;
	wire[511:0]		xzm1_out;

	X25519_MainLoopIteration dut(
		.clk(clk),
		.en(en),
		.xzm1_in(xzm1_in),
		.xzm_in(xzm_in),
		.work_low(work_low),
		.b(b),
		.out_valid(out_valid),
		.xzm_out(xzm_out),
		.xzm1_out(xzm1_out)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Testbench

	logic[7:0] state = 0;
	always_ff @(posedge clk) begin

		en	<= 0;

		case(state)
			0: begin
				en			<= 1;

				xzm1_in		<= 512'h000000000000000000000000000000000000000000000000000000000000000_1873d418211b4c6b2d4e9175d5a58b7329a9f635a8de8f8c246fbabcdecff73c6;
				xzm_in		<= 512'h000000000000000000000000000000000000000000000000000000000000000_00000000000000000000000000000000000000000000000000000000000000001;
				work_low	<= 264'h00873d418211b4c6b2d4e9175d5a58b7329a9f635a8de8f8c246fbabcdecff73c6;
				b			<= 1;
				state		<= 1;
			end

		endcase
	end

endmodule
