	//Differential clock input for transceiver
	wire [[name]];
	IBUFDS_GTE2 #(
		.CLKRCV_TRST("TRUE"),
		.CLKCM_CFG("TRUE"),
		.CLKSWING_CFG(2'b11)
	) ibuf (
		.I([[name]]_p),
		.IB([[name]]_n),
		.CEB(1'b0),
		.O([[name]]),
		.ODIV2()
	);
