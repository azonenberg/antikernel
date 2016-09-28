`timescale 1ns / 1ps
/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2016 Andrew D. Zonenberg                                                                          *
* All rights reserved.                                                                                                 *
*                                                                                                                      *
* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the     *
* following conditions are met:                                                                                        *
*                                                                                                                      *
*    * Redistributions of source code must retain the above copyright notice, this list of conditions, and the         *
*      following disclaimer.                                                                                           *
*                                                                                                                      *
*    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the       *
*      following disclaimer in the documentation and/or other materials provided with the distribution.                *
*                                                                                                                      *
*    * Neither the name of the author nor the names of any contributors may be used to endorse or promote products     *
*      derived from this software without specific prior written permission.                                           *
*                                                                                                                      *
* THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   *
* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL *
* THE AUTHORS BE HELD LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES        *
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR       *
* BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE       *
* POSSIBILITY OF SUCH DAMAGE.                                                                                          *
*                                                                                                                      *
***********************************************************************************************************************/

/**
	@file
	@author Andrew D. Zonenberg
	@brief Test vectors for the cache bank
 */
module testSaratogaCPUL1CacheBank;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock oscillator
	
	reg clk = 0;

	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	
	always begin
		#5;
		clk = 0;
		#5;
		clk = ready;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT
	
	reg[4:0] 	c0_tid		= 0;
	reg[4:0]	c1_tid		= 0;
	reg[4:0] 	c2_tid		= 0;

	reg			c0_rd		= 0;
	reg[31:0]	c0_addr		= 0;
	reg			c0_wr		= 0;
	reg[3:0]	c0_wmask	= 0;
	reg[31:0]	c0_din		= 0;

	wire[1:0] 	c2_hit;
	wire[63:0]	c2_dout;
	
	wire		miss_rd;
	wire[4:0]	miss_tid;
	wire[31:0]	miss_addr;
	
	reg			push_wr		= 0;
	reg[4:0]	push_tid	= 0;
	reg[31:0]	push_addr	= 0;
	reg[63:0]	push_data	= 0;
	
	wire		flush_en;
	wire[4:0]	flush_tid;
	wire[31:0]	flush_addr;
	wire[63:0]	flush_dout;

	SaratogaCPUL1CacheBank uut(
		.clk(clk),
		
		.c0_tid(c0_tid),
		.c0_rd(c0_rd),
		.c0_addr(c0_addr),
		.c0_wr(c0_wr),
		.c0_wmask(c0_wmask),
		.c0_din(c0_din),
		.c1_tid(c1_tid),
		.c2_tid(c2_tid),
		.c2_dout(c2_dout),
		.c2_hit(c2_hit),
	
		.miss_rd(miss_rd),
		.miss_tid(miss_tid),
		.miss_addr(miss_addr),
		
		.push_wr(push_wr),
		.push_tid(push_tid),
		.push_addr(push_addr),
		.push_data(push_data),
		
		.flush_en(flush_en),
		.flush_tid(flush_tid),
		.flush_addr(flush_addr),
		.flush_dout(flush_dout)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push flags down the pipe
	
	always @(posedge clk) begin
		c1_tid <= c0_tid;
		c2_tid <= c1_tid;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Miss handling code
	
	reg			miss_rd_buf			= 0;
	reg			miss_rd_buf2		= 0;
	reg			miss_rd_buf3		= 0;
	reg			miss_active_buf		= 0;
	reg			miss_active_buf2	= 0;
	reg			miss_active_buf3	= 0;
	reg			push_wr_buf			= 0;
	reg			push_wr_buf2		= 0;
	reg			push_wr_buf3		= 0;
	
	always @(posedge clk) begin
		miss_rd_buf			<= miss_rd;
		miss_rd_buf2		<= miss_rd_buf;
		miss_rd_buf3		<= miss_rd_buf2;
		
		miss_active_buf		<= miss_active;
		miss_active_buf2	<= miss_active_buf;
		miss_active_buf3	<= miss_active_buf2;
		
		push_wr_buf			<= push_wr;
		push_wr_buf2		<= push_wr_buf;
		push_wr_buf3		<= push_wr_buf2;
	end
	
	/*
		In the real system, we'll need a WORDS_PER_LINE entry FIFO for each thread context
		for storing incoming DMA messages. This will let us stream multiple incoming messages to the cache, interleaved.
		For now, just send one word whenever it's our turn
	 */
	 
	reg			miss_active		= 0;
	reg[1:0]	miss_count		= 0;
	reg[4:0]	saved_miss_tid	= 0;
	reg[31:0]	saved_miss_addr	= 0;
	
	//Debug marker for sim view
	reg			our_thread		= 0;
	always @(*) begin
		our_thread				<= (c0_tid == 3);
	end
	
	//Calculate the address we're reading from
	reg[31:0] pending_addr		= 0;
	always @(*) begin
		pending_addr			<= saved_miss_addr + {miss_count, 3'b00};
	end
	
	always @(posedge clk) begin
	
		push_addr		<= 0;
		push_wr			<= 0;
		push_tid		<= 0;
		push_data		<= 0;
	
		//Go into miss-handling mode
		if(miss_rd) begin

			miss_active			<= 1;
			miss_count			<= 0;
			saved_miss_tid		<= miss_tid;
			saved_miss_addr		<= miss_addr;
		end
			
		//If we're processing a miss, and it's our turn, go push it
		if(miss_active && ( (c2_tid + 5'h1) == saved_miss_tid ) ) begin
		
			push_addr			<= pending_addr;
			push_tid			<= saved_miss_tid;
			push_wr				<= 1;
			miss_count			<= miss_count + 2'h1;
			
			if(miss_count == 3)
				miss_active		<= 0;
			
			case(pending_addr)
			
				32'hbfc00000:	push_data	<= 64'hfeedfacebaadf00d;
				32'hbfc00008:	push_data	<= 64'hc0dec0decdcdcdcd;
				32'hbfc00010:	push_data	<= 64'ha3a3a3a3cccccccc;
				32'hbfc00018:	push_data	<= 64'heeeeeeeedddddddd;
				
				32'hcfc00000:	push_data	<= 64'h1111111122222222;
				32'hcfc00008:	push_data	<= 64'h3333333344444444;
				32'hcfc00010:	push_data	<= 64'h5555555566666666;
				32'hcfc00018:	push_data	<= 64'h7777777788888888;
			
				32'hdfc00000:	push_data	<= 64'hcccccccccccccccc;
				32'hdfc00008:	push_data	<= 64'hcccccccccccccccc;
				32'hdfc00010:	push_data	<= 64'hcccccccccccccccc;
				32'hdfc00018:	push_data	<= 64'hcccccccccccccccc;
			
			endcase
		
		end
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test driver code
	
	reg[7:0]	count = 0;	
	
	always @(posedge clk) begin
		
		//Barrel, swap every cycle	
		//Run 8 simulated threads to keep the sim shorter
		c0_tid		<= c0_tid + 5'h1;
		c0_tid[4:3]	<= 0;
		
		c0_rd		<= 0;
		c0_addr		<= 0;
		c0_wr		<= 0;
		c0_din		<= 0;
		c0_wmask	<= 0;
	
		case(count)
		
			//Dispatch a read request
			0: begin
				if(c0_tid == 2) begin
					$display("Issuing read to base address");
					c0_rd		<= 1;
					c0_addr		<= 32'hbfc00000;
					count		<= 1;
				end
			end
			
			//Wait for the result
			1: 		count 		<= 2;
			2: 		count 		<= 3;
			
			//Keep on trying to read until we get a hit
			3: begin

				if(miss_rd)
					$display("Got a miss");
				
				if(c2_hit == 2'b11) begin
					//Sanity check it
					if(c2_dout == 64'hfeedfacebaadf00d)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					
					count		<= 4;
				end
				
				//Even if no miss was alerted, go back to start and read again
				//We will only declare a miss the first time
				else
					count			<= 0;
				
			end
			
			4: begin
				if(c0_tid == 2) begin
					//Issue a read to an odd word address
					//Should return baadf00d c0dec0de
					$display("Trying an odd read");
					c0_rd		<= 1;
					c0_addr		<= 32'hbfc00004;
					count		<= 5;
				end
			end
			
			5: begin
				if(c2_hit == 3) begin
					
					//Sanity check it
					if(c2_dout == 64'hbaadf00dc0dec0de)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					count	<= 6;

				end
			end

			6: begin
				if(c0_tid == 2) begin
					//Issue a read to the 				second-to-last address
					//Should return eeeeeeee dddddddd
					$display("Trying an even read");
					c0_rd		<= 1;
					c0_addr		<= 32'hbfc00018;
					count		<= 7;
				end
			end
			
			7: begin
				if(c2_hit == 3) begin
					
					//Sanity check it
					if(c2_dout == 64'heeeeeeeedddddddd)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					
					count		<= 8;
				end
			end
			
			8: begin
				if(c0_tid == 2) begin
					//Issue a read to the last address
					//Should return dddddddd [miss]
					$display("Reading last address");
					c0_rd		<= 1;
					c0_addr		<= 32'hbfc0001c;
					count		<= 9;
				end
			end
			
			9: begin
				if(c2_hit == 2) begin
					
					//Sanity check it
					if(c2_dout == 64'hdddddddd00000000)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					
					count		<= 10;
				end
			end
			
			10: begin
				if(c0_tid == 2) begin
					//Fetch an address that collides with the first address, but isn't the same
					c0_rd		<= 1;
					c0_addr		<= 32'hcfc00000;			
					count		<= 11;
				end
			end
			
			//Wait for the result
			11: 	count 		<= 12;
			12: 	count 		<= 13;
			
			//Keep on trying to read until we get a hit
			13: begin

				if(miss_rd)
					$display("Got a miss");
				
				if(c2_hit == 2'b11) begin
					//Sanity check it
					if(c2_dout == 64'h1111111122222222)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					
					count		<= 14;
				end
				
				//Even if no miss was alerted, go back to start and read again
				//We will only declare a miss the first time
				else
					count			<= 10;
				
			end
			
			//Read the old value and make sure that's a hit
			14: begin
				if(c0_tid == 2) begin
					c0_rd		<= 1;
					c0_addr		<= 32'hbfc00000;
					count		<= 15;
				end
			end
	
			//This should be a hit
			15: begin
				if(c2_hit == 3) begin
					
					//Sanity check it
					if(c2_dout == 64'hfeedfacebaadf00d)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					
					count		<= 16;
					
				end
			end
			
			//Try doing a write to the old cache line
			//This should succeed without flushing since it's resident
			16: begin
				if(c0_tid == 2) begin
					$display("Doing a write");
					c0_wr		<= 1;
					c0_wmask	<= 4'b1111;
					c0_addr		<= 32'hbfc00000;
					c0_din		<= 32'h12345678;
					count		<= 17;
				end
			end
			
			//Wait for write to complete
			17: begin
				if(c2_hit != 0) begin
					$display("Good write");
					count		<= 18;
				end
			end
			
			//Try to read it back and make sure it was OK
			18: begin
				if(c0_tid == 2) begin
					$display("Reading back the written data");
					c0_rd		<= 1;
					c0_addr		<= 32'hbfc00000;
					count		<= 19;
				end
			end
	
			//This should be a hit
			19: begin
				if(c2_hit == 3) begin
					
					//Sanity check it
					if(c2_dout == 64'h12345678baadf00d)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					
					count		<= 20;
					
				end
			end
			
			//Try doing a write to the old cache line
			//This should succeed without flushing since it's resident
			20: begin
				if(c0_tid == 2) begin
					$display("Doing another write");
					c0_wr		<= 1;
					c0_wmask	<= 4'b1111;
					c0_addr		<= 32'hbfc00004;
					c0_din		<= 32'hdeaddead;
					count		<= 21;
				end
			end
			
			//Wait for write to complete
			21: begin
				if(c2_hit != 0) begin
					$display("Good write");
					count		<= 22;
				end
			end
			
			//Try to read it back and make sure it was OK
			22: begin
				if(c0_tid == 2) begin
					$display("Reading back the written data");
					c0_rd		<= 1;
					c0_addr		<= 32'hbfc00000;
					count		<= 23;
				end
			end
	
			//This should be a hit
			23: begin
				if(c2_hit == 3) begin
					
					//Sanity check it
					if(c2_dout == 64'h12345678deaddead)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					
					count		<= 24;
					
				end
			end
			
			//Do a read of yet another address, to flush the dirty cache line
			//Read the old value and make sure that's a hit
			24: begin
				if(c0_tid == 2) begin
					$display("Doing read to flush dirty cache line");
					c0_rd		<= 1;
					c0_addr		<= 32'hdfc00000;
					count		<= 25;
				end
				
				if((c2_tid == 6) && flush_en) begin
					$display("Flushing dirty word (%x, %x)", flush_addr, flush_dout);
					
					//First word has full address
					//The rest only have LSBs
					case(flush_addr)
						
						32'hbfc00000: begin
							if(flush_dout != 64'h12345678deaddead) begin
								$display("FAIL: Bad data");
								$finish;
							end
						end
						
						32'h8: begin
							if(flush_dout != 64'hc0dec0decdcdcdcd) begin
								$display("FAIL: Bad data");
								$finish;
							end
						end
						
						32'h10: begin
							if(flush_dout != 64'ha3a3a3a3cccccccc) begin
								$display("FAIL: Bad data");
								$finish;
							end
						end
						
						32'h18: begin
							if(flush_dout != 64'heeeeeeeedddddddd) begin
								$display("FAIL: Bad data");
								$finish;
							end
						end
						
						default: begin
							$display("Invalid flush address");
							$finish;
						end
					endcase
					
				end
				
				if( (c2_tid == 6) && (miss_active_buf3 || push_wr_buf3) && !flush_en) begin
					$display("FAIL: Should have gotten a flush, but didn't");
					$finish;
				end

			end
			
			//Wait for the result
			25: count 		<= 26;
			26: count 		<= 27;
			
			//Keep on trying to read until we get a hit
			27: begin

				if(miss_rd)
					$display("Got a miss");
				
				if(c2_hit == 2'b11) begin
					//Sanity check it
					if(c2_dout == 64'hcccccccccccccccc)
						$display("Good read");
					else begin
						$display("FAIL: Bad read data %x", c2_dout);
						$finish;
					end
					
					count		<= 28;
				end
				
				//Even if no miss was alerted, go back to start and read again
				//We will only declare a miss the first time
				else
					count			<= 24;
				
			end
			
			//TODO: More testing!
			28: begin
				$display("PASS: Test completed without error");
				$finish;
			end
		
		endcase

	end
	
	initial begin
		#3000;
		$display("FAIL: Test timed out");
		$finish;
	end
      
endmodule

