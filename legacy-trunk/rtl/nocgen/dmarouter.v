
	wire		dma_[[router_name]]_unused_tx_en[4:0];
	wire[31:0]	dma_[[router_name]]_unused_tx_data[4:0];
	wire		dma_[[router_name]]_unused_rx_ack[4:0];
	
	DMARouter #
	(
		.PORT_DISABLE( {1'b0, 1'b[[dma_p3_disable]], 1'b[[dma_p2_disable]], 1'b[[dma_p1_disable]], 1'b[[dma_p0_disable]]} ),
	
		//Router-level settings
		.SUBNET_MASK(16'h[[subnet_mask]]),
		.SUBNET_ADDR(16'h[[base_addr]]),
		.HOST_BIT_HIGH([[host_bit_high]])
		
	)
	dma_[[router_name]] (
		
		.clk(clk_noc),
		
		//Vector ports for easier scaling to different router widths
		.port_rx_en({[[dma_p4_rx_en]], [[dma_p3_rx_en]], [[dma_p2_rx_en]], [[dma_p1_rx_en]], [[dma_p0_rx_en]]}),
		.port_rx_ack({[[dma_p4_rx_ack]], [[dma_p3_rx_ack]], [[dma_p2_rx_ack]], [[dma_p1_rx_ack]], [[dma_p0_rx_ack]]}),
		.port_rx_data({[[dma_p4_rx_data]], [[dma_p3_rx_data]], [[dma_p2_rx_data]], [[dma_p1_rx_data]], [[dma_p0_rx_data]]}),
		
		.port_tx_en({[[dma_p4_tx_en]], [[dma_p3_tx_en]], [[dma_p2_tx_en]], [[dma_p1_tx_en]], [[dma_p0_tx_en]]}),
		.port_tx_data({[[dma_p4_tx_data]], [[dma_p3_tx_data]], [[dma_p2_tx_data]], [[dma_p1_tx_data]], [[dma_p0_tx_data]]}),
		.port_tx_ack({[[dma_p4_tx_ack]], [[dma_p3_tx_ack]], [[dma_p2_tx_ack]], [[dma_p1_tx_ack]], [[dma_p0_tx_ack]]})
	);
