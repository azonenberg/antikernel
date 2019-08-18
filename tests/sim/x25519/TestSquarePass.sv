`timescale 1ns/1ps
`default_nettype none

module TestMultPass();

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
	logic[4:0]	i			= 0;
	wire			out_valid;
	wire[31:0]		out;

	X25519_SquarePass dut(
		.clk(clk),
		.en(en),
		.a(a),
		.b(a),
		.i(i),
		.out_valid(out_valid),
		.out(out)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Testbench

	logic[7:0]	state		= 0;
	logic[31:0] expected	= 0;
	always_ff @(posedge clk) begin

		en	<= 0;

		case(state)

			0: begin
				en		<= 1;
				a		<= 256'hdc21740e549bcdab5e580525a3310d66c9332e76e71b547ce3f2ba294a516967;
				i 		<= 0;
				en		<= 1;
				state	<= 1;
			end

			1: begin
				case(i)
					0:	expected <= 32'h011230a2;
					1:	expected <= 32'h0128b7e5;
					2:	expected <= 32'h01168dac;
					3:	expected <= 32'h010022c8;
					4:	expected <= 32'h00e8608a;
					5:	expected <= 32'h00f251c9;
					6:	expected <= 32'h00bfc458;
					7:	expected <= 32'h00c6499c;
					8:	expected <= 32'h00b7b885;
					9:	expected <= 32'h00b3bc90;
					10:	expected <= 32'h009be725;
					11:	expected <= 32'h00848907;
					12:	expected <= 32'h0081b520;
					13:	expected <= 32'h0077fcd6;
					14:	expected <= 32'h007f32df;
					15:	expected <= 32'h0078b6c8;
					16:	expected <= 32'h0085d147;
					17:	expected <= 32'h00764754;
					18:	expected <= 32'h006f3223;
					19:	expected <= 32'h0061eb13;
					20:	expected <= 32'h004c45b6;
					21:	expected <= 32'h005f5195;
					22:	expected <= 32'h0054498c;
					23:	expected <= 32'h004cfd7d;
					24:	expected <= 32'h003dcbee;
					25:	expected <= 32'h00369c91;
					26:	expected <= 32'h0016d69a;
					27:	expected <= 32'h001db81d;
					28:	expected <= 32'h001a3072;
					29:	expected <= 32'h00126933;
					30:	expected <= 32'h0018d268;
					31:	expected <= 32'h0008198f;
				endcase

				state	<= 2;
			end
		/*
			2: begin

				if(out_valid) begin
					if(out == expected)
						$display("Test %d: OK", i);
					else begin
						$display("Test %d: FAIL", i);
						$finish;
					end

					if(i == 31)
						state	<= 3;

					else begin
						state	<= 1;
						i		<= i + 1'h1;
						en		<= 1;
					end
				end

			end*/

		endcase
	end

endmodule
