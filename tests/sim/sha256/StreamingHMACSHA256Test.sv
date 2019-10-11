`timescale 1ns / 1ps
/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2019 Andrew D. Zonenberg                                                                          *
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

module StreamingHMACSHA256Test();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock synthesis

	logic		clk = 0;

	always begin
		#5;
		clk = 0;
		#5;
		clk = 1;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	logic			start 		= 0;
	logic			update 		= 0;
	logic[31:0]		data_in		= 0;
	logic[2:0]		bytes_valid	= 0;
	logic			finalize	= 0;

	logic			key_update	= 0;
	logic[511:0]	key			= 0;

	wire			hash_valid;
	wire[255:0]		hash;

	wire			ready;

	StreamingHMACSHA256 dut(
		.clk(clk),
		.key(key),
		.key_update(key_update),
		.start(start),
		.ready(ready),
		.update(update),
		.data_in(data_in),
		.bytes_valid(bytes_valid),
		.finalize(finalize),
		.hash_valid(hash_valid),
		.hash(hash)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test inputs

	logic[7:0] state = 0;
	logic[7:0] count = 0;

	always_ff @(posedge clk) begin

		start		<= 0;
		update		<= 0;
		finalize	<= 0;
		count		<= 0;

		case(state)

			//"Hi There", 20 * 'h0b -> b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7
			//RFC4231 test vector #1
			0: begin
				start		<= 1;
				state		<= 1;

				key_update	<= 1;
				key			<= {160'h0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b, 352'h0};

				$display("RFC 4231 Test Vector #1: ");
			end

			1: begin
				if(ready) begin
					update		<= 1;
					data_in		<= {"Hi T"};
					bytes_valid	<= 4;
					state		<= 2;
				end
			end

			2: begin
				update		<= 1;
				data_in		<= {"here"};
				bytes_valid	<= 4;
				state		<= 3;
			end

			3: begin
				finalize	<= 1;
				state		<= 4;
			end

			4: begin
				if(hash_valid) begin
					if(hash == 256'hb0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7) begin
						$display("PASS");
						state	<= 5;

						//"what do ya want for nothing?", "Jefe" -> 5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843
						//RFC4231 test vector #2
						start		<= 1;
						key_update	<= 1;
						count		<= 0;
						key			<= { "Jefe", 480'h0 };

						$display("RFC 4231 Test Vector #2: ");
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end

			5: begin
				if(ready)
					state	<= 6;
			end

			6: begin
				count		<= count + 1;
				update		<= 1;
				bytes_valid	<= 4;

				case(count)
					0: data_in	<= "what";
					1: data_in <= " do ";
					2: data_in <= "ya w";
					3: data_in <= "ant ";
					4: data_in <= "for ";
					5: data_in <= "noth";
					6: begin
						data_in <= "ing?";
						state	<= 7;
					end
				endcase
			end

			7: begin
				finalize	<= 1;
				state		<= 8;
			end

			8: begin
				if(hash_valid) begin
					if(hash == 256'h5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843) begin
						$display("PASS");
						state	<= 9;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end

		endcase

	end

endmodule
