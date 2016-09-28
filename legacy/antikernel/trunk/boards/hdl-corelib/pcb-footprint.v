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
	@brief PCB footprint blackboxes
 */

//6-terminal 0.1" pin header, right angle
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "CONN_HEADER_2.54MM_1x6_RA" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module CONN_HEADER_2p54MM_1x6_RA(p1, p2, p3, p4, p5, p6);
	
	inout wire p1;
	inout wire p2;
	inout wire p3;
	inout wire p4;
	inout wire p5;
	inout wire p6;
	
endmodule

//8-pin DIP IC
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "DIP_8_2.54MM_7.62MM" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module DIP_8(p1, p2, p3, p4, p5, p6, p7, p8);
	
	inout wire p1;
	inout wire p2;
	inout wire p3;
	inout wire p4;
	inout wire p5;
	inout wire p6;
	inout wire p7;
	inout wire p8;

endmodule

//2-terminal SMT resistor in EIA 0402 case size
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "EIA_0402_RES_NOSILK" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module EIA_0402_RES_NOSILK(p1, p2);
	
	inout wire p1;
	inout wire p2;
	
endmodule

//2-terminal SMT capacitor in EIA 0402 case size
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "EIA_0402_CAP_NOSILK" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module EIA_0402_CAP_NOSILK(p1, p2);
	
	inout wire p1;
	inout wire p2;
	
endmodule

//2-terminal SMT inductor in EIA 0603 case size
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "EIA_0603_INDUCTOR_NOSILK" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module EIA_0603_INDUCTOR_NOSILK(p1, p2);
	
	inout wire p1;
	inout wire p2;
		
endmodule

//2-terminal SMT LED in EIA 0603 case size
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "EIA_0603_LED" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module EIA_0603_LED(p1, p2);
	
	inout wire p1;
	inout wire p2;
		
endmodule

//2-terminal SMT capacitor in EIA 0805 case size
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "EIA_0805_CAP_NOSILK" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module EIA_0805_CAP_NOSILK(p1, p2);
	
	inout wire p1;
	inout wire p2;
		
endmodule

//2-terminal SMT capacitor in EIA 1206 case size
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "EIA_1206_CAP_NOSILK" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module EIA_1206_CAP_NOSILK(p1, p2);
	
	inout wire p1;
	inout wire p2;
	
endmodule

//2-terminal SMT capacitor in EIA 1210 case size
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "EIA_1210_CAP_NOSILK" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module EIA_1210_CAP_NOSILK(p1, p2);
	
	inout wire p1;
	inout wire p2;
	
endmodule

//Hirose mini-USB connector
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "CONN_HIROSE_UX60S-MB-5ST_MINI_USB" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module HIROSE_UX60S_MB_5ST(p1, p2, p3, p4, p5, p6, p7);
	
	inout wire p1;
	inout wire p2;
	inout wire p3;
	inout wire p4;
	inout wire p5;
	inout wire p6;
	inout wire p7;

endmodule

//TDK SPM6530T series SMT inductors
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "INDUCTOR_TDK_SPM6530" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module INDUCTOR_TDK_SPM6530(p1, p2);
	
	inout wire p1;
	inout wire p2;

endmodule

//Taiyo Yuden NR6028 series SMT inductors
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "INDUCTOR_YUDEN_NR6028" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module INDUCTOR_YUDEN_NR6028(p1, p2);
	
	inout wire p1;
	inout wire p2;

endmodule

//38-pin QFN used by Linear Technology LTC3374 among others
(* keep *)
(* KICAD_LIBRARY = "azonenberg_pcb" *)
(* KICAD_MODULE_NAME = "QFN_38_0.5MM_5x7MM" *)
(* KICAD_PIN_NAMING = "NORMAL" *)
module QFN_38_0p5MM_5x7MM(
	p1, p2, p3, p4, p5, p6, p7, p8, p9, p10,
	p11, p12, p13, p14, p15, p16, p17, p18, p19, p20,
	p21, p22, p23, p24, p25, p26, p27, p28, p29, p30,
	p31, p32, p33, p34, p35, p36, p37, p38,
	PAD
	);
	
	inout wire p1;
	inout wire p2;
	inout wire p3;
	inout wire p4;
	inout wire p5;
	inout wire p6;
	inout wire p7;
	inout wire p8;
	inout wire p9;
	inout wire p10;
	inout wire p11;
	inout wire p12;
	inout wire p13;
	inout wire p14;
	inout wire p15;
	inout wire p16;
	inout wire p17;
	inout wire p18;
	inout wire p19;
	inout wire p20;
	inout wire p21;
	inout wire p22;
	inout wire p23;
	inout wire p24;
	inout wire p25;
	inout wire p26;
	inout wire p27;
	inout wire p28;
	inout wire p29;
	inout wire p30;
	inout wire p31;
	inout wire p32;
	inout wire p33;
	inout wire p34;
	inout wire p35;
	inout wire p36;
	inout wire p37;
	inout wire p38;
	inout wire PAD;
	
endmodule
