	wire intosc;

	STARTUP_SPARTAN6 startup(
			.EOS(),
			.CLK(),
			.GSR(1'b0),				//don't hold everything in reset
			.KEYCLEARB(1'b1),		//don't clear BBRAM key
			.GTS(1'b0),				//don't tristate I/O
			.CFGMCLK(intosc),		//internal oscillator
			.CFGCLK()
		);
	
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) bufg_intosc (
		.clkin(intosc),
		.clkout([[selfclock]]),
		.ce(1'b1)
	);
