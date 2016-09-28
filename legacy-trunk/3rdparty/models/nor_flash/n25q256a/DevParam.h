//-MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON-
//-MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON-
//-MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON-
//-MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON-
//
//  Verilog Behavioral Model
//  Version 1.1
//
//  Copyright (c) 2013 Micron Inc.
//
//-MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON-
//-MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON-
//-MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON--MICRON-
//
// This file and all files delivered herewith are Micron Confidential Information.
// 
// 
// Disclaimer of Warranty:
// -----------------------
// This software code and all associated documentation, comments
// or other information (collectively "Software") is provided 
// "AS IS" without warranty of any kind. MICRON TECHNOLOGY, INC. 
// ("MTI") EXPRESSLY DISCLAIMS ALL WARRANTIES EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO, NONINFRINGEMENT OF THIRD PARTY
// RIGHTS, AND ANY IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS
// FOR ANY PARTICULAR PURPOSE. MTI DOES NOT WARRANT THAT THE
// SOFTWARE WILL MEET YOUR REQUIREMENTS, OR THAT THE OPERATION OF
// THE SOFTWARE WILL BE UNINTERRUPTED OR ERROR-FREE. FURTHERMORE,
// MTI DOES NOT MAKE ANY REPRESENTATIONS REGARDING THE USE OR THE
// RESULTS OF THE USE OF THE SOFTWARE IN TERMS OF ITS CORRECTNESS,
// ACCURACY, RELIABILITY, OR OTHERWISE. THE ENTIRE RISK ARISING OUT
// OF USE OR PERFORMANCE OF THE SOFTWARE REMAINS WITH YOU. IN NO
// EVENT SHALL MTI, ITS AFFILIATED COMPANIES OR THEIR SUPPLIERS BE
// LIABLE FOR ANY DIRECT, INDIRECT, CONSEQUENTIAL, INCIDENTAL, OR
// SPECIAL DAMAGES (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS
// OF PROFITS, BUSINESS INTERRUPTION, OR LOSS OF INFORMATION)
// ARISING OUT OF YOUR USE OF OR INABILITY TO USE THE SOFTWARE,
// EVEN IF MTI HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
// Because some jurisdictions prohibit the exclusion or limitation
// of liability for consequential or incidental damages, the above
// limitation may not apply to you.
// 
// Copyright 2013 Micron Technology, Inc. All rights reserved.
//



/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-----------------------------------------------------------
-----------------------------------------------------------
--                                                       --
--           PARAMETERS OF DEVICES                       --
--                                                       --
-----------------------------------------------------------
-----------------------------------------------------------
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


//-----------------------------
//  Customization Parameters
//-----------------------------
`include "UserData.h"
`define timingChecks


//-- Available devices 

//N25Q256A83E
//N25Q256A73E
//N25Q256A33E
//N25Q256A31E
//N25Q256A13E
//N25Q256A11E

//N25Q128A13E

//N25Q32A13E
//N25Q32A11E
//N25W32A13E
//N25W32A11E

//N25Q008A11E

 

//----------------------------
// Model configuration
//----------------------------


parameter dataDim = 8;
parameter dummyDim = 15;

`ifdef N25Q00AA13E
  `define N25Q256A13E
  `define Stack1024Mb
//  `define Stack512Mb
`elsif N25Q00AA33E
  `define N25Q256A33E
  `define Stack1024Mb
  `define Stack512Mb
`elsif N25Q00AA31E
  `define N25Q256A31E
  `define Stack1024Mb
  `define Stack512Mb
`elsif N25Q00AA11E
  `define N25Q256A11E
  `define Stack1024Mb
//  `define Stack512Mb
`elsif N25Q512A13E
  `define N25Q256A13E
  `define Stack512Mb
`elsif N25Q512A33E
  `define N25Q256A33E
  `define Stack512Mb
`elsif N25Q512A31E
  `define N25Q256A31E
  `define Stack512Mb
`elsif N25Q512A11E
  `define N25Q256A11E
  `define Stack512Mb
