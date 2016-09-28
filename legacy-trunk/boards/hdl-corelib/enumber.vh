`timescale 1ns / 1ps
`default_nettype none
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
	@brief Routines for dealing with E-numbers
 */
 
/**
	@brief Returns the closer of two numbers to a given target value if it is between them.
	
	Otherwise the input is returned unchanged.
 */
function [63:0] choose_between;
	input[63:0] value;
	input[63:0] a;
	input[63:0] b;
	
	begin
		
		if(value < a)
			choose_between = value;
		else if(value > b)
			choose_between = value;
		else if( (value - a) < (b - value) )
			choose_between = a;
		else
			choose_between = b;
		
	end
	
endfunction

/**
	@brief Returns the Nth E96 number
 */
function integer get_e96;
	input integer n;
	begin
		case(n)
			0:			get_e96 = 100;
			1:			get_e96 = 102;
			2:			get_e96 = 105;
			3:			get_e96 = 107;
			4:			get_e96 = 110;
			5:			get_e96 = 113;
			6:			get_e96 = 115;
			7:			get_e96 = 118;
			8:			get_e96 = 121;
			9:			get_e96 = 124;
		
			10:			get_e96 = 127;
			11:			get_e96 = 130;
			12:			get_e96 = 133;
			13:			get_e96 = 137;
			14:			get_e96 = 140;
			15:			get_e96 = 143;
			16:			get_e96 = 147;
			17:			get_e96 = 150;
			18:			get_e96 = 154;
			19:			get_e96 = 158;
		
			20:			get_e96 = 162;
			21:			get_e96 = 165;
			22:			get_e96 = 169;
			23:			get_e96 = 174;
			24:			get_e96 = 178;
			25:			get_e96 = 182;
			26:			get_e96 = 187;
			27:			get_e96 = 191;
			28:			get_e96 = 196;
			29:			get_e96 = 200;
		
			30:			get_e96 = 205;
			31:			get_e96 = 210;
			32:			get_e96 = 215;
			33:			get_e96 = 221;
			34:			get_e96 = 226;
			35:			get_e96 = 232;
			36:			get_e96 = 237;
			37:			get_e96 = 243;
			38:			get_e96 = 249;
			39:			get_e96 = 255;
			
			40:			get_e96 = 261;
			41:			get_e96 = 267;
			42:			get_e96 = 274;
			43:			get_e96 = 280;
			44:			get_e96 = 287;
			45:			get_e96 = 294;
			46:			get_e96 = 301;
			47:			get_e96 = 309;
			48:			get_e96 = 316;
			49:			get_e96 = 324;
			
			50:			get_e96 = 332;
			51:			get_e96 = 340;
			52:			get_e96 = 348;
			53:			get_e96 = 357;
			54:			get_e96 = 365;
			55:			get_e96 = 374;
			56:			get_e96 = 383;
			57:			get_e96 = 392;
			58:			get_e96 = 402;
			59:			get_e96 = 412;
			
			60:			get_e96 = 422;
			61:			get_e96 = 432;
			62:			get_e96 = 442;
			63:			get_e96 = 453;
			64:			get_e96 = 464;
			65:			get_e96 = 475;
			66:			get_e96 = 487;
			67:			get_e96 = 499;
			68:			get_e96 = 511;
			69:			get_e96 = 523;
			
			70:			get_e96 = 536;
			71:			get_e96 = 549;
			72:			get_e96 = 562;
			73:			get_e96 = 576;
			74:			get_e96 = 590;
			75:			get_e96 = 604;
			76:			get_e96 = 619;
			77:			get_e96 = 634;
			78:			get_e96 = 649;
			79:			get_e96 = 665;
			
			80:			get_e96 = 681;
			81:			get_e96 = 698;
			82:			get_e96 = 715;
			83:			get_e96 = 732;
			84:			get_e96 = 750;
			85:			get_e96 = 768;
			86:			get_e96 = 787;
			87:			get_e96 = 806;
			88:			get_e96 = 825;
			89:			get_e96 = 845;
			
			90:			get_e96 = 866;
			91:			get_e96 = 887;
			92:			get_e96 = 909;
			93:			get_e96 = 931;
			94:			get_e96 = 951;
			95:			get_e96 = 976;
			
			default:	get_e96 = 0;
		endcase
	end	
