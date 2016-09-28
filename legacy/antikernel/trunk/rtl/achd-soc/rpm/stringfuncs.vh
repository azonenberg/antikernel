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
	@brief String helper functions
	
	String objects are fixed size byte arrays, padded on the left with 0x00. 
	Too-long values are silently truncated.
 */
localparam DIGITS = "9876543210";

//see http://stackoverflow.com/questions/20481745/verilog-placement-constraints-with-generate-statements
`define THOUSANDS(x) (x / 1000)
`define  HUNDREDS(x) ((x - (`THOUSANDS(x) * 1000)) / 100)
`define      TENS(x) ((x - (`THOUSANDS(x) * 1000) - (`HUNDREDS(x) * 100)) / 10)
`define      ONES(x) (x - (`THOUSANDS(x) * 1000) - (`HUNDREDS(x) * 100) - (`TENS(x) * 10))
`define     TO_STRING(x) (DIGITS[((8 * (x + 1)) - 1) : (8 * x)])
`define VAR_TO_STRING(x) ({`TO_STRING(`THOUSANDS(x)), `TO_STRING(`HUNDREDS(x)), `TO_STRING(`TENS(x)), `TO_STRING(`ONES(x))})