`endif


`ifdef MT25QL512ABA8E0

    parameter [15*8:1] devName = "MT25QL512ABA8E0";
    `define MEDITERANEO

    parameter addrDim = 26; 
    parameter sectorAddrDim = 10;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h44; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h76; 
    parameter [dataDim-1:0] CFD_1 = 'h98; 
    parameter [dataDim-1:0] CFD_2 = 'hBA; 
    parameter [dataDim-1:0] CFD_3 = 'hDC; 
    parameter [dataDim-1:0] CFD_4 = 'hFE; 
    parameter [dataDim-1:0] CFD_5 = 'h1F; 
    parameter [dataDim-1:0] CFD_6 = 'h32; 
    parameter [dataDim-1:0] CFD_7 = 'h54; 
    parameter [dataDim-1:0] CFD_8 = 'h76; 
    parameter [dataDim-1:0] CFD_9 = 'h98;
    parameter [dataDim-1:0] CFD_10 = 'hBA; 
    parameter [dataDim-1:0] CFD_11 = 'hDC; 
    parameter [dataDim-1:0] CFD_12 = 'hFE; 
    parameter [dataDim-1:0] CFD_13 = 'h10; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define VCC_3V 
    `define RESET_software
    `define Feature_8 
    `define ENRSTQIO
    `define QIEFP_38
    `define PP_4byte
    `define SE_4byte
    `define SSE_4byte
    `define QIFP_4byte
    `define MEDT_4READ4D
    `define MEDT_QIEFP_4byte
    `define MEDT_DYB_4byte
    `define MEDT_GPRR
    `define MEDT_SubSect32K
    `define MEDT_4KBLocking
    `define MEDT_PPB
    `define MEDT_DUMMY_CYCLES
    `define MEDT_PASSWORD
    `define MEDT_ADVANCED_SECTOR
    `define PowDown

    parameter RESET_PIN=0;

`elsif MT25QU512ABA8E0

    parameter [15*8:1] devName = "MT25QU512ABA8E0";
    `define MEDITERANEO

    parameter addrDim = 26; 
    parameter sectorAddrDim = 10;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h44; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h76; 
    parameter [dataDim-1:0] CFD_1 = 'h98; 
    parameter [dataDim-1:0] CFD_2 = 'hBA; 
    parameter [dataDim-1:0] CFD_3 = 'hDC; 
    parameter [dataDim-1:0] CFD_4 = 'hFE; 
    parameter [dataDim-1:0] CFD_5 = 'h1F; 
    parameter [dataDim-1:0] CFD_6 = 'h32; 
    parameter [dataDim-1:0] CFD_7 = 'h54; 
    parameter [dataDim-1:0] CFD_8 = 'h76; 
    parameter [dataDim-1:0] CFD_9 = 'h98;
    parameter [dataDim-1:0] CFD_10 = 'hBA; 
    parameter [dataDim-1:0] CFD_11 = 'hDC; 
    parameter [dataDim-1:0] CFD_12 = 'hFE; 
    parameter [dataDim-1:0] CFD_13 = 'h10; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define VCC_1e8V 
    `define RESET_software
    `define Feature_8 
    `define ENRSTQIO
    `define QIEFP_38
    `define PP_4byte
    `define SE_4byte
    `define SSE_4byte
    `define QIFP_4byte
    `define MEDT_4READ4D
    `define MEDT_QIEFP_4byte
    `define MEDT_DYB_4byte
    `define MEDT_GPRR
    `define MEDT_SubSect32K
    `define MEDT_4KBLocking
    `define MEDT_PPB
    `define MEDT_DUMMY_CYCLES
    `define MEDT_PASSWORD
    `define MEDT_ADVANCED_SECTOR

    parameter RESET_PIN=0;

