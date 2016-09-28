	//Unused router ports
	wire		rpc_[[router_name]]_unused_tx_en[4:0];
	wire[31:0]	rpc_[[router_name]]_unused_tx_data[4:0];
	wire[1:0]	rpc_[[router_name]]_unused_rx_ack[4:0];
	
	RPCv2Router #
	(
		.PORT_DISABLE( {1'b0, 1'b[[rpc_p3_disable]], 1'b[[rpc_p2_disable]], 1'b[[rpc_p1_disable]], 1'b[[rpc_p0_disable]]} ),
	
		//Router-level settings
		.SUBNET_MASK(16'h[[subnet_mask]]),
		.SUBNET_ADDR(16'h[[base_addr]]),
		.HOST_BIT_HIGH([[host_bit_high]])
	)
	rpc_[[router_name]] (
	
		.clk(clk_noc),
		
		//Vector ports for easier scaling to different router widths
		.port_rx_en({[[p4_rx_en]], [[p3_rx_en]], [[p2_rx_en]], [[p1_rx_en]], [[p0_rx_en]]}),
		.port_rx_data({[[p4_rx_data]], [[p3_rx_data]], [[p2_rx_data]], [[p1_rx_data]], [[p0_rx_data]]}),
		.port_rx_ack({[[p4_rx_ack]], [[p3_rx_ack]], [[p2_rx_ack]], [[p1_rx_ack]], [[p0_rx_ack]]}),
		
		.port_tx_en({[[p4_tx_en]], [[p3_tx_en]], [[p2_tx_en]], [[p1_tx_en]], [[p0_tx_en]]}),
		.port_tx_data({[[p4_tx_data]], [[p3_tx_data]], [[p2_tx_data]], [[p1_tx_data]], [[p0_tx_data]]}),
		.port_tx_ack({[[p4_tx_ack]], [[p3_tx_ack]], [[p2_tx_ack]], [[p1_tx_ack]], [[p0_tx_ack]]})
	);
	
