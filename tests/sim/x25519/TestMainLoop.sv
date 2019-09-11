`timescale 1ns/1ps
`default_nettype none

module TestMainLoop();

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

	logic			en 			= 0;
	logic[255:0]	work_in		= 0;
	logic[255:0]	e			= 0;

	//wire			out_valid;

	X25519_MainLoop dut(
		.clk(clk),
		.en(en),
		.work_in(work_in),
		.e(e)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Testbench

	logic[7:0] state = 0;
	always_ff @(posedge clk) begin

		en	<= 0;

		case(state)
			0: begin
				en			<= 1;

				work_in		<= 256'h873d418211b4c6b2d4e9175d5a58b7329a9f635a8de8f8c246fbabcdecff73c6;
				e			<= 256'h5c21740e549bcdab5e580525a3310d66c9332e76e71b547ce3f2ba294a516960;
				state		<= 1;
			end

		endcase
	end

endmodule