`elsif MT25QL512ABA1E0

    parameter [15*8:1] devName = "MT25QL512ABA1E0";
    `define MEDITERANEO

    parameter addrDim = 26; 
    parameter sectorAddrDim = 10;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h40; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h76; 
    parameter [dataDim-1:0] CFD_1 = 'h98; 
    parameter [dataDim-1:0] CFD_2 = 'hBA; 
    parameter [dataDim-1:0] CFD_3 = 'hDC; 
    parameter [dataDim-1:0] CFD_4 = 'hFE; 
    parameter [dataDim-1:0] CFD_5 = 'h1F; 
    parameter [dataDim-1:0] CFD_6 = 'h32; 
    parameter [dataDim-1:0] CFD_7 = 'h54; 
    parameter [dataDim-1:0] CFD_8 = 'h76; 
    parameter [dataDim-1:0] CFD_9 = 'h98;
    parameter [dataDim-1:0] CFD_10 = 'hBA; 
    parameter [dataDim-1:0] CFD_11 = 'hDC; 
    parameter [dataDim-1:0] CFD_12 = 'hFE; 
    parameter [dataDim-1:0] CFD_13 = 'h10; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define VCC_3V 
    `define RESET_software
    //`define Feature_8 
    `define ENRSTQIO
    `define QIEFP_38
    `define PP_4byte
    `define SE_4byte
    `define SSE_4byte
    `define QIFP_4byte
    `define MEDT_4READ4D
    `define MEDT_QIEFP_4byte
    `define MEDT_DYB_4byte
    `define MEDT_GPRR
    `define MEDT_SubSect32K
    `define MEDT_4KBLocking
    `define MEDT_PPB
    `define MEDT_DUMMY_CYCLES
    `define MEDT_PASSWORD
    `define MEDT_ADVANCED_SECTOR
    `define PowDown

    parameter RESET_PIN=0;

`elsif MT25QU512ABA1E0

    parameter [15*8:1] devName = "MT25QU512ABA1E0";
    `define MEDITERANEO

    parameter addrDim = 26; 
    parameter sectorAddrDim = 10;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h40; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h76; 
    parameter [dataDim-1:0] CFD_1 = 'h98; 
    parameter [dataDim-1:0] CFD_2 = 'hBA; 
    parameter [dataDim-1:0] CFD_3 = 'hDC; 
    parameter [dataDim-1:0] CFD_4 = 'hFE; 
    parameter [dataDim-1:0] CFD_5 = 'h1F; 
    parameter [dataDim-1:0] CFD_6 = 'h32; 
    parameter [dataDim-1:0] CFD_7 = 'h54; 
    parameter [dataDim-1:0] CFD_8 = 'h76; 
    parameter [dataDim-1:0] CFD_9 = 'h98;
    parameter [dataDim-1:0] CFD_10 = 'hBA; 
    parameter [dataDim-1:0] CFD_11 = 'hDC; 
    parameter [dataDim-1:0] CFD_12 = 'hFE; 
    parameter [dataDim-1:0] CFD_13 = 'h10; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define VCC_1e8V 
    `define RESET_software
    //`define Feature_8 
    `define ENRSTQIO
    `define QIEFP_38
    `define PP_4byte
    `define SE_4byte
    `define SSE_4byte
    `define QIFP_4byte
    `define MEDT_4READ4D
    `define MEDT_QIEFP_4byte
    `define MEDT_DYB_4byte
    `define MEDT_GPRR
    `define MEDT_SubSect32K
    `define MEDT_4KBLocking
    `define MEDT_PPB
    `define MEDT_DUMMY_CYCLES
    `define MEDT_PASSWORD
    `define MEDT_ADVANCED_SECTOR

    parameter RESET_PIN=0;

`elsif N25Q256A83E

    parameter [12*8:1] devName = "N25Q256A83E";

    parameter addrDim = 25; 
    parameter sectorAddrDim = 9;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    `ifdef Stack1024Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h21; 
    `elsif Stack512Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    `else    
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h19; 
    `endif
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h04; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define VCC_3V 
    `define RESET_software
    `define Feature_8 
    `define PP_4byte
    `define SE_4byte
    `define SSE_4byte
    `define QIFP_4byte
    `define ENRSTQIO
    `define QIEFP_38

    parameter RESET_PIN=0;

`elsif N25Q256A73E

    parameter [12*8:1] devName = "N25Q256A73E";

    parameter addrDim = 25; 
    parameter sectorAddrDim = 9;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    `ifdef Stack1024Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h21; 
    `elsif Stack512Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    `else    
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h19; 
    `endif
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define VCC_3V 
    `define RESET_software
    `define start_in_byte_4  //powerup in 4 byte addressing mode
    `define disEN4BYTE       //disable enter 4-byte addressing mode command
    `define disEX4BYTE       //disable exit 4-byte addressing mode command

    parameter RESET_PIN=0;

