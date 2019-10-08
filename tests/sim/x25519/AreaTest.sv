module AreaTest(
	input wire clk_200mhz_p,
	input wire clk_200mhz_n
);

	wire		clk_200mhz;
	IBUFGDS ibuf(
		.I(clk_200mhz_p),
		.IB(clk_200mhz_n),
		.O(clk_200mhz)
	);

	wire	clk;
	clk_wiz_0 pll(
		.clk_in1(clk_200mhz),
		.clk_out1(clk)
		);

	wire[255:0] work_in;
	wire[255:0] e;
	logic		en = 0;
	wire[255:0]	out;
	wire		out_valid;

	wire		toggle;
	vio_0 vio(
		.clk(clk),
		.probe_in0(out),
		.probe_in1(out_valid),
		.probe_out0(work_in),
		.probe_out1(e),
		.probe_out2(toggle)
	);

	logic	toggle_ff = 0;
	always_ff @(posedge clk) begin
		toggle_ff	<= toggle;

		en 			<= (toggle != toggle_ff);
	end

	X25519_ScalarMult dut(
		.clk(clk),
		.en(en),
		.work_in(work_in),
		.e(e),
		.out_valid(out_valid),
		.work_out(out)
	);

endmodule
