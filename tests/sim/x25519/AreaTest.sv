module AreaTest(
	input wire clk
);

	wire[263:0] a;
	wire[263:0] b;
	wire		en;

	wire[4:0]	i;

	wire[263:0]	add_out;
	wire		add_valid;

	vio_0 vio(
		.clk(clk),
		.probe_in0(add_out[255:0]),
		.probe_in1(add_out[263:256]),
		.probe_in2(add_valid),
		.probe_out0(a[255:0]),
		.probe_out1(a[263:256]),
		.probe_out2(b[255:0]),
		.probe_out3(b[263:256]),
		.probe_out4(en),
		.probe_out5(i)
	);

	X25519_Mult dut(
		.clk(clk),
		.en(en),
		.a(a),
		.b(b),
		.out_valid(add_valid),
		.out(add_out)
	);

endmodule