endfunction

/**
	@brief Returns the Nth E24 number scaled from 100 to 1000
 */
function integer get_e24;
	input integer n;
	begin
		case(n)
			0:			get_e24 = 100;
			1:			get_e24 = 110;
			2:			get_e24 = 120;
			3:			get_e24 = 130;
			4:			get_e24 = 150;
			5:			get_e24 = 160;
			6:			get_e24 = 180;
			7:			get_e24 = 200;
			8:			get_e24 = 220;
			9:			get_e24 = 240;
		
			10:			get_e24 = 270;
			11:			get_e24 = 300;
			12:			get_e24 = 330;
			13:			get_e24 = 360;
			14:			get_e24 = 390;
			15:			get_e24 = 430;
			16:			get_e24 = 470;
			17:			get_e24 = 510;
			18:			get_e24 = 560;
			19:			get_e24 = 620;
		
			20:			get_e24 = 680;
			21:			get_e24 = 750;
			22:			get_e24 = 820;
			23:			get_e24 = 910;
			
			default:	get_e24 = 0;
		endcase
	end	
endfunction

/**
	@brief Returns the Nth E12 number scaled from 100 to 1000
 */
function integer get_e12;
	input integer n;
	begin
		case(n)
			0:			get_e12 = 100;
			1:			get_e12 = 120;
			2:			get_e12 = 150;
			3:			get_e12 = 180;
			4:			get_e12 = 220;
			5:			get_e12 = 270;
			6:			get_e12 = 330;
			7:			get_e12 = 390;
			8:			get_e12 = 470;
			9:			get_e12 = 560;
		
			10:			get_e12 = 680;
			11:			get_e12 = 820;
			
			default:	get_e12 = 0;
		endcase
	end	
endfunction
 
/**
	@brief Find the nearest E-value for a given target value
 */
function [63:0] choose_evalue;

	input[63:0]	value;
	
	input[7:0] tolerance;	//in percent, legal values are 1/5/10
	
	integer decimal_shift;
	integer i;

	begin
		
		//Early out if input is zero
		if(value == 0)
			choose_evalue = 0;
		
		else begin
			
			//Normalize the value to [100, 1000] saving the original exponent
			decimal_shift = 0;
			while(value >= 1000) begin
				value = value / 10;
				decimal_shift = decimal_shift + 1;
			end
			while(value < 100) begin
				value = value * 10;
				decimal_shift = decimal_shift - 1;
			end
			
			//Go through the E-value tables and pick the closest entry
			choose_evalue = value;
			case(tolerance)
				
				10: begin
					for(i=0; i<11; i=i+1)
						choose_evalue = choose_between(choose_evalue, get_e12(i), get_e12(i+1));
				end
				
				5: begin
					for(i=0; i<23; i=i+1)
						choose_evalue = choose_between(choose_evalue, get_e24(i), get_e24(i+1));
				end
				
				//default to 1% tolerance
				default: begin
					for(i=0; i<95; i=i+1)
						choose_evalue = choose_between(choose_evalue, get_e96(i), get_e96(i+1));
				end
				
			endcase
				
			//Apply the saved exponent
			while(decimal_shift < 0) begin
				choose_evalue = choose_evalue / 10;
				decimal_shift = decimal_shift + 1;
			end
			while(decimal_shift > 0) begin
				choose_evalue = choose_evalue * 10;
				decimal_shift = decimal_shift - 1;
			end
			
		end
		
	end

endfunction