`elsif N25Q256A33E

    parameter [12*8:1] devName = "N25Q256A33E";

    parameter addrDim = 25; 
    parameter sectorAddrDim = 9;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    `ifdef Stack1024Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h21; 
    `elsif Stack512Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    `else    
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h19; 
    `endif
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h08; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define RESET_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define RESET_software
    `define VCC_3V 

    parameter RESET_PIN=1;

`elsif N25Q256A23E

    parameter [12*8:1] devName = "N25Q256A23E";

    parameter addrDim = 25; 
    parameter sectorAddrDim = 9;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    `ifdef Stack1024Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h21; 
    `elsif Stack512Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    `else    
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h19; 
    `endif
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_basic
    `define byte_4
    `define VCC_3V 
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25Q256A13E

    parameter [12*8:1] devName = "N25Q256A13E";

    parameter addrDim = 25; 
    parameter sectorAddrDim = 9;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    `ifdef Stack1024Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h21; 
    `elsif Stack512Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    `else    
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h19; 
    `endif
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define VCC_3V 
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25Q256A11E

    parameter [12*8:1] devName = "N25Q256A11E";

    parameter addrDim = 25; 
    parameter sectorAddrDim = 9;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    `ifdef Stack1024Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h21; 
    `elsif Stack512Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    `else    
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h19; 
    `endif
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define VCC_1e8V 
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25Q256A31E
    
    parameter [12*8:1] devName = "N25Q256A31E";

    parameter addrDim = 25; 
    parameter sectorAddrDim = 9;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    `ifdef Stack1024Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h21; 
    `elsif Stack512Mb
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h20; 
    `else    
        parameter [dataDim-1:0] MemoryCapacity_ID = 'h19; 
    `endif
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h08; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define RESET_pin
    `define SubSect
    `define XIP_Numonyx
    `define byte_4
    `define RESET_software
    `define PowDown
    `define VCC_1e8V 

    parameter RESET_PIN=1;

`elsif N25Q128A11E

    parameter [12*8:1] devName = "N25Q128A11E";

    parameter addrDim = 24; 
    parameter sectorAddrDim = 8;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h18; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define VCC_1e8V
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25Q128A11B

    parameter [12*8:1] devName = "N25Q128A11B";

    parameter addrDim = 24; 
    parameter sectorAddrDim = 8;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h18; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define VCC_1e8V
    `define RESET_software
    `define bottom

    parameter RESET_PIN=0;
`elsif N25Q128A13E

    parameter [12*8:1] devName = "N25Q128A13E";

    parameter addrDim = 24; 
    parameter sectorAddrDim = 8;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h18; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define VCC_3V 
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25Q128A13B

    parameter [12*8:1] devName = "N25Q128A13B";

    parameter addrDim = 24; 
    parameter sectorAddrDim = 8;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h18; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h13; 
    parameter [dataDim-1:0] CFD_1 = 'h51; 
    parameter [dataDim-1:0] CFD_2 = 'h2c; 
    parameter [dataDim-1:0] CFD_3 = 'h3b; 
    parameter [dataDim-1:0] CFD_4 = 'h01; 
    parameter [dataDim-1:0] CFD_5 = 'h4a; 
    parameter [dataDim-1:0] CFD_6 = 'h89; 
    parameter [dataDim-1:0] CFD_7 = 'haa; 
    parameter [dataDim-1:0] CFD_8 = 'hc4; 
    parameter [dataDim-1:0] CFD_9 = 'he1;
    parameter [dataDim-1:0] CFD_10 = 'h84; 
    parameter [dataDim-1:0] CFD_11 = 'hdd; 
    parameter [dataDim-1:0] CFD_12 = 'hd2; 
    parameter [dataDim-1:0] CFD_13 = 'hed; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define VCC_3V 
    `define RESET_software
    `define bottom

    parameter RESET_PIN=0;

`elsif N25Q064A13E

    parameter [12*8:1] devName = "N25Q064A13E";

    parameter addrDim = 22; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h17; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define VCC_3V

    parameter RESET_PIN=0;

