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
	@brief Pipeline forwarding logic for GRAFTON
 */
module GraftonCPUPipelineForwarding(
	execute_regval, execute_regid,
	mem_regwrite, mem_regid_d, mem_regval,
	writeback_regwrite, writeback_regid_d, writeback_regval,
	post_wb_regid, post_wb_regval,
	
	execute_regval_fwd
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Input from register file
	input wire[31:0] execute_regval;
	input wire[4:0] execute_regid;
	
	//Inputs from mem stage
	input wire mem_regwrite;
	input wire[4:0] mem_regid_d;
	input wire[31:0] mem_regval;
	
	//Inputs from writeback stage
	input wire writeback_regwrite;
	input wire[4:0] writeback_regid_d;
	input wire[31:0] writeback_regval;
	
	//Inputs from post-writeback state
	input wire[4:0] post_wb_regid;
	input wire[31:0] post_wb_regval;
	
	//Output to execute stage
	output reg[31:0] execute_regval_fwd = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Forwarding logic
	
	always @(*) begin
		execute_regval_fwd <= execute_regval;
		
		//$zero is always zero
		if(execute_regid == 0)
			execute_regval_fwd <= 0;
		
		//Forward mem stage to execute stage
		else if(mem_regwrite && (mem_regid_d == execute_regid))
			execute_regval_fwd <= mem_regval;
			
		//Forward writeback stage to execute stage
		else if(writeback_regwrite && (writeback_regid_d == execute_regid))
			execute_regval_fwd <= writeback_regval;
			
		//Forward post-writeback stage to execute stage
		else if(post_wb_regid == execute_regid)
			execute_regval_fwd <= post_wb_regval;
		
	end
	
endmodule
