	wire intosc;
	
	STARTUPE2 #(
		.PROG_USR("FALSE"),		//Don't lock resets (requires encrypted bitstream)
		.SIM_CCLK_FREQ(15.0)	//Default to 66 MHz clock for simulation boots
	)
	startup (
		.CFGCLK(),				//Configuration clock not used
		.CFGMCLK(intosc),		//Internal configuration oscillator
		.EOS(),					//End-of-startup ignored
		.CLK(),					//Configuration clock not used
		.GSR(1'b0),				//Not using GSR
		.GTS(1'b0),				//Not using GTS
		.KEYCLEARB(1'b1),		//Not zeroizing BBRAM
		.PREQ(),				//PROG_B request not used
		.PACK(1'b0),			//PROG_B ack not used

		.USRCCLKO([[cclk_netname]]),		//CCLK pin
		.USRCCLKTS([[cclk_highz]]),	//Assert to tristate CCLK

		.USRDONEO(1'b1),		//Hold DONE pin high
		.USRDONETS(1'b1)		//Do not tristate DONE pin
		);
	
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) bufg_intosc (
		.clkin(intosc),
		.clkout([[selfclock]]),
		.ce(1'b1)
	);
