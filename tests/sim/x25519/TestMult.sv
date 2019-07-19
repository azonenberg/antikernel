`timescale 1ns/1ps
`default_nettype none

module TestMult();

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

	X25519_Mult dut(
		.clk(clk),
		.en(en),
		.a(a),
		.b(b),
		.out_valid(out_valid),
		.out(out)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Testbench

	logic[7:0] state = 0;
	always_ff @(posedge clk) begin

		en	<= 0;

		case(state)

			0: begin
				en		<= 1;
				a		<= 264'h00dc21740e549bcdab5e580525a3310d66c9332e76e71b547ce3f2ba294a516967;
				b		<= 264'h00873d418211b4c6b2d4e9175d5a58b7329a9f635a8de8f8c246fbabcdecff73c6;
				state	<= 1;
			end

			1: begin
				if(out_valid) begin
					if(out == 264'h0073eb81412a74aa40262a3d10bbf09e7d735e1045a29a0f8f53932ac47f774d0e)
						$display("Test 1: OK");
					else begin
						$display("Test 1: FAIL");
						$finish;
					end

					en		<= 1;
					a		<= 264'h00f1b10fa85c89be757c05d1fbaafbfe02dbec3c323bec5c8f6bea7e3efc413e70;
					b		<= 264'h00b3eb9599bbf961d8943ce6293afa431a5c1854affbb02a3896dc970167e1a1e9;
					state	<= 2;
				end
			end

			2: begin
				if(out_valid) begin
					if(out == 264'h003e9e0dc20f7b906c1e24ae829840d93848cb59f17fecd9cd655b3ede33ffb1f5)
						$display("Test 2: OK");
					else begin
						$display("Test 2: FAIL");
						$finish;
					end

					en		<= 1;
					a		<= 264'h007dba22bb1548e333af1bacaa0911643b795e5a14641c1e1f6448cbca3ae9f705;
					b		<= 264'h00f59b196f5c4750cd3b10f2d4dc9e2470634bc573c57ba823bd47d00be5a100ef;
					state	<= 3;
				end
			end

			3: begin
				if(out_valid) begin
					if(out == 264'h0017c59eb75093abd945e2916b5d56c3c9f84d2648e5fbecc3fb6df1c678762720)
						$display("Test 3: OK");
					else begin
						$display("Test 3: FAIL");
						$finish;
					end

					en		<= 1;
					a		<= 264'h004efd154fe4e2b3365c3bb5be55aa21ac6cfa4ebc3d7938984eb51bf8f87f1a0b;
					b		<= 264'h00a98249329ef0af94d3047370a21a2b8605cb775f344de032e8ca13a429231ce1;
					state	<= 4;
				end
			end

			4: begin
				if(out_valid) begin
					if(out == 264'h002b3a00e17df43da02b9f3d787312d505db74ad5c0101763c28e15e82062b40dc)
						$display("Test 4: OK");
					else begin
						$display("Test 4: FAIL");
						$finish;
					end

					en		<= 1;
					a		<= 264'h0086200bf407fb8520304a1cde76ad7fa3afc4e5092d4cf3aca80ebc9a548ad408;
					b		<= 264'h00c3bab9ec04b26c23f6c4ec3247d42d84cd3306429bd78e5b4418d50a4829b270;
					state	<= 5;
				end
			end

			5: begin
				if(out_valid) begin
					if(out == 264'h001a925a6fa37a769241cc4082041c893c9d1277cf71c71bddef713917e57ff5f1)
						$display("Test 5: OK");
					else begin
						$display("Test 5: FAIL");
						$finish;
					end

					state	<= 6;
				end
			end

		endcase
	end

endmodule
