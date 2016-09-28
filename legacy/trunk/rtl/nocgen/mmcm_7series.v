[[inbuf]]
	wire pll_locked_[[instance_name]];
	wire clk_feedback_[[instance_name]];
[[clock_nets]]

	MMCME2_BASE #(
		.CLKIN1_PERIOD([[input_period]]),    		//input frequency [[input_freq]] MHz
		.DIVCLK_DIVIDE([[pfd_div]]),			//PFD frequency [[pfd_freq]] MHz
		.CLKFBOUT_MULT_F([[vco_mult]]),  		//VCO frequency [[vco_freq]] MHz
		.CLKFBOUT_PHASE(0.0),
		
		.CLKOUT0_DIVIDE_F([[output_divisor_0]]),			//[[output_freq_text_0]]
		.CLKOUT1_DIVIDE([[output_divisor_1]]),			//[[output_freq_text_1]]
		.CLKOUT2_DIVIDE([[output_divisor_2]]),			//[[output_freq_text_2]]
		.CLKOUT3_DIVIDE([[output_divisor_3]]),			//[[output_freq_text_3]]
		.CLKOUT4_DIVIDE([[output_divisor_4]]),			//[[output_freq_text_4]]
		.CLKOUT5_DIVIDE([[output_divisor_5]]),			//[[output_freq_text_5]]
		.CLKOUT6_DIVIDE(1),								//output #6 not implemented in nocgen yet
														//for spartan-6 backward compatibility
		
		.CLKOUT0_DUTY_CYCLE([[output_duty_0]]),
		.CLKOUT1_DUTY_CYCLE([[output_duty_1]]),
		.CLKOUT2_DUTY_CYCLE([[output_duty_2]]),
		.CLKOUT3_DUTY_CYCLE([[output_duty_3]]),
		.CLKOUT4_DUTY_CYCLE([[output_duty_4]]),
		.CLKOUT5_DUTY_CYCLE([[output_duty_5]]),
		.CLKOUT6_DUTY_CYCLE(0.5),						//output #6 not implemented in nocgen yet
														//for spartan-6 backward compatibility
														
		.CLKOUT0_PHASE([[output_phase_0]]),
		.CLKOUT1_PHASE([[output_phase_1]]),
		.CLKOUT2_PHASE([[output_phase_2]]),
		.CLKOUT3_PHASE([[output_phase_3]]),
		.CLKOUT4_PHASE([[output_phase_4]]),
		.CLKOUT5_PHASE([[output_phase_5]]),
		.CLKOUT6_PHASE(0.0),							//output #6 not implemented in nocgen yet
														//for spartan-6 backward compatibility
		
		.BANDWIDTH("OPTIMIZED"),
		.REF_JITTER1(0.1),
		.STARTUP_WAIT("FALSE"),
		
		.CLKOUT4_CASCADE("FALSE")						//counter cascade not implemented in nocgen yet
	)
	[[instance_name]]
	(
		.CLKFBOUT(clk_feedback_[[instance_name]]),
		.CLKFBOUTB(),									//feedback clock not used
		.CLKFBIN(clk_feedback_[[instance_name]]),
		.CLKOUT0([[output_net_raw_0]]),
		.CLKOUT0B(),									//inverted clocks not implemented in nocgen yet
		.CLKOUT1([[output_net_raw_1]]),
		.CLKOUT1B(),									//inverted clocks not implemented in nocgen yet
		.CLKOUT2([[output_net_raw_2]]),
		.CLKOUT2B(),									//inverted clocks not implemented in nocgen yet
		.CLKOUT3([[output_net_raw_3]]),
		.CLKOUT3B(),									//inverted clocks not implemented in nocgen yet
		.CLKOUT4([[output_net_raw_4]]),
		.CLKOUT5([[output_net_raw_5]]),
		.CLKOUT6(),
		.LOCKED(pll_locked_[[instance_name]]),
		.CLKIN1([[input_net]]),
		.PWRDWN(1'b0),
		.RST(1'b0)
	);

[[bufgs]]
