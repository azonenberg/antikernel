	//Gated PLL output [[output_net]]
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("YES")
	) bufg_[[output_net]] (
		.clkin([[output_net]]_raw),
		.clkout([[output_net]]),
		.ce(pll_locked_[[instance_name]])
	);