`elsif N25Q064A11E

    parameter [12*8:1] devName = "N25Q064A11E";

    parameter addrDim = 22; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h17; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define PowDown
    `define VCC_1e8V
    `define RESET_software

    parameter RESET_PIN=0;
`elsif N25Q032A13E

    parameter [12*8:1] devName = "N25Q032A13E";

    parameter addrDim = 22; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h16; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define VCC_3V

    parameter RESET_PIN=0;

`elsif N25Q032A11E

    parameter [12*8:1] devName = "N25Q032A11E";

    parameter addrDim = 22; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBA; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h16; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define PowDown
    `define VCC_1e8V
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25W032A13E

    parameter [12*8:1] devName = "N25W032A13E";

    parameter addrDim = 22; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h2C;
    parameter [dataDim-1:0] MemoryType_ID = 'hCB; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h16; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define VCC_3V

    parameter RESET_PIN=0;

`elsif N25W032A11E

    parameter [12*8:1] devName = "N25W032A11E";

    parameter addrDim = 22; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h2C;
    parameter [dataDim-1:0] MemoryType_ID = 'hCB; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h16; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define PowDown
    `define VCC_1e8V
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25Q016A11E

    parameter [12*8:1] devName = "N25Q016A11E";

    parameter addrDim = 21; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBB; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h15; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define PowDown
    `define VCC_1e8V
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25Q016A13E

    parameter [12*8:1] devName = "N25Q016A13E";

    parameter addrDim = 21; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBB; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h15; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define PowDown
    `define VCC_3V
    `define RESET_software

    parameter RESET_PIN=0;

`elsif N25Q008A11E

    parameter [12*8:1] devName = "N25Q008A11E";

    parameter addrDim = 20; 
    parameter sectorAddrDim = 6;
    parameter [dataDim-1:0] Manufacturer_ID = 'h20;
    parameter [dataDim-1:0] MemoryType_ID = 'hBB; 
    parameter [dataDim-1:0] MemoryCapacity_ID = 'h14; 
    parameter [dataDim-1:0] UID = 'h10; 
    parameter [dataDim-1:0] EDID_0 = 'h00; 
    parameter [dataDim-1:0] EDID_1 = 'h00; 
    parameter [dataDim-1:0] CFD_0 = 'h0; 
    parameter [dataDim-1:0] CFD_1 = 'h0; 
    parameter [dataDim-1:0] CFD_2 = 'h0; 
    parameter [dataDim-1:0] CFD_3 = 'h0; 
    parameter [dataDim-1:0] CFD_4 = 'h0; 
    parameter [dataDim-1:0] CFD_5 = 'h0; 
    parameter [dataDim-1:0] CFD_6 = 'h0; 
    parameter [dataDim-1:0] CFD_7 = 'h0; 
    parameter [dataDim-1:0] CFD_8 = 'h0; 
    parameter [dataDim-1:0] CFD_9 = 'h0;
    parameter [dataDim-1:0] CFD_10 = 'h0; 
    parameter [dataDim-1:0] CFD_11 = 'h0; 
    parameter [dataDim-1:0] CFD_12 = 'h0; 
    parameter [dataDim-1:0] CFD_13 = 'h0; 
   
    `define HOLD_pin
    `define SubSect
    `define XIP_Numonyx
    `define PowDown
    `define VCC_1e8V
    `define RESET_software

    parameter RESET_PIN=0;

`endif



//----------------------------
// Include TimingData file 
//----------------------------


`include "TimingData.h"





//----------------------------------------
// Parameters constants for all devices
//----------------------------------------

`define VoltageRange 31:0




//---------------------------
// stimuli clock period
//---------------------------
// for a correct behavior of the stimuli, clock period should
// be multiple of 4

`ifdef N25Q256A73E
  parameter time T = 40;
`elsif N25Q256A33E
  parameter time T = 40;
`elsif N25Q256A31E
  parameter time T = 40;
`elsif N25Q256A13E
  parameter time T = 40;
`elsif N25Q256A11E
  parameter time T = 40;
`elsif N25Q064A13E
  parameter time T = 40;
`elsif N25Q064A11E
  parameter time T = 40;
`elsif N25Q032A13E
  parameter time T = 40;
`elsif N25Q032A11E
  parameter time T = 40;
