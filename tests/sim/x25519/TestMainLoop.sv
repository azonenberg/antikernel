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

	wire			out_valid;
	wire[255:0]		work_out;

	//actually the whole crypto_scalarmult, need to rename it!
	X25519_MainLoop dut(
		.clk(clk),
		.en(en),
		.work_in(work_in),
		.e(e),
		.out_valid(out_valid),
		.work_out(work_out)
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

			1: begin
				if(out_valid) begin
					if(work_out !== 256'h394d5f49ab5a11eb88e82e70019dfbfb2d61fbad01e37c0345ff1129c090c3e5) begin
						$display("FAIL: work_out mismatch");
						$finish;
					end
					else begin
						$display("PASS");
						//$finish;
					end
				end
			end

		endcase
	end

endmodule
