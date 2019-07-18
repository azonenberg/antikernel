`timescale 1ns/1ps
`default_nettype none

module TestSqueeze();

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
	logic[263:0]	a = 0;
	wire			out_valid;
	wire[263:0]		out;

	X25519_Squeeze dut(
		.clk(clk),
		.en(en),
		.a(a),
		.out_valid(out_valid),
		.out(out)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Testbench

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Testbench

	logic[7:0] state = 0;
	always_ff @(posedge clk) begin

		en	<= 0;

		case(state)
			0: begin
				en		<= 1;
				a		<= 256'hdc21740e549bcdab5e580525a3310d66c9332e76e71b547ce3f2ba294a516967;
				state	<= 1;
			end

			1: begin
				state	<= 2;
				en		<= 1;
				a		<= 256'hf1b10fa85c89be757c05d1fbaafbfe02dbec3c323bec5c8f6bea7e3efc413e70;
			end

			2: begin

				en		<= 1;
				a		<= 256'h7dba22bb1548e333af1bacaa0911643b795e5a14641c1e1f6448cbca3ae9f705;

				state	<= 3;
			end

			3: begin
				if(out_valid && out == 264'h005c21740e549bcdab5e580525a3310d66c9332e76e71b547ce3f2ba294a51697a)
					$display("Test 1: OK");
				else begin
					$display("Test 1: FAIL");
					$finish;
				end

				en		<= 1;
				a		<= 256'h4efd154fe4e2b3365c3bb5be55aa21ac6cfa4ebc3d7938984eb51bf8f87f1a0b;

				state	<= 4;
			end

			4: begin
				if(out_valid && out == 264'h0071b10fa85c89be757c05d1fbaafbfe02dbec3c323bec5c8f6bea7e3efc413e83)
					$display("Test 2: OK");
				else begin
					$display("Test 2: FAIL");
					$finish;
				end

				en		<= 1;
				a		<= 256'h86200bf407fb8520304a1cde76ad7fa3afc4e5092d4cf3aca80ebc9a548ad408;

				state	<= 5;
			end

			5: begin
				if(out_valid && out == 264'h007dba22bb1548e333af1bacaa0911643b795e5a14641c1e1f6448cbca3ae9f705)
					$display("Test 3: OK");
				else begin
					$display("Test 3: FAIL");
					$finish;
				end

				state	<= 6;
			end

			6: begin
				if(out_valid && out == 264'h004efd154fe4e2b3365c3bb5be55aa21ac6cfa4ebc3d7938984eb51bf8f87f1a0b)
					$display("Test 4: OK");
				else begin
					$display("Test 4: FAIL");
					$finish;
				end

				state	<= 7;
			end

			7: begin
				if(out_valid && out == 264'h0006200bf407fb8520304a1cde76ad7fa3afc4e5092d4cf3aca80ebc9a548ad41b)
					$display("Test 5: OK");
				else begin
					$display("Test 5: FAIL");
					$finish;
				end

				state	<= 8;
			end

		endcase
	end

endmodule
