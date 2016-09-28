	JtagDebugController #(
		.DMA_DISABLE(1)
	) debug_controller (
		.clk_noc(clk_noc), 
		.rpc_tx_en(  root_rpc_rx_en), 
		.rpc_tx_data(root_rpc_rx_data), 
		.rpc_tx_ack( root_rpc_rx_ack), 
		.rpc_rx_en(  root_rpc_tx_en), 
		.rpc_rx_data(root_rpc_tx_data), 
		.rpc_rx_ack( root_rpc_tx_ack), 
		.dma_tx_en(), 
		.dma_tx_data(), 
		.dma_tx_ack( 1'b1), 
		.dma_rx_en(  1'b0), 
		.dma_rx_data(32'h0), 
		.dma_rx_ack( root_dma_tx_ack)
		);
