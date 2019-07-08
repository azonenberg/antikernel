`timescale 1ns/1ps
`default_nettype none

module TestAdd();

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
	logic[263:0]	b = 0;
	wire			out_valid;
	wire[263:0]		out;

	X25519_Add dut(
		.clk(clk),
		.en(en),
		.a(a),
		.b(b),
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
				b		<= 256'h873d418211b4c6b2d4e9175d5a58b7329a9f635a8de8f8c246fbabcdecff73c6;
				state	<= 1;
			end

			1: begin
				state	<= 2;
				en		<= 1;
				a		<= 256'hf1b10fa85c89be757c05d1fbaafbfe02dbec3c323bec5c8f6bea7e3efc413e70;
				b		<= 256'hb3eb9599bbf961d8943ce6293afa431a5c1854affbb02a3896dc970167e1a1e9;
			end

			2: begin
				if(out_valid && out == 264'h01635eb5906650945e33411c82fd89c49963d291d175044d3f2aee65f73750dd2d)
					$display("Test 1: OK");
				else begin
					$display("Test 1: FAIL");
					$finish;
				end

				en		<= 1;
				a		<= 256'h7dba22bb1548e333af1bacaa0911643b795e5a14641c1e1f6448cbca3ae9f705;
				b		<= 256'hf59b196f5c4750cd3b10f2d4dc9e2470634bc573c57ba823bd47d00be5a100ef;

				state	<= 3;
			end

			3: begin
				if(out_valid && out == 264'h01a59ca5421883204e1042b824e5f6411d380490e2379c86c802c715406422e059)
					$display("Test 2: OK");
				else begin
					$display("Test 2: FAIL");
					$finish;
				end

				en		<= 1;
				a		<= 256'h4efd154fe4e2b3365c3bb5be55aa21ac6cfa4ebc3d7938984eb51bf8f87f1a0b;
				b		<= 256'ha98249329ef0af94d3047370a21a2b8605cb775f344de032e8ca13a429231ce1;

				state	<= 4;
			end

			4: begin
				if(out_valid && out == 264'h0173553c2a71903400ea2c9f7ee5af88abdcaa1f882997c64321909bd6208af7f4)
					$display("Test 3: OK");
				else begin
					$display("Test 3: FAIL");
					$finish;
				end

				en		<= 1;
				a		<= 256'h86200bf407fb8520304a1cde76ad7fa3afc4e5092d4cf3aca80ebc9a548ad408;
				b		<= 256'hc3bab9ec04b26c23f6c4ec3247d42d84cd3306429bd78e5b4418d50a4829b270;

				state	<= 5;
			end

			5: begin
				if(out_valid && out == 264'h00f87f5e8283d362cb2f40292ef7c44d3272c5c61b71c718cb377f2f9d21a236ec)
					$display("Test 4: OK");
				else begin
					$display("Test 4: FAIL");
					$finish;
				end

				state	<= 6;
			end

			6: begin
				if(out_valid && out == 264'h0149dac5e00cadf144270f0910be81ad287cf7eb4bc9248207ec2791a49cb48678)
					$display("Test 5: OK");
				else begin
					$display("Test 5: FAIL");
					$finish;
				end

				state	<= 7;
			end

		endcase
	end

endmodule