`elsif N25W032A13E
  parameter time T = 40;
`elsif N25W032A11E
  parameter time T = 40;
`else
  parameter time T = 40;
`endif




//-----------------------------------
// Devices Parameters 
//-----------------------------------


// data & address dimensions

parameter cmdDim = 8;
parameter addrDimLatch = 24; //da verificare se va bene

`ifdef byte_4
    parameter addrDimLatch4 = 32; //da verificare
`endif

// memory organization


parameter colAddrDim = 8;
parameter colAddr_sup = colAddrDim-1;
parameter pageDim = 2 ** colAddrDim;

`ifdef Stack1024Mb
  parameter nSector = 4 * (2 ** sectorAddrDim);
  parameter memDim = 4 * (2 ** addrDim); 
`elsif Stack512Mb
  parameter nSector = 2 * (2 ** sectorAddrDim);
  parameter memDim = 2* (2 ** addrDim); 
`else
  parameter nSector = 2 ** sectorAddrDim;
  parameter memDim = 2 ** addrDim; 
`endif
parameter sectorAddr_inf = addrDim-sectorAddrDim; 
parameter EARvalidDim = 2; // number of valid EAR bits


parameter sectorAddr_sup = addrDim-1;
parameter sectorSize = 2 ** (addrDim-sectorAddrDim);

 `ifdef bottom
   parameter bootSec_num = 8;
 `endif
 `ifdef top
   parameter bootSec_num = 8;
 `endif
 `ifdef uniform
   parameter bootSec_num = 0;
 `endif

`ifdef SubSect

parameter subsecAddrDim = 4+sectorAddrDim;
parameter subsecAddr_inf = 12;
parameter subsecAddr_sup = addrDim-1;
parameter subsecSize = 2 ** (addrDim-subsecAddrDim);
parameter nSSector = 2 ** subsecAddrDim;
 
`endif

`ifdef MEDT_SubSect32K

parameter subsec32AddrDim = 1+sectorAddrDim;
parameter subsec32Addr_inf = 15;
parameter subsec32Addr_sup = addrDim-1;
parameter subsec32Size = 2 ** (addrDim-subsec32AddrDim);

`endif

`ifdef MEDT_4KBLocking
parameter TOP_sector = 'h0;
parameter BOTTOM_sector = 'h0; 
`endif


parameter pageAddrDim = addrDim-colAddrDim;
parameter pageAddr_inf = colAddr_sup+1;
parameter pageAddr_sup = addrDim-1;




// OTP section

 parameter OTP_dim = 65;
 parameter OTP_addrDim = 7;

// FDP section

parameter FDP_dim = 16384; //2048 byte
parameter FDP_addrDim = 11; // 2048 address


// others constants

parameter [dataDim-1:0] data_NP = 'hFF;


`ifdef VCC_3V
parameter [`VoltageRange] Vcc_wi = 'd2500; //write inhibit 
parameter [`VoltageRange] Vcc_min = 'd2700;
parameter [`VoltageRange] Vcc_max = 'd3600;

`else

parameter [`VoltageRange] Vcc_wi = 'd1500; //write inhibit 
parameter [`VoltageRange] Vcc_min = 'd1700;
parameter [`VoltageRange] Vcc_max = 'd2000;
`endif
//-------------------------
// Alias used in the code
//-------------------------


// status register code

`define WIP N25Qxxx.stat.SR[0]

`define WEL N25Qxxx.stat.SR[1]

`define BP0 N25Qxxx.stat.SR[2]

`define BP1 N25Qxxx.stat.SR[3]

`define BP2 N25Qxxx.stat.SR[4]

`define TB N25Qxxx.stat.SR[5]

`define BP3 N25Qxxx.stat.SR[6]

`define SRWD N25Qxxx.stat.SR[7]

// PLR Sequence cycles
parameter PLRS_1st_x4_byte3 = 7;
parameter PLRS_1st_x4_byte4 = 9;
parameter PLRS_1st_x2_byte3 = 13;
parameter PLRS_1st_x2_byte4 = 17;
parameter PLRS_1st_x1_byte3 = 25;
parameter PLRS_1st_x1_byte4 = 33;

parameter PLRS_2nd = 8;
