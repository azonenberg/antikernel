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

	X25519_ScalarMult dut(
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

				e			<= 256'h4efd154fe4e2b3365c3bb5be55aa21ac6cfa4ebc3d7938984eb51bf8f87f1a0b;
				work_in		<= 256'ha98249329ef0af94d3047370a21a2b8605cb775f344de032e8ca13a429231ce1;
				state		<= 1;
			end

			1: begin
				if(out_valid) begin
					if(work_out !== 256'h16a5809b6050c51eb0b3b00ed972c12e22bc8cb71ac00f99f30c44395bdf3f85) begin
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
