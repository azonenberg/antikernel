`timescale 1ns/1ps
`default_nettype none

module TestMult121665();

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

	X25519_Mult121665 dut(
		.clk(clk),
		.en(en),
		.a(a),
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
				state	<= 1;
			end

			1: begin
				if(out_valid) begin
					if(out == 264'h0076d50ea0922c309045e6245a73521e6b0d356b0063b42ea9400be160ed7a8950)
						$display("Test 1: OK");
					else begin
						$display("Test 1: FAIL");
						$finish;
					end

					en		<= 1;
					a		<= 264'h00f1b10fa85c89be757c05d1fbaafbfe02dbec3c323bec5c8f6bea7e3efc413e70;
					state	<= 2;
				end
			end

			2: begin
				if(out_valid) begin
					if(out == 264'h0066025d73135d58f34a184727fa4accc92aac7df0c6c19da67ec8ec0b1bad44a3)
						$display("Test 2: OK");
					else begin
						$display("Test 2: FAIL");
						$finish;
					end

					en		<= 1;
					a		<= 264'h007dba22bb1548e333af1bacaa0911643b795e5a14641c1e1f6448cbca3ae9f705;
					state	<= 3;
				end
			end

			3: begin
				if(out_valid) begin
					if(out == 264'h004ab3f1fea5129607cf6655ff9264cd4be218b4ed9707e50b889bf9a912e0a4b5)
						$display("Test 3: OK");
					else begin
						$display("Test 3: FAIL");
						$finish;
					end

					en		<= 1;
					a		<= 264'h004efd154fe4e2b3365c3bb5be55aa21ac6cfa4ebc3d7938984eb51bf8f87f1a0b;
					state	<= 4;
				end
			end

			4: begin
				if(out_valid) begin
					if(out == 264'h0024cda6f9c0155df035614e466cad7afc1ba543db87c9f8b606e30f4aedadca10)
						$display("Test 4: OK");
					else begin
						$display("Test 4: FAIL");
						$finish;
					end

					en		<= 1;
					a		<= 264'h0086200bf407fb8520304a1cde76ad7fa3afc4e5092d4cf3aca80ebc9a548ad408;
					state	<= 5;
				end
			end

			5: begin
				if(out_valid) begin
					if(out == 264'h000450d3c5b6df86c5c6621ab00de21fb1f5f62e6248ab3aaa03b03e0d0ecfa3f5)
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
