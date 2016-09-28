///////////////////////////////////////////////////////////////////////////////
//  File name : s25fl008k.v
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
//  Copyright (C) 2010 Spansion, LLC.
//
//  MODIFICATION HISTORY :
//
//  version: |   author:         |   mod date:  | changes made:
//    V1.0       R.Prokopovic       10 Sep 30      Initial
//            
///////////////////////////////////////////////////////////////////////////////
//  PART DESCRIPTION:
//
//  Library:    FLASH
//  Technology: FLASH MEMORY
//  Part:       S25FL008K
//
//  Description: 8 Megabit Serial Flash Memory
//
///////////////////////////////////////////////////////////////////////////////
//  Comments :
//
//////////////////////////////////////////////////////////////////////////////
//  Known Bugs:
//
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
// MODULE DECLARATION                                                       //
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ps/1 ps

module s25fl008k
    (
        // Data Inputs/Outputs
        SI     ,
        SO     ,
        // Controls
        SCK    ,
        CSNeg  ,
        HOLDNeg,
        WPNeg  

);

///////////////////////////////////////////////////////////////////////////////
// Port / Part Pin Declarations
///////////////////////////////////////////////////////////////////////////////
    inout   SI            ;
    inout   SO            ;
    input   SCK           ;
    input   CSNeg         ;
    inout   HOLDNeg       ;
    inout   WPNeg         ;

    // interconnect path delay signals
    wire   SCK_ipd        ;
    wire   SI_ipd         ;
    wire   SO_ipd         ;

    wire SI_in            ;
    assign SI_in = SI_ipd ;

    wire SI_out           ;
    assign SI_out = SI    ;

    wire SO_in            ;
    assign SO_in = SO_ipd ;

    wire SO_out           ;
    assign SO_out = SO    ;

    wire   CSNeg_ipd      ;
    wire   HOLDNeg_ipd    ;
    wire   WPNeg_ipd      ;

    wire HOLDNeg_in                 ;
    //Internal pull-up 
    assign HOLDNeg_in = (HOLDNeg_ipd === 1'bx) ? 1'b1 : HOLDNeg_ipd;

    wire HOLDNeg_out                ;
    assign HOLDNeg_out = HOLDNeg    ;

    wire   WPNeg_in                 ;
    //Internal pull-up 
    assign WPNeg_in = (WPNeg_ipd === 1'bx) ? 1'b1 : WPNeg_ipd;

    wire   WPNeg_out                ;
    assign WPNeg_out = WPNeg        ;

    // ***** internal delays *********************
    reg PP_in       = 1'b0;
    reg PP_out      = 1'b0;
    reg BP_in       = 1'b0;
    reg BP_out      = 1'b0;
    reg SE_in       = 1'b0;
    reg SE_out      = 1'b0;
    reg BE_in       = 1'b0;
    reg BE_out      = 1'b0;
    reg PRGSUSP_in  = 1'b0;
    reg PRGSUSP_out = 1'b0;
    reg ERSSUSP_in  = 1'b0;
    reg ERSSUSP_out = 1'b0;
    reg PRGRES_out  = 1'b0;
    reg ERSRES_out  = 1'b0;
    reg PRGRES_in   = 1'b0;
    reg ERSRES_in   = 1'b0;
    reg WRR_in      = 1'b0;
    reg WRR_out     = 1'b0;
    reg DP_in      = 1'b0;
    reg DP_out     = 1'b0;
    reg RES_in     = 1'b0;
    reg RES_out   = 1'b0 ;
    // ******* event control registers ************
    reg PRGSUSP_out_event = 1'b0;
    reg PRGRES_out_event = 1'b0;
    reg ERSSUSP_out_event = 1'b0;
    reg ERSRES_out_event = 1'b0;
    reg PGSUSP_event = 1'b0;
    reg PGRES_event = 1'b0;
    reg ESUSP_event = 1'b0;
    reg ERES_event = 1'b0;
    reg next_state_event = 1'b0;

    reg rising_edge_PoweredUp = 1'b0;
    reg rising_edge_RES_out = 1'b0;
    reg rising_edge_PRGRES_out = 1'b0;
    reg rising_edge_PSTART = 1'b0;
    reg rising_edge_WSTART = 1'b0;
    reg rising_edge_VLTSTART = 1'b0;
    reg rising_edge_ESTART = 1'b0;
    reg rising_edge_prot_bits = 1'b0;
    reg rising_edge_CSNeg_ipd  = 1'b0;
    reg falling_edge_CSNeg_ipd = 1'b0;
    reg rising_edge_SCK_ipd    = 1'b0;
    reg falling_edge_SCK_ipd   = 1'b0;

    reg  SOut_zd = 1'bZ     ;
    reg  SOut_z  = 1'bZ     ;

    reg DataDriveOut_SO = 1'bZ ;
    reg DataDriveOut_SI = 1'bZ ;
    reg DataDriveOut_HOLD = 1'bZ ;
    reg DataDriveOut_WP = 1'bZ ;

    wire SI_z                ;
    wire SO_z                ;

    reg  SIOut_zd = 1'bZ     ;
    reg  SIOut_z  = 1'bZ     ;

    reg  WPNegOut_zd   = 1'bZ  ;
    reg  HOLDNegOut_zd = 1'bZ  ;

    assign SI_z = SIOut_z;
    assign SO_z = SOut_z;

    parameter UserPreload       = 1;
    parameter mem_file_name     = "none";//"s25fl008k.mem";
    parameter screg_file_name   = "s25fl008kscreg.mem";//"none";
    parameter TimingModel   = "DefaultTimingModel";

    parameter  PartID          = "s25fl008k";
    parameter  MaxData         = 255;
    parameter  AddrRANGE       = 20'hFFFFF;
    parameter  PageNum         = 12'hFFF;
    parameter  SecSize_4       = 12'hFFF;
    parameter  SecSize_32      = 16'h7FFF;
    parameter  SecSize_64      = 16'hFFFF;
    parameter  Blk_4_Num       = 255;
    parameter  Blk_64_Num      = 15;
    parameter  Blk_32_Num      = 32;
    parameter  SFDP_HiAddr     = 8'hFF;
    parameter  SFDP_LoAddr     = 8'h00;
    parameter  SecReg_HiAddr   = 8'hFF;
    parameter  SecReg_LoAddr   = 8'h00;
    parameter  SCREG_LoAddr    = 12'h000;
    parameter  SCREG_HiAddr    = 12'h2FF;
    parameter  BYTE           = 8;

    // Manufacturer Identification and Device Identification
    parameter  Manuf_ID        = 8'hEF;
    parameter  Device_ID1      = 8'h13;
    parameter  Device_ID2      = 8'h40;
    parameter  Device_ID3      = 8'h14;
    parameter  unique_id       = 64'h000000000000ABAB;

    // If speedsimulation is needed uncomment following line

        `define SPEEDSIM;

    // powerup
    reg PoweredUp;

    // FSM control signals
    reg PDONE     = 1'b0;
    reg PSTART    = 1'b0;
    reg PGSUSP    = 1'b0;
    reg PGRES     = 1'b0;
//     reg ERSRES    ;

    reg WDONE     = 1'b0;
    reg WSTART    = 1'b0;
    reg VLTSTART  = 1'b0;
    reg VLTDONE   = 1'b0;

    reg EDONE     = 1'b0;
    reg ESTART    = 1'b0;
    reg ESUSP     = 1'b0;
    reg ERES      = 1'b0;

    // Programming buffer
    integer WByte[0:255];

    // Flash Memory Array
    integer Mem[0:AddrRANGE];

    // Registers
    // Status Register 1
    reg[7:0] Status_reg1       = 8'h00;
    reg[7:0] Status_reg1_in    = 8'h00;

    wire  SRP0;
    wire  SEC;
    wire  TB;
    wire  BP2;
    wire  BP1;
    wire  BP0;
    wire  WEL;
    wire  BUSY;
    assign  SRP0 = Status_reg1[7];
    assign  SEC  = Status_reg1[6];
    assign  TB   = Status_reg1[5];
    assign  BP2  = Status_reg1[4];
    assign  BP1  = Status_reg1[3];
    assign  BP0  = Status_reg1[2];
    assign  WEL  = Status_reg1[1];
    assign  BUSY = Status_reg1[0];

    // Status Register 2
    reg[7:0] Status_reg2       = 8'h00;
    reg[7:0] Status_reg2_in    = 8'h00;

    wire  SUS;
    wire  CMP;

    wire  [2:0]LB;
    wire  QE;
    wire  SRP1;
    assign  SUS  = Status_reg2[7];
    assign  CMP  = Status_reg2[6];
    assign  LB   = Status_reg2[5:3];
    assign  QE   = Status_reg2[1];
    assign  SRP1 = Status_reg2[0];

    reg[15:0] Status_reg;     // Status_reg2 & Status_reg1
    reg[15:0] Status_reg_in;  // Status_reg2 & Status_reg1

    // Sector is protect if Sec_Prot(SecNum) = '1'
    reg [Blk_4_Num:0] Sec_Prot  = {256{1'b0}};

    // Security registers array
    integer Security_Reg[SCREG_LoAddr:SCREG_HiAddr];
    integer Security_Reg1[SecReg_LoAddr:SecReg_HiAddr];
    integer Security_Reg2[SecReg_LoAddr:SecReg_HiAddr];
    integer Security_Reg3[SecReg_LoAddr:SecReg_HiAddr];

    // SFDP register array
    integer SFDP_array[SFDP_LoAddr:SFDP_HiAddr];

    ///////////////////////////////////////////////////////////////////////////
    // Command Register
    reg write;
    reg read_out;
    reg slow_read;
    reg dual_read;
    reg fast_read;
    reg quad_read;
    reg pp_quad;
    reg oe = 1'b0;
    event oe_event;

    reg[7:0]  old_bit, new_bit;
    integer old_int, new_int;
    integer wr_cnt;
    integer cnt;
    integer Byte_number = 0;
    integer read_cnt = 0;
    integer read_addr = 0;
    reg[7:0] data_out;
    reg[23:0] ident_out;
    reg[15:0] ident_out2;
    integer AddrLo;
    integer AddrHi;
    integer AddrLo_ers;
    integer AddrHi_ers;
    integer AddrLo_wrap;
    integer AddrHi_wrap;

    reg change_prot_bits = 0;

    //Address
    integer Address = 0;         // 0 - AddrRANGE
    reg  change_addr;

    //Sector and subsector addresses
    integer SA        = 0;
    integer sect;
    integer sect_tmp_pg;
    integer sect_tmp_ers;
    integer sfdp_addr;
    integer w_size;

    reg hold_mode     = 1'b0;

    time SCK_cycle = 0;
    time prev_SCK;

    // Flag for release from deep power down, read ID or not
    reg res_flag;
    reg pg_screg_flag  = 1'b0;
    reg ers_screg_flag = 1'b0;
    reg wren_vlt_flag  = 1'b0;
    reg susp_flag  = 1'b0;
    // timing check violation
    reg Viol = 1'b0;
    reg sr_read = 1'b0;
    reg read_id = 1'b0;
    reg glitch = 1'b0;
    time SCK_SO_2;
    time SCK_SOS_01;
    time start_rdid;
    time out_time;
///////////////////////////////////////////////////////////////////////////////
//Interconnect Path Delay Section
///////////////////////////////////////////////////////////////////////////////
 buf   (SCK_ipd, SCK);
 buf   (SI_ipd, SI);

 buf   (SO_ipd, SO);
 buf   (CSNeg_ipd, CSNeg);
 buf   (HOLDNeg_ipd, HOLDNeg);
 buf   (WPNeg_ipd, WPNeg);

///////////////////////////////////////////////////////////////////////////////
// Propagation  delay Section
///////////////////////////////////////////////////////////////////////////////
    nmos   (SI,   SI_z , 1'b1);

    nmos   (SO,   SO_z , 1'b1);
    nmos   (HOLDNeg,   HOLDNegOut_zd , 1'b1);
    nmos   (WPNeg,   WPNegOut_zd , 1'b1);

    wire deg_pin;
    wire deg_sin;
    wire deg_holdin;

    reg deq_holdin;
    always @(HOLDNeg_ipd, HOLDNegOut_zd)
    begin
      if (HOLDNeg_ipd==HOLDNegOut_zd)
        deq_holdin=1'b0;
      else
        deq_holdin=1'b1;
    end
    //VHDL VITAL CheckEnable equivalents
    wire rd_slow;
    assign rd_slow = slow_read;
    wire rd_fast;
    assign rd_fast = fast_read;
    wire quad_rd;
    assign quad_rd = deg_holdin && QE && ~dual_read && (SIOut_z !== 1'bz);
    wire quad_pg;
    assign quad_pg = QE && WEL && pp_quad;
    wire wr_prot;
    assign wr_prot = SRP0 && WEL;
    wire dual_rd;
    assign dual_rd = dual_read ;
    wire power;
    assign power = PoweredUp;
    wire hold_cond;
    assign hold_cond = PoweredUp && ~QE && HOLDNeg_in !== 1'bX;
    wire any_read;
    assign any_read = (dual_read || quad_read || slow_read || fast_read) 
                                                    && ~WEL && ~sr_read;
    // check when data is generated from model to avoid setuphold check in
    // this occasion
    assign deg_holdin=deq_holdin;

    reg deq_sin;
    always @(SI_in, SIOut_z)
    begin
      if (SI_in !== 1'bZ)
        deq_sin=1'b0;
      else
        deq_sin=1'b1;
    end
    assign deg_sin = deq_sin && ~read_out; /*&& (~any_read);*/

    wire pg_ers;
    assign pg_ers = PSTART || ESTART || sr_read;

specify
    // tipd delays: interconnect path delays , mapped to input port delays.
    // In Verilog is not necessary to declare any tipd_ delay variables,
    // they can be taken from SDF file
    // With all the other delays real delays would be taken from SDF file

    // tpd delays
    specparam   tpd_SCK_SO_1            =1; // tCLQV1
    specparam   tpd_SCK_SO_2            =1; // tCLQV2 -for read ID instructions
    specparam   tpd_CSNeg_SO            =1; // tSHQZ (tDIS)
    specparam   tpd_HOLDNeg_SO          =1; // tHLQZ, tHHQX

    //tsetup values: setup times
    specparam   tsetup_CSNeg_SCK        =1; // tSLCH, tSHCH
    specparam   tsetup_SI_SCK           =1; // tDVCH
    specparam   tsetup_HOLDNeg_SCK      =1; // tHLCH, tHHCH
    specparam   tsetup_WPNeg_CSNeg      =1; // tWHSL

    //thold values: hold times
    specparam   thold_CSNeg_SCK         =1; // tCHSL, tCHSH
    specparam   thold_SI_SCK            =1; // tCHDX
    specparam   thold_HOLDNeg_SCK       =1; // tCHHL, tCHHH
    specparam   thold_WPNeg_CSNeg       =1; // tSHWL

    // tpw values: pulse width
    specparam   tpw_SCK_slow_posedge    =1; // tCH
    specparam   tpw_SCK_slow_negedge    =1; // tCL
    specparam   tpw_SCK_fast_posedge    =1; // tCH
    specparam   tpw_SCK_fast_negedge    =1; // tCL
    specparam   tpw_CSNeg_read_posedge  =1; // tSHSL1
    specparam   tpw_CSNeg_pger_posedge  =1; // tSHSL2

    // tperiod min (calculated as 1/max freq)
    specparam   tperiod_SCK_slow        =1;
    specparam   tperiod_SCK_fast        =1;

    // tdevice values: values for internal delays

    // VCC (min) to CS# Low
    specparam   tdevice_PU              = 1e7; // 10 us
    // CS# High to Power Down Mode -- tDP
    specparam   tdevice_DP              = 3e6; // 3 us
    // CS# High to StandBy mode without Electronic Signature read
    specparam   tdevice_RES1            = 3e6; // 3 us
    // CS# High to StandBy mode with Electronic Signature read
    specparam   tdevice_RES2            = 18e5; // 1.8 us
    // CS# High to next Instruction after Suspend
    specparam   tdevice_SUS             = 2e7; // 20 us
    // Resume Suspend to Program/Erase time
    specparam   tdevice_PRGSUSP         = 2e5; // 200 ns

    `ifdef SPEEDSIM
        // Page Program Time
        specparam   tdevice_PP          = 3e8; // 30 us
        // Byte Program Time (First Byte)
        specparam   tdevice_BP1         = 5e5; // 0.5 us
        // Additional Byte Program Time (After First Byte)
        specparam   tdevice_BP2         = 12e4; // 120 ns
        // Sector Erase Time (4KB)
        specparam   tdevice_SE          = 4e9; // 4 ms
        // Block Erase Time (32KB)
        specparam   tdevice_BE1         = 8e9; // 8 ms
        // Block Erase Time (64KB)
        specparam   tdevice_BE2         = 1e10; // 10 ms
        // Chip Erase Time
        specparam   tdevice_CE          = 6e10; // 150 ms
        // Write Status Register Time
        specparam   tdevice_WRR         = 15e7; // 150 us
        // Write Volatile Status Register Time
        specparam   tdevice_VRR         = 5e4; // 50 ns
    `else
        // Page Program Time
        specparam   tdevice_PP          = 3e9; // 3 ms
        // Byte Program Time (First Byte)
        specparam   tdevice_BP1         = 5e7; // 50 us
        // Additional Byte Program Time (After First Byte)
        specparam   tdevice_BP2         = 12e6; // 12 us
        // Sector Erase Time (4KB)
        specparam   tdevice_SE          = 4e11; // 400 ms
        // Block Erase Time (32KB)
        specparam   tdevice_BE1         = 8e11; // 800 ms
        // Block Erase Time (64KB)
        specparam   tdevice_BE2         = 1e12; // 1000 ms
        // Chip Erase Time
        specparam   tdevice_CE          = 6e12; // 15 s
        // Write Status Register Time
        specparam   tdevice_WRR         = 15e9; // 15 ms
        // Write Volatile Status Register Time
        specparam   tdevice_VRR         = 5e4; // 50 ns
    `endif // SPEEDSIM

///////////////////////////////////////////////////////////////////////////////
// Input Port  Delays  don't require Verilog description
///////////////////////////////////////////////////////////////////////////////
// Path delays                                                               //
///////////////////////////////////////////////////////////////////////////////
    if (~read_id) (SCK => SO)     = tpd_SCK_SO_1;
    if (~glitch && read_id)  (SCK => SO)     = tpd_SCK_SO_2;
    if (CSNeg)    (CSNeg   => SO) = tpd_CSNeg_SO;
    if (~quad_read)    (HOLDNeg => SO) = tpd_HOLDNeg_SO;
    if (~glitch && (dual_read || quad_read)) (SCK => SI) = tpd_SCK_SO_1;
    if (CSNeg && ~deg_sin) (CSNeg => SI)  = tpd_CSNeg_SO;
    if (~quad_read && dual_read) (HOLDNeg => SI) = tpd_HOLDNeg_SO;

    if (~glitch && quad_read) (SCK => WPNeg) = tpd_SCK_SO_1;
    if (~glitch && quad_read) (SCK => HOLDNeg) = tpd_SCK_SO_1;
    if (CSNeg && QE) (CSNeg => SI) = tpd_CSNeg_SO;
    if (CSNeg && QE) (CSNeg => WPNeg) = tpd_CSNeg_SO;
    if (CSNeg && QE) (CSNeg => HOLDNeg) = tpd_CSNeg_SO;
///////////////////////////////////////////////////////////////////////////////
// Timing Violation                                                          //
///////////////////////////////////////////////////////////////////////////////
    $setup ( CSNeg          , posedge SCK &&& power,
                                            tsetup_CSNeg_SCK   ,    Viol);
    $setup ( SI             , posedge SCK &&& deg_sin,
                                            tsetup_SI_SCK      ,    Viol);
    $setup ( SO             , posedge SCK &&& quad_pg,
                                            tsetup_SI_SCK      ,    Viol);
    $setup ( WPNeg          , posedge SCK &&& quad_pg,
                                            tsetup_SI_SCK      ,    Viol);
    $setup ( HOLDNeg        , posedge SCK &&& quad_pg,
                                            tsetup_SI_SCK      ,    Viol);
    $setup ( HOLDNeg        , posedge SCK &&& hold_cond,
                                            tsetup_HOLDNeg_SCK ,    Viol);
    $setup ( WPNeg          , negedge CSNeg &&& WPNeg,
                                            tsetup_WPNeg_CSNeg ,    Viol);

    $hold  ( posedge SCK &&& power,   CSNeg,
                                            thold_CSNeg_SCK  ,      Viol);
    $hold  ( posedge SCK &&& deg_sin, SI   , 
                                            thold_SI_SCK     ,      Viol);
    $hold  ( posedge SCK &&& quad_pg, SO   ,
                                            thold_SI_SCK     ,      Viol);
    $hold  ( posedge SCK &&& quad_pg, WPNeg,
                                            thold_SI_SCK     ,      Viol);
    $hold  ( posedge SCK &&& quad_pg, HOLDNeg,              
                                            thold_SI_SCK     ,      Viol);
    $hold  ( posedge SCK &&& hold_cond, HOLDNeg,
                                            thold_HOLDNeg_SCK,      Viol);
    $hold  ( posedge CSNeg &&& wr_prot, WPNeg,
                                            thold_WPNeg_CSNeg,      Viol);

    $width ( posedge SCK   &&&  rd_slow  ,     tpw_SCK_slow_posedge);
    $width ( negedge SCK   &&&  rd_slow  ,     tpw_SCK_slow_negedge);
    $width ( posedge SCK   &&&  rd_fast  ,     tpw_SCK_fast_posedge);
    $width ( negedge SCK   &&&  rd_fast  ,     tpw_SCK_fast_negedge);
    $width ( posedge CSNeg &&&  any_read ,     tpw_CSNeg_read_posedge);
    $width ( posedge CSNeg &&&  pg_ers   ,     tpw_CSNeg_pger_posedge);

    $period ( posedge SCK  &&&  rd_slow  ,     tperiod_SCK_slow);
    $period ( posedge SCK  &&&  rd_fast  ,     tperiod_SCK_fast);

endspecify

///////////////////////////////////////////////////////////////////////////////
// Main Behavior Block                                                       //
///////////////////////////////////////////////////////////////////////////////
// FSM states
    parameter   IDLE            = 4'd0;
    parameter   WRITE_SR        = 4'd1;
    parameter   PAGE_PG         = 4'd2;
    parameter   PG_SUSP         = 4'd3;
    parameter   SECTOR_ERS      = 4'd4;
    parameter   BULK_ERS        = 4'd5;
    parameter   ERS_SUSP        = 4'd6;
    parameter   ERS_SUSP_PG     = 4'd7;
    parameter   PG_SUSP_ERS     = 4'd8;
    parameter   DP_DOWN         = 4'd9;
    parameter   WRITE_SR_V      = 4'd10;

    reg [3:0] current_state;
    reg [3:0] next_state;

// Instruction type
    parameter   NONE            = 6'd0;
    parameter   WREN            = 6'd1;  // 06h
    parameter   WRENV           = 6'd2;  // 50h
    parameter   WRDI            = 6'd3;  // 04h
    parameter   RDSR            = 6'd4;  // 05h
    parameter   RDSR2           = 6'd5;  // 35h
    parameter   WRR             = 6'd6;  // 01h
    parameter   READ            = 6'd7;  // 03h
    parameter   FAST_READ       = 6'd8;  // 0Bh
    parameter   FAST_DREAD      = 6'd9;  // 3Bh
    parameter   FAST_QREAD      = 6'd10; // 6Bh
    parameter   FAST_DREAD_2    = 6'd11; // BBh
    parameter   FAST_QREAD_4    = 6'd12; // EBh
    parameter   W_QREAD         = 6'd13; // E7h
    parameter   WOCT_QREAD      = 6'd14; // E3h
    parameter   SET_BURST_WRAP  = 6'd15; // 77h
    parameter   CONT_RD_RST     = 6'd16; // FFh or FFFFH
    parameter   PP              = 6'd17; // 02h
    parameter   QPP             = 6'd18; // 32h
    parameter   SE              = 6'd19; // 20h
    parameter   BE_32           = 6'd20; // 52h
    parameter   BE_64           = 6'd21; // D8h
    parameter   CE              = 6'd22; // C7h or 60h
    parameter   ERS_PG_SUSP     = 6'd23; // 75h
    parameter   ERS_PG_RES      = 6'd24; // 7Ah
    parameter   DP              = 6'd25; // B9h
    parameter   RES_RD_ID       = 6'd26; // ABh
    parameter   RDID            = 6'd27; // 90h
    parameter   RDID_DUAL       = 6'd28; // 92h
    parameter   RDID_QUAD       = 6'd29; // 94h
    parameter   RD_UNIQ_ID      = 6'd30; // 4Bh
    parameter   RDIDJ           = 6'd31; // 9Fh
    parameter   RD_SFDP         = 6'd32; // 5Ah
    parameter   ERS_SCREG       = 6'd33; // 44h
    parameter   PG_SCREG        = 6'd34; // 42h
    parameter   RD_SCREG        = 6'd35; // 48h

    reg [5:0]   Instruct;

//Bus cycle state
    parameter   STAND_BY        = 3'd0;
    parameter   OPCODE_BYTE     = 3'd1;
    parameter   ADDRESS_BYTES   = 3'd2;
    parameter   DUMMY_BYTES     = 3'd3;
    parameter   MODE_BYTE       = 3'd4;
    parameter   DATA_BYTES      = 3'd5;
    
    reg [2:0]   bus_cycle_state;


    //Power Up time;
    initial
    begin
        PoweredUp = 1'b0;
        #tdevice_PU PoweredUp = 1'b1;
    end

    always @(PoweredUp or falling_edge_CSNeg_ipd)
    begin:CheckCEOnPowerUP
        if ((~PoweredUp) && falling_edge_CSNeg_ipd)
            $display ("Device is selected during Power Up");
    end

    initial
    begin : Init
        write       = 1'b0;
        read_out    = 1'b0;
        Address     = 0;
        change_addr = 1'b0;
//         cnt         = 0;
        PGSUSP      = 1'b0;
        PGRES       = 1'b0;
        ESUSP       = 1'b0;
        ERES        = 1'b0;
        PDONE       = 1'b1;
        PSTART      = 1'b0;
        EDONE       = 1'b1;
        ESTART      = 1'b0;
        WDONE       = 1'b1;
        WSTART      = 1'b0;
        VLTDONE     = 1'b1;
        VLTSTART    = 1'b0;

        DP_in       = 1'b0;
        DP_out      = 1'b0;
        RES_in      = 1'b0;
        RES_out     = 1'b0;
        PRGRES_in   = 1'b0;
        ERSRES_in   = 1'b0;
        Instruct        = NONE;
        bus_cycle_state = STAND_BY;
        current_state   = IDLE;
        next_state      = IDLE;

    end

    // initialize memory and load preload files if any
    initial
    begin: InitMemory
        integer i;

        for (i=0;i<=AddrRANGE;i=i+1)
        begin
            Mem[i] = MaxData;
        end

        if ((UserPreload) && !(mem_file_name == "none"))
        begin
           // Memory Preload
           //s25fl008k.mem, memory preload file
           //  @aaaaaa - <aaaaaa> stands for address
           //  dd      - <dd> is byte to be written at Mem(aaaaaa++)
           // (aaaaaa is incremented at every load)
           $readmemh(mem_file_name,Mem);
        end

        for (i=SCREG_LoAddr;i<=SCREG_HiAddr;i=i+1)
        begin
            Security_Reg[i] = MaxData;
        end

        if (UserPreload && !(screg_file_name == "none"))
        begin
        //s25fl008kSCREG memory file
        //   /       - comment
        //   @aaa     - <aaa> stands for address of specific Security register
        //   dd      - <dd> is byte to be written at SCREG(aaa++)
        //   (aa is incremented at every load)
        //   only first 1-4 columns are loaded. NO empty lines !!!!!!!!!!!!!!!!
           $readmemh(screg_file_name,Security_Reg);
        end
        for (i=0;i<=255;i=i+1)
        begin
            Security_Reg1[i] = Security_Reg[i];
            Security_Reg2[i] = Security_Reg[256+i];
            Security_Reg3[i] = Security_Reg[512+i];
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // SFDP - Serial Flash Discoverable Parameter register
    initial
    begin: InitSFDP
    integer i;
    integer j;
        SFDP_array[8'h00] = 8'h53;
        SFDP_array[8'h01] = 8'h46;
        SFDP_array[8'h02] = 8'h44;
        SFDP_array[8'h03] = 8'h50;
        SFDP_array[8'h04] = 8'h01;
        SFDP_array[8'h05] = 8'h01;
        SFDP_array[8'h06] = 8'h00;
        SFDP_array[8'h07] = 8'hFF;
        SFDP_array[8'h08] = 8'hEF;
        SFDP_array[8'h09] = 8'h00;
        SFDP_array[8'h0A] = 8'h01;
        SFDP_array[8'h0B] = 8'h04;
        SFDP_array[8'h0C] = 8'h80;
        SFDP_array[8'h0D] = 8'h00;
        SFDP_array[8'h0E] = 8'h00;
        SFDP_array[8'h0F] = 8'hFF;
        SFDP_array[8'h10] = 8'hEF;
        SFDP_array[8'h11] = 8'h00;
        SFDP_array[8'h12] = 8'h01;
        SFDP_array[8'h13] = 8'h00;
        SFDP_array[8'h14] = 8'h90;
        SFDP_array[8'h15] = 8'h00;
        SFDP_array[8'h16] = 8'h00;
        SFDP_array[8'h17] = 8'hFF;

        for (i=24;i<=127;i=i+1)
        begin
            SFDP_array[i] = MaxData;
        end

        SFDP_array[8'h80] = 8'hE5;
        SFDP_array[8'h81] = 8'h20;
        SFDP_array[8'h82] = 8'hF1;
        SFDP_array[8'h83] = 8'hFF;
        SFDP_array[8'h84] = 8'hFF;
        SFDP_array[8'h85] = 8'hFF;
        SFDP_array[8'h86] = 8'h7F;
        SFDP_array[8'h87] = 8'h00;
        SFDP_array[8'h88] = 8'h44;
        SFDP_array[8'h89] = 8'hEB;
        SFDP_array[8'h8A] = 8'h08;
        SFDP_array[8'h8B] = 8'h6B;
        SFDP_array[8'h8C] = 8'h08;
        SFDP_array[8'h8D] = 8'h3B;
        SFDP_array[8'h8E] = 8'h80;
        SFDP_array[8'h8F] = 8'hBB;

        for (i=144;i<=255;i=i+1)
        begin
            SFDP_array[i] = MaxData;
        end

    end
    ///////////////////////////////////////////////////////////////////////////
    //// Internal Delays
    ///////////////////////////////////////////////////////////////////////////
    always @(posedge DP_in)
    begin:TDPr
        #tdevice_DP DP_out = DP_in;
    end
    always @(negedge DP_in)
    begin:TDPf
        #1 DP_out = DP_in;
    end

    always @(posedge RES_in)
    begin:TRESr
        if (res_flag)  // res_flag is '1' when read ID after resume DP
                       // res_flag will be set to '1' in DUMMY_BYTES if read ID
            #tdevice_RES2 RES_out = RES_in;
        else
            #tdevice_RES1 RES_out = RES_in;
    end
    always @(negedge RES_in)
    begin:TRESf
        #1 RES_out = RES_in;
    end

    always @(posedge PRGSUSP_in)
    begin:PRGSuspend
        PRGSUSP_out = 1'b0;
        #tdevice_SUS PRGSUSP_out = 1'b1;
    end

    always @(posedge PRGRES_in)
    begin:ProgSuspend
        PRGRES_out = 1'b0;
        #tdevice_PRGSUSP PRGRES_out = 1'b1;
    end

    always @(posedge ERSSUSP_in)
    begin:ERSSuspend
        ERSSUSP_out = 1'b0;
        #tdevice_SUS ERSSUSP_out = 1'b1;
    end

    always @(posedge ERSRES_in)
    begin:ERSresume
        ERSRES_out = 1'b0;
        #tdevice_PRGSUSP ERSRES_out = 1'b1;
    end

    always @(posedge ERSRES_in or posedge PRGRES_in)
    begin
        susp_flag = 1'b1;
        #tdevice_SUS susp_flag = 1'b0;
    end

    always @(next_state or PoweredUp)
    begin: StateTransition
        if (PoweredUp)
        begin
            current_state = next_state;
        end
    end

///////////////////////////////////////////////////////////////////////////////
// write cycle decode
///////////////////////////////////////////////////////////////////////////////
    integer opcode_cnt = 0;
    integer addr_cnt   = 0;
    integer mode_cnt   = 0;
    integer wrap_cnt   = 0;
    integer dummy_cnt  = 0;
    integer data_cnt   = 0;
    integer bit_cnt    = 0;

    reg [4095:0] Data_in = 4096'b0;
    reg [7:0] opcode;
    reg [15:0] opcode_double;
    reg [7:0] opcode_in;
    reg [15:0] opcode_double_in;
    reg [23:0] addr_bytes;
    reg [23:0] Address_in;
    reg [7:0] mode_byte;
    reg [7:0] mode_in;
    reg [7:0] wrap_in;
    reg [7:0] wrap_byte;

    integer quad_data_in [0:511];
    reg [3:0] quad_nybble = 4'b0;
    reg [3:0] Quad_slv;
    reg [7:0] Byte_slv;

    always @(rising_edge_CSNeg_ipd or falling_edge_CSNeg_ipd or 
           rising_edge_SCK_ipd or falling_edge_SCK_ipd)
    begin: Buscycle
        integer i;
        integer j;
        integer k;
        if (falling_edge_CSNeg_ipd)
        begin
            if (bus_cycle_state==STAND_BY)
            begin
                bus_cycle_state = OPCODE_BYTE;
                Instruct = NONE;
                write = 1'b1;
                opcode_cnt = 0;
                addr_cnt   = 0;
                data_cnt   = 0;
                mode_cnt   = 0;
                wrap_cnt   = 0;
                dummy_cnt  = 0;
            end
            else if (bus_cycle_state==DATA_BYTES && (mode_byte[5:4]==2'b10))
            begin
                bus_cycle_state = ADDRESS_BYTES;
                dummy_cnt  = 0;
                opcode_cnt = 0;
            end
        end    
        if (rising_edge_SCK_ipd && PoweredUp)
        begin
            if (~CSNeg_ipd)
            begin
                case (bus_cycle_state)
                    OPCODE_BYTE :
                    begin
                        if ((HOLDNeg_in && ~QE) || QE)
                        begin
                            opcode_in[opcode_cnt] = SI_in;
                            opcode_cnt = opcode_cnt + 1;
                            if (opcode_cnt == BYTE)
                            begin
                                for (i=0;i<=7;i=i+1)
                                begin
                                    opcode[i] = opcode_in[7-i];
                                end
                                case(opcode)
                                    8'b00000110 : // 06h
                                    begin
                                        Instruct = WREN;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b01010000 : // 50h
                                    begin
                                        Instruct = WRENV;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b00000100 : // 04h
                                    begin
                                        Instruct = WRDI;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b00000101 : // 05h
                                    begin
                                        Instruct = RDSR;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b00110101 : // 05h
                                    begin
                                        Instruct = RDSR2;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b00000001 : // 01h
                                    begin
                                        Instruct = WRR;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b00000011 : // 03h
                                    begin
                                        Instruct = READ;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b00001011 : // 0Bh
                                    begin
                                        Instruct = FAST_READ;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b00111011 : // 3Bh
                                    begin
                                        Instruct = FAST_DREAD;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b01101011 : // 6Bh
                                    begin
                                        Instruct = FAST_QREAD;
                                        if (QE)
                                            bus_cycle_state = ADDRESS_BYTES;
                                        else
                                            bus_cycle_state = STAND_BY;
                                    end
                                    8'b10111011 : // BBh
                                    begin
                                        Instruct = FAST_DREAD_2;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b11101011 : // EBh
                                    begin
                                        Instruct = FAST_QREAD_4;
                                        if (QE)
                                            bus_cycle_state = ADDRESS_BYTES;
                                        else
                                            bus_cycle_state = STAND_BY;
                                    end
                                    8'b11100111 : // E7h
                                    begin
                                        Instruct = W_QREAD;
                                        if (QE)
                                            bus_cycle_state = ADDRESS_BYTES;
                                        else
                                            bus_cycle_state = STAND_BY;
                                    end
                                    8'b11100011 : // E3h
                                    begin
                                        Instruct = WOCT_QREAD;
                                        if (QE)
                                            bus_cycle_state = ADDRESS_BYTES;
                                        else
                                            bus_cycle_state = STAND_BY;
                                    end
                                    8'b01110111 : // 77h
                                    begin
                                        Instruct = SET_BURST_WRAP;
                                        if (QE)
                                            bus_cycle_state = DUMMY_BYTES;
                                        else
                                            bus_cycle_state = STAND_BY;
                                    end
                                    8'b11111111 : // FFh
                                    begin
                                        Instruct = CONT_RD_RST;
                                        bus_cycle_state = MODE_BYTE;
                                    end
                                    8'b00000010 : // 02h
                                    begin
                                        Instruct = PP;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b00110010 : // 32h
                                    begin
                                        Instruct = QPP;
                                        if (QE)
                                            bus_cycle_state = ADDRESS_BYTES;
                                        else
                                            bus_cycle_state = STAND_BY;
                                    end
                                    8'b00100000 : // 20h
                                    begin
                                        Instruct = SE;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b01010010 : // 52h
                                    begin
                                        Instruct = BE_32;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b11011000 : // D8h
                                    begin
                                        Instruct = BE_64;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b11000111, 8'b01100000 : // C7h or 60h
                                    begin
                                        Instruct = CE;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b01110101 : // 75h
                                    begin
                                        Instruct = ERS_PG_SUSP;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b01111010 : // 7Ah
                                    begin
                                        Instruct = ERS_PG_RES;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b10111001 : // B9h
                                    begin
                                        Instruct = DP;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b10101011: // ABh
                                    begin
                                        Instruct = RES_RD_ID;
                                        bus_cycle_state = DUMMY_BYTES;
                                    end
                                    8'b10010000: // 90h
                                    begin
                                        Instruct = RDID;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b10010010: // 92h
                                    begin
                                        Instruct = RDID_DUAL;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b10010100: // 94h
                                    begin
                                        Instruct = RDID_QUAD;
                                        if (QE)
                                            bus_cycle_state = ADDRESS_BYTES;
                                        else
                                            bus_cycle_state = STAND_BY;
                                    end
                                    8'b01001011: // 4Bh
                                    begin
                                        Instruct = RD_UNIQ_ID;
                                        bus_cycle_state = DUMMY_BYTES;
                                    end
                                    8'b10011111: // 9Fh
                                    begin
                                        Instruct = RDIDJ;
                                        bus_cycle_state = DATA_BYTES;
                                    end
                                    8'b01011010: // 5Ah
                                    begin
                                        Instruct = RD_SFDP;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b01000100: // 44h
                                    begin
                                        Instruct = ERS_SCREG;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b01000010: // 42h
                                    begin
                                        Instruct = PG_SCREG;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                    8'b01001000: // 48h
                                    begin
                                        Instruct = RD_SCREG;
                                        bus_cycle_state = ADDRESS_BYTES;
                                    end
                                endcase
                            end
                        end
                        else
                            $display("Device is in HOLD mode, opcode");
                    end  // end of OPCODE_BYTE

                    ADDRESS_BYTES :
                    begin
                        if ((HOLDNeg_in && ~QE) || QE)
                        begin
                            if (Instruct == READ || Instruct == FAST_READ ||
                                Instruct == FAST_DREAD || Instruct == RDID ||
                                Instruct == SE || Instruct == PP ||
                                Instruct == RD_SCREG || Instruct == PG_SCREG ||
                                Instruct == RD_SFDP || Instruct == BE_32 ||
                                Instruct == BE_64 || Instruct == ERS_SCREG ||
                                ((Instruct == QPP || Instruct == FAST_QREAD) 
                                && QE))
                            begin
                                Address_in[addr_cnt] = SI_in;
                                addr_cnt = addr_cnt + 1;
                                if (addr_cnt == 3*BYTE)
                                begin
                                    for (i=23;i>=0;i=i-1)
                                    begin
                                        addr_bytes[23-i] = Address_in[i];
                                    end
                                    Address = addr_bytes ;
                                    change_addr = 1'b1;
                                    #1000 change_addr = 1'b0;
                                    if (Instruct == PP || Instruct == QPP 
                                    || Instruct == READ || Instruct == SE 
                                    || Instruct == BE_32 || Instruct == BE_64 
                                    || Instruct == RDID || Instruct == PG_SCREG
                                    || Instruct == ERS_SCREG)
                                        bus_cycle_state = DATA_BYTES;
                                    else
                                        bus_cycle_state = DUMMY_BYTES;
                                end
                            end
                            else if (Instruct == RDID_DUAL || 
                                    Instruct == FAST_DREAD_2)
                            begin
                                if (SO_in !== 1'bX)
                                begin
                                    Address_in[2*addr_cnt]     = SO_in;
                                    Address_in[2*addr_cnt + 1] = SI_in;
                                    read_cnt = 0;
                                    addr_cnt = addr_cnt + 1;
                                    if (addr_cnt == 3*BYTE/2)
                                    begin
                                        addr_cnt = 0;
                                        for (i=23;i>=0;i=i-1)
                                        begin
                                            addr_bytes[23-i] = Address_in[i];
                                        end
                                        Address = addr_bytes ;
                                        change_addr = 1'b1;
                                        #1000 change_addr = 1'b0;
                                        bus_cycle_state = MODE_BYTE;
                                    end
                                end
                                else
                                begin
                                    if (mode_byte[5:4] == 2'b10)
                                    begin
                                        opcode_double_in[opcode_cnt] = SI_in;
                                        opcode_cnt = opcode_cnt + 1;

                                        if (opcode_cnt == 2*BYTE)
                                        begin
                                            for (i=0;i<=15;i=i+1)
                                            begin
                                                opcode_double[i] = 
                                                opcode_double_in[15-i];
                                            end
                                            if (opcode_double == 16'hFFFF)
                                            begin
                                                Instruct = CONT_RD_RST;
                                                bus_cycle_state = MODE_BYTE;
                                            end
                                        end
                                    end
                                end
                            end
                            else if (QE && (Instruct == FAST_QREAD_4 || 
                                            Instruct == W_QREAD      ||
                                            Instruct == WOCT_QREAD   ||
                                            Instruct == RDID_QUAD))
                            begin
                                if (SO_in !== 1'bX)
                                begin
                                    Address_in[4*addr_cnt] = HOLDNeg_in;
                                    Address_in[4*addr_cnt+1] = WPNeg_in;
                                    Address_in[4*addr_cnt+2] = SO_in;
                                    Address_in[4*addr_cnt+3] = SI_in;
                                    read_cnt = 0;
                                    addr_cnt = addr_cnt + 1;
                                    if (addr_cnt == 3*BYTE/4)
                                    begin
                                        addr_cnt = 0;
                                        for(i=23;i>=0;i=i-1)
                                        begin
                                            addr_bytes[23-i] = Address_in[i];
                                        end
                                        Address = addr_bytes ;
                                        change_addr = 1'b1;
                                        #1000 change_addr = 1'b0;
                                        bus_cycle_state = MODE_BYTE;
                                    end
                                end
                                else
                                begin
                                    if (mode_byte[5:4] == 2'b10)
                                    begin
                                        opcode_in[opcode_cnt] = SI_in;
                                        opcode_cnt = opcode_cnt + 1;
                                        if (opcode_cnt == BYTE)
                                        begin
                                            for (i=0;i<=7;i=i+1)
                                            begin
                                                opcode[i] = opcode_in[7-i];
                                            end
                                            if (opcode == 8'hFF) 
                                            begin
                                                Instruct = CONT_RD_RST;
                                                bus_cycle_state = MODE_BYTE;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        else
                            $display("Device is in HOLD mode, addr");
                    end  // end of ADDRESS_BYTES

                    MODE_BYTE:
                    begin
                        if (QE || (HOLDNeg_in && ~QE))
                        begin
                            if (Instruct == SET_BURST_WRAP && QE)
                            begin
                                wrap_in[4*wrap_cnt] = HOLDNeg_in;
                                wrap_in[4*wrap_cnt+1] = WPNeg_in;
                                wrap_in[4*wrap_cnt+2] = SO_in;
                                wrap_in[4*wrap_cnt+3] = SI_in;
                                wrap_cnt = wrap_cnt + 1;
                                if (wrap_cnt == BYTE/4)
                                begin
                                    wrap_cnt = 0;
                                    for(i=7;i>=0;i=i-1)
                                    begin
                                        wrap_byte[i] = wrap_in[7-i];
                                    end
                                    bus_cycle_state = DATA_BYTES;
                                end
                                case (wrap_byte[6:5])
                                    2'b00:
                                        w_size = 8;
                                    2'b01:
                                        w_size = 16;
                                    2'b10:
                                        w_size = 32;
                                    2'b11:
                                        w_size = 64;
                                endcase
                            end
                            else if ((Instruct == FAST_QREAD_4 ||
                                Instruct == WOCT_QREAD ||
                                Instruct == W_QREAD ||
                                Instruct == RDID_QUAD ) && QE)
                            // FAST_QREAD_4,WOCT_QREAD,W_QREAD,RDID_QUAD
                            begin
                                mode_in[4*mode_cnt] = HOLDNeg_in;
                                mode_in[4*mode_cnt+1] = WPNeg_in;
                                mode_in[4*mode_cnt+2] = SO_in;
                                mode_in[4*mode_cnt+3] = SI_in;
                                mode_cnt = mode_cnt + 1;
                                if (mode_cnt == BYTE/4)
                                begin
                                    mode_cnt = 0;
                                    for(i=7;i>=0;i=i-1)
                                    begin
                                        mode_byte[i] = mode_in[7-i];
                                    end
                                    if (Instruct == WOCT_QREAD)
                                        bus_cycle_state = DATA_BYTES;
                                    else
                                        bus_cycle_state = DUMMY_BYTES;
                                end
                            end
                            else if (Instruct == RDID_DUAL || 
                                     Instruct == FAST_DREAD_2)
                            begin
                                mode_in[2*mode_cnt] = SO_in;
                                mode_in[2*mode_cnt+1] = SI_in;
                                mode_cnt = mode_cnt + 1;
                                if (mode_cnt == BYTE/2)
                                begin
                                    mode_cnt = 0;
                                    for(i=7;i>=0;i=i-1)
                                    begin
                                        mode_byte[i] = mode_in[7-i];
                                    end
                                    bus_cycle_state = DATA_BYTES;
                                end
                            end
                        end
                        else
                            $display("Device is in HOLD mode, mode");

                    end  // end of MODE_BYTE

                    DUMMY_BYTES:
                    begin
                        if (QE || (HOLDNeg_in && ~QE))
                        begin
                            if ((Instruct == FAST_QREAD_4 || 
                                Instruct == RDID_QUAD) && QE)
                            begin
                                dummy_cnt = dummy_cnt + 1;
                                if (dummy_cnt == BYTE/2)
                                    bus_cycle_state = DATA_BYTES;
                            end
                            else if (Instruct == W_QREAD && QE) 
                            begin
                                dummy_cnt = dummy_cnt + 1;
                                if (dummy_cnt == BYTE/4)
                                    bus_cycle_state = DATA_BYTES;
                            end
                            else if (Instruct == SET_BURST_WRAP && QE)
                            begin
                                dummy_cnt = dummy_cnt + 1;
                                if (dummy_cnt == 3*BYTE/4)
                                    bus_cycle_state = MODE_BYTE;
                            end
                            else if (Instruct == FAST_QREAD && QE)
                            begin
                                dummy_cnt = dummy_cnt + 1;
                                if (dummy_cnt == BYTE)
                                    bus_cycle_state = DATA_BYTES;
                            end
                            else if (Instruct==FAST_READ  || Instruct==RD_SFDP
                            || Instruct == FAST_DREAD || Instruct == RD_SCREG)
                            begin
                                dummy_cnt = dummy_cnt + 1;
                                if (dummy_cnt == BYTE)
                                    bus_cycle_state = DATA_BYTES;
                            end
                            else if (Instruct == RD_UNIQ_ID)
                            begin
                                dummy_cnt = dummy_cnt + 1;
                                if (dummy_cnt == 4*BYTE)
                                    bus_cycle_state = DATA_BYTES;
                            end
                            else // for RES_RD_ID
                            begin
                                dummy_cnt = dummy_cnt + 1;
                                if (dummy_cnt == 3*BYTE)
                                    bus_cycle_state = DATA_BYTES;
                            end
                        end
                        else
                            $display("Device is in HOLD mode, dummy");
                    end  // end of DUMMY_BYTES

                    DATA_BYTES:
                    begin
                        if (Instruct == PP || Instruct == WRR || 
                            Instruct == PG_SCREG) 
                        begin
                            if ((HOLDNeg_in && ~QE) || QE)
                            begin
                                if (data_cnt > 2047)
                                //In case of serial mode and PP,if more than 
                                //256 bytes are sent to the device
                                begin
                                    if (bit_cnt == 0)
                                    begin
                                        for (i=0;i<=(255*BYTE-1);i=i+1)
                                        begin
                                            Data_in[i] = Data_in[i+8];
                                        end
                                    end
                                    Data_in[2040 + bit_cnt] = SI_in;
                                    bit_cnt = bit_cnt + 1;
                                    if (bit_cnt == 8)
                                    begin
                                        bit_cnt = 0;
                                    end
                                    data_cnt = data_cnt + 1;
                                end
                                else
                                begin
                                    Data_in[data_cnt] = SI_in;
                                    data_cnt = data_cnt + 1;
                                    bit_cnt = 0;
                                end
                            end
                            else
                                $display("Device is in HOLD mode, data");
                        end
                        else if (Instruct == QPP && QE)
                        begin
                            pp_quad = 1'b1;
                            quad_nybble = {HOLDNeg_in, WPNeg_in, 
                                                        SO_in, SI_in};
                            if (data_cnt > 511)
                            begin
                            //In case of quad mode and QPP,if more than
                            // 256 bytes are sent to the device
                                for(i=0;i<=510;i=i+1)
                                begin
                                    quad_data_in[i] = quad_data_in[i+1];
                                end
                                quad_data_in[511] = quad_nybble;
                                data_cnt = data_cnt +1;
                            end
                            else
                            begin
                                if (quad_nybble !== 4'bZZZZ)
                                begin
                                    quad_data_in[data_cnt] = quad_nybble;
                                end
                                data_cnt = data_cnt +1;
                            end
                        end
                    end  // end of DATA_BYTES
                endcase  // end of case bus_cycle_state
            end  // end of ~CSNeg
        end  // end of rising_edge_SCK

        if (falling_edge_SCK_ipd)
        begin
            if ((bus_cycle_state == DATA_BYTES) && (~CSNeg_ipd))
            begin            
                if (((Instruct == RDSR        || Instruct == RDSR2        ||
                     Instruct == FAST_READ    || Instruct == FAST_DREAD   ||
                     Instruct == FAST_DREAD_2 || Instruct == RES_RD_ID    ||
                     Instruct == RDID         || Instruct == RDID_DUAL    || 
                     Instruct == RD_UNIQ_ID   || Instruct == RDIDJ        || 
                     Instruct == RD_SFDP      || Instruct == RD_SCREG     || 
                     Instruct == READ) && ((HOLDNeg_in && ~QE) || QE)) ||
                     ((Instruct == FAST_QREAD || Instruct == FAST_QREAD_4 ||
                      Instruct == W_QREAD || Instruct == RDID_QUAD ||
                      Instruct == WOCT_QREAD) && QE))
                begin
                    read_out = 1'b1;
                    #1 read_out = 1'b0;
                end
            end // end of ~CSNeg_ipd
        end  // end of falling_edge_SCK_ipd

        if (rising_edge_CSNeg_ipd)
        begin
            if (bus_cycle_state==MODE_BYTE && Instruct == CONT_RD_RST)
            begin
                mode_byte[5:4] = 2'b11;
                mode_byte[7:6] = 2'b00;
                mode_byte[3:0] = 4'b0000;
                bus_cycle_state = STAND_BY;
            end
            else if (bus_cycle_state==DATA_BYTES && ~(mode_byte[5:4]==2'b10))
            begin
                bus_cycle_state = STAND_BY;
                case (Instruct)                
                    WREN,
                    WRDI,
                    SET_BURST_WRAP,
                    SE,
                    BE_32,
                    BE_64,
                    CE,
                    ERS_PG_RES,
                    DP,
                    ERS_SCREG:
                    begin
                        if (data_cnt == 0)
                            write = 1'b0;
                    end

                    WRENV:
                    begin
                        write = 1'b0;
                        wren_vlt_flag = 1'b1;
                    end

                    RES_RD_ID:
                    begin
                        write = 1'b0;
                        res_flag = 1'b1;
                    end

                    WRR:
                    begin
                        if (data_cnt == 8)
                        //If CS# is driven high after eight
                        //cycle,only the Status Register is
                        //written to.
                        begin
                            write = 1'b0;
                            for(i=0;i<=7;i=i+1)
                            begin
                                Status_reg1_in[i]=
                                Data_in[7-i];
                            end
                        end
                        else if (data_cnt == 16)
                        //After the 16th cycle both the
                        //Status and Configuration Registers
                        //are written to.
                        begin
                            write = 1'b0;
                            for(i=0;i<=7;i=i+1)
                            begin
                                Status_reg1_in[i]=
                                Data_in[7-i];
                                Status_reg2_in[i]=
                                Data_in[15-i];
                            end
                        end
                    end

                    PP,
                    PG_SCREG:
                    begin
                        if (data_cnt > 0)
                        begin
                            if ((data_cnt % 8) == 0)
                            begin
                                write = 1'b0;
                                for (i=0;i<=255;i=i+1)
                                begin
                                    for (j=7;j>=0;j=j-1)
                                    begin
                                        Byte_slv[j] =
                                        Data_in[(i*8) + (7-j)];
                                    end
                                    WByte[i] = Byte_slv;
                                end
                                if (data_cnt > 256*BYTE)
                                    Byte_number = 255;
                                else
                                    Byte_number = ((data_cnt/8) - 1);
                            end
                        end
                    end

                    QPP:
                    begin
                        if (data_cnt >0)
                        begin
                            if ((data_cnt % 2) == 0)
                            begin
                                write = 1'b0;
                                for (i=0;i<=255;i=i+1)
                                begin
                                    for(j=1;j>=0;j=j-1)
                                    begin
                                        Quad_slv =
                                        quad_data_in[(i*2)+(1-j)];
                                        if (j==1)
                                            Byte_slv[7:4] = Quad_slv;
                                        else // if (j==0)
                                            Byte_slv[3:0] = Quad_slv;
                                    end
                                    WByte[i] = Byte_slv;
                                end
                                if (data_cnt > 256*BYTE/4)
                                    Byte_number = 255;
                                else
                                    Byte_number = ((data_cnt/2) - 1);
                            end
                        end
                    end

                endcase
            end
            else if (bus_cycle_state==DATA_BYTES && (mode_byte[5:4]==2'b10))
            begin
                bus_cycle_state = DATA_BYTES;
            end
            else
            begin
                bus_cycle_state = STAND_BY;
                if (HOLDNeg_in && (Instruct == RES_RD_ID) &&
                (dummy_cnt == 0))
                begin
                    write = 1'b0;
                    res_flag = 1'b0;
                end
            end
        end  // end of rising_edge_CSNeg_ipd

    end // end of Buscycle

    ///////////////////////////////////////////////////////////////////////////
    // Timing control for the Page Program
    ///////////////////////////////////////////////////////////////////////////
    time pob;
    time elapsed;
    time start;
    time duration;
    event pdone_event;

    always @(rising_edge_PSTART)
    begin
        if ((Instruct == PP) || (Instruct == QPP) || (Instruct == PG_SCREG))
            pob = tdevice_PP;
        else
            pob = tdevice_BP1;
        if ((rising_edge_PSTART) && PDONE)
        begin
            elapsed = 0;
            PDONE = 1'b0;
            ->pdone_event;
            start = $time;
        end
    end

    always @(PGSUSP_event)
    begin
        if ((PGSUSP_event) && PGSUSP && (~PDONE))
        begin
            disable pdone_process;
            elapsed = $time - start;
            duration = pob - elapsed;
            PDONE = 1'b0;
        end
    end

    always @(PGRES_event)
    begin
        if ((PGRES_event) && PGRES && (~PDONE))
        begin
            start = $time;
            ->pdone_event;
        end
    end

    always @(pdone_event)
    begin:pdone_process
        PDONE = 1'b0;
        #pob PDONE = 1'b1;
    end

    ///////////////////////////////////////////////////////////////////////////
    // Timing control for the Write Status Register Operation
    // start
    ///////////////////////////////////////////////////////////////////////////
    time wob;
    always @(WSTART)
    begin
        wob = tdevice_WRR;
        if ((rising_edge_WSTART) && WDONE)
        begin
            WDONE = 1'b0;
            #wob WDONE = 1'b1;
        end
    end
    ///////////////////////////////////////////////////////////////////////////
    // Timing control for the Volatile Write Status Register Operation
    // start
    ///////////////////////////////////////////////////////////////////////////
    time vob;
    always @(VLTSTART)
    begin
        vob = tdevice_VRR;
        if (rising_edge_VLTSTART && VLTDONE)
        begin
            VLTDONE = 1'b0;
            #vob VLTDONE = 1'b1;
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Timing control for the Erase Operations
    ///////////////////////////////////////////////////////////////////////////
    time seo;
    time beo32;
    time beo64;
    time ceo;
    event edone_event;

    always @(rising_edge_ESTART)
    begin
        seo   = tdevice_SE;
        beo32 = tdevice_BE1;
        beo64 = tdevice_BE2;
        ceo   = tdevice_CE;
        if ((rising_edge_ESTART) && EDONE)
        begin
            if (Instruct == CE)
            begin
                duration = ceo;
            end
            else if (Instruct == BE_64)
            begin
                duration = beo64;
            end
            else if (Instruct == BE_32)
            begin
                duration = beo32;
            end
            else
            begin
                duration = seo;
            end
            elapsed = 0;
            EDONE = 1'b0;
            ->edone_event;
            start = $time;
        end
    end

    always @(ESUSP_event)
    begin
        if ((ESUSP_event) && ESUSP && (~EDONE))
        begin
            disable edone_process;
            elapsed = $time - start;
            duration = duration - elapsed;
            EDONE = 1'b0;
        end
    end

    always @(ERES_event)
    begin
        if  ((ERES_event) && ERES && (~EDONE))
        begin
            start = $time;
            ->edone_event;
        end
    end

    always @(edone_event)
    begin : edone_process
        EDONE = 1'b0;
        #duration EDONE = 1'b1;
    end

    ///////////////////////////////////////////////////////////////////
    // Process for clock frequency determination
    ///////////////////////////////////////////////////////////////////
    always @(posedge SCK_ipd)
    begin : clock_period
        if (SCK_ipd)
        begin
            SCK_cycle = $time - prev_SCK;
            prev_SCK = $time;
        end
    end 


    ///////////////////////////////////////////////////////////////////////////
    // Main Behavior Process
    // combinational process for next state generation
    ///////////////////////////////////////////////////////////////////////////
    reg rising_edge_PDONE   = 1'b0;
    reg rising_edge_EDONE   = 1'b0;
    reg rising_edge_WDONE   = 1'b0;
    reg rising_edge_VLTDONE = 1'b0;
    reg falling_edge_write  = 1'b0;
    reg rising_edge_DP_out  = 1'b0;

    integer i;
    integer j;

    always @(rising_edge_PoweredUp or falling_edge_write or rising_edge_DP_out 
             or rising_edge_PDONE or rising_edge_WDONE or rising_edge_EDONE or
             ERSSUSP_out_event or ERSRES_out_event or RES_out or 
             PRGSUSP_out_event or PRGRES_out_event or rising_edge_VLTDONE)
    begin: StateGen1

        if (rising_edge_PoweredUp)
            next_state = IDLE;
        else
        begin        
            case (current_state)
                IDLE :
                begin
                    if (falling_edge_write)
                    begin
                        if (Instruct == WRR && (~SRP1 && 
                            (~SRP0 || (SRP0 && WPNeg))))
                        begin
                            if (WEL && ~wren_vlt_flag)
                                next_state = WRITE_SR;
                            else if (~WEL && wren_vlt_flag)
                                next_state = WRITE_SR_V;
                        end
                        else if (Instruct == PP && WEL)
                        begin
                            sect = Address / 16'h1000;
                            sect_tmp_pg = sect;
                            if (Sec_Prot[sect] == 0)
                                next_state = PAGE_PG;
                        end
                        else if (Instruct == QPP && WEL && QE)
                        begin
                            sect = Address / 16'h1000;
                            sect_tmp_pg = sect;
                            if (Sec_Prot[sect] == 0)
                                next_state = PAGE_PG;
                        end
                        else if (Instruct == PG_SCREG && WEL)
                        begin
                            sect = Address / 16'h1000;
                            if ((sect < 4 && sect > 0) && LB[sect-1]==0)
                                next_state = PAGE_PG;
                        end
                        else if (Instruct == ERS_SCREG && WEL)
                        begin
                            sect = Address / 16'h1000;
                            if ((sect <= 3) && LB[sect-1]==0)
                                next_state = SECTOR_ERS;
                        end
                        else if ((Instruct == SE || Instruct == BE_32 || 
                                Instruct == BE_64) && WEL)
                        begin
                            sect = Address / 16'h1000;
                            sect_tmp_ers = sect;
                            if (Sec_Prot[sect] == 0)
                                next_state = SECTOR_ERS;
                        end
                        else if (Instruct == CE && WEL && 
                        ((~CMP && ~BP2 && ~BP1 && ~BP0) || 
                        (CMP && BP2 && BP1 && BP0)))
                            next_state = BULK_ERS;
                        else
                            next_state = IDLE;
                    end
                    else if (rising_edge_DP_out)
                        next_state = DP_DOWN;
                end  // end of IDLE

                WRITE_SR:
                begin
                    if (rising_edge_WDONE)
                        next_state = IDLE;
                end  // end of WRITE_SR

                WRITE_SR_V:
                begin
                    if (rising_edge_VLTDONE)
                        next_state = IDLE;
                end

                PAGE_PG:
                begin
                    if (PRGSUSP_out_event && PRGSUSP_out == 1)
                        next_state = PG_SUSP;
                    else if (rising_edge_PDONE)
                        next_state = IDLE;
                end  // end of PAGE_PG

                PG_SUSP:
                begin
                    if (PRGRES_out_event && PRGRES_out == 1)
                        next_state = PAGE_PG;
                    else if (falling_edge_write)
                    begin 
                        if (Instruct == SE || Instruct == BE_32 ||
                            Instruct == BE_64)
                        begin
                            sect = Address / 16'h1000;
                            if ((Sec_Prot[sect] == 0) && (sect != sect_tmp_pg))
                                next_state = PG_SUSP_ERS;
                        end
                    end
                end  // end of PG_SUSP

                PG_SUSP_ERS:
                begin
                    if (rising_edge_EDONE)
                        next_state = PG_SUSP;
                    else
                        next_state = PG_SUSP_ERS;
                end

                BULK_ERS:
                begin
                    if (rising_edge_EDONE)
                        next_state = IDLE;
                end

                SECTOR_ERS:
                begin
                    if (ERSSUSP_out_event && ERSSUSP_out == 1)
                        next_state = ERS_SUSP;
                    else if (rising_edge_EDONE)
                        next_state = IDLE;
                end

                ERS_SUSP:
                begin
                    if (ERSRES_out_event && ERSRES_out == 1)
                        next_state = SECTOR_ERS;
                    else if (falling_edge_write)
                    begin
                        if (Instruct == PP || (Instruct == QPP && QE))
                        begin
                            sect = Address / 16'h1000;
                            if ((Sec_Prot[sect] == 0)&&(sect != sect_tmp_ers))
                                next_state = ERS_SUSP_PG;
                        end
                        else if (Instruct == PG_SCREG)
                        begin
                            sect = Address / 16'h1000;
                            if ((sect < 4 && sect > 0) && LB[sect-1]==0)
                                next_state = ERS_SUSP_PG;
                        end
                    end
                end

                ERS_SUSP_PG:
                begin
                    if (rising_edge_PDONE)
                        next_state = ERS_SUSP;
                    else
                        next_state = ERS_SUSP_PG;
                end

                DP_DOWN:
                begin
                    if (rising_edge_RES_out)
                        next_state = IDLE;
                end

            endcase  // end case of current_state
        end  // 
    end // end of StateGen1

    ///////////////////////////////////////////////////////////////////////////
    //FSM Output generation and general functionality
    ///////////////////////////////////////////////////////////////////////////
    reg rising_edge_read_out = 1'b0;
    reg Instruct_event       = 1'b0;
    reg change_addr_event    = 1'b0;
    reg current_state_event  = 1'b0;

    integer WData [0:255];
    integer Addr;
    integer Addr_ers;
    integer Addr_tmp;
    integer Addr_tmp_2;
    integer Addr_tmp_3;
    integer Addr_screg;

    always @(oe_event)
    begin
        oe = 1'b1;
        #1000 oe = 1'b0;
    end

    always @(rising_edge_read_out or Instruct or rising_edge_SCK_ipd or
             change_addr_event or oe or current_state_event or Address or
             falling_edge_write or PDONE or rising_edge_WDONE or Instruct_event
             or rising_edge_EDONE or ERSSUSP_out or rising_edge_PoweredUp or
             rising_edge_CSNeg_ipd or rising_edge_RES_out or ERSRES_out or
             PRGSUSP_out or PRGRES_out_event or rising_edge_VLTDONE or
             rising_edge_DP_out or WDONE)

    begin: Functionality
    integer i,j;

        if (rising_edge_read_out)
        begin
            if (PoweredUp == 1'b1)
                ->oe_event;
        end

        if (Instruct_event)
        begin
            read_cnt = 0;
            fast_read = 1'b1;
            dual_read = 1'b0;
            slow_read = 1'b0;
            quad_read = 1'b0;
            sr_read   = 1'b0;
            read_id   = 1'b0;
            pp_quad   = 1'b0;
            if (current_state == IDLE)
            begin
                if (DP_in == 1'b1)
                begin
                    $display ("Command results can be corrupted ");
                end
            end
        end        

        if (rising_edge_PoweredUp)
        begin
            Status_reg1[1] = 1'b0;  // WEL bit
            Status_reg1[0] = 1'b0;  // BUSY bit

            Status_reg2[7] = 1'b0;  // SUS bit
        end

        if (change_addr_event)
        begin
            read_addr = Address;
        end

        if (rising_edge_RES_out)
        begin
            if(RES_out)
            begin
                RES_in = 1'b0;
            end
        end

        case (current_state)
            IDLE :
            begin
                fast_read = 1'b1;
                dual_read = 1'b0;
                slow_read = 1'b0;
                quad_read = 1'b0;
                sr_read = 1'b0;
                res_flag = 1'b0;
                pg_screg_flag = 1'b0;
                ers_screg_flag = 1'b0;
                if (falling_edge_write && ~DP_in)
                begin
                    read_cnt = 0;
                    if (Instruct == WREN)
                        Status_reg1[1] = 1'b1;
                    else if (Instruct == WRDI)
                        Status_reg1[1] = 1'b0;
                    else if (Instruct == WRR)
                    begin
                        if(~SRP1 && (~SRP0 || (SRP0 && WPNeg)))
                        begin
                            if (WEL && ~wren_vlt_flag)
                            begin
                                WSTART = 1'b1;
                                WSTART <= #5 1'b0;
                                Status_reg1[0] = 1'b1;
                            end
                            else if (~WEL && wren_vlt_flag)
                            begin
                                VLTSTART = 1'b1;
                                VLTSTART <= #5 1'b0;
                            end
                        end
                        else
                            Status_reg1[1] = 1'b0;                            
                    end
                    else if ((Instruct == PP || (Instruct == QPP && QE)) 
                            && WEL && PDONE)
                    begin
                        sect = Address / 16'h1000;
                        if (Sec_Prot[sect] == 0)
                        begin
                            PSTART = 1'b1;
                            PSTART <= #5 1'b0;
                            PGSUSP  = 1'b0;
                            PGRES   = 1'b0;
                            Status_reg1[0] = 1'b1;
                            SA      = sect;
                            Addr    = Address;
                            Addr_tmp= Address;
                            wr_cnt  = Byte_number;
                            for (i=wr_cnt;i>=0;i=i-1)
                            begin
                                if (Viol != 0)
                                    WData[i] = -1;
                                else
                                    WData[i] = WByte[i];
                            end
                        end
                        else
                            Status_reg1[1] = 1'b0;
                    end
                    else if (Instruct == PG_SCREG && WEL)
                    begin
                        sect = Address / 16'h1000;
                        if ((sect <= 3) && LB[sect-1]==0)
                        begin
                            PSTART = 1'b1;
                            PSTART <= #5 1'b0;
                            PGSUSP  = 1'b0;
                            PGRES   = 1'b0;
                            Status_reg1[0] = 1'b1;
                            SA      = sect;
                            wr_cnt  = Byte_number;
                            Addr_screg = Address % 16'h1000;
                            pg_screg_flag = 1'b1;
                            for (i=wr_cnt;i>=0;i=i-1)
                            begin
                                if (Viol != 0)
                                    WData[i] = -1;
                                else
                                    WData[i] = WByte[i];
                            end
                        end
                        else
                        begin
                            Status_reg1[1] = 1'b0;
                        end
                    end
                    else if ((Instruct == SE || Instruct == BE_32 || 
                                Instruct == BE_64) && WEL)
                    begin
                        sect = Address / 16'h1000;
                        if (Sec_Prot[sect] == 0)
                        begin
                            ESTART = 1'b1;
                            ESTART <= #5 1'b0;
                            ESUSP     = 1'b0;
                            ERES      = 1'b0;
                            Status_reg1[0] = 1'b1;
                            Addr_ers = Address;
                        end
                        else
                            Status_reg1[1] = 1'b0;
                    end
                    else if (Instruct == CE && WEL)
                    begin
//                         if ((~CMP && ~BP2 && ~BP1 && ~BP0) || 
//                            (CMP && BP2 && BP1 && BP0))
                        if (Sec_Prot == 0)
                        begin
                            ESTART = 1'b1;
                            ESTART <= #5 1'b0;
                            ESUSP     = 1'b0;
                            ERES      = 1'b0;
                            Status_reg1[0] = 1'b1;
                        end
                        else
                            Status_reg1[1] = 1'b0;
                    end
                    else if (Instruct == ERS_SCREG && WEL)
                    begin
                        sect = Address / 16'h1000;
                        if ((sect <= 3) && LB[sect-1]==0)
                        begin
                            ESTART = 1'b1;
                            ESTART <= #5 1'b0;
                            ESUSP     = 1'b0;
                            ERES      = 1'b0;
                            Status_reg1[0] = 1'b1;
                            SA      = sect;
                            ers_screg_flag = 1'b1;
                        end
                        else
                            Status_reg1[1] = 1'b0;
                    end
                    else if (Instruct == DP)
                    begin
                        RES_in <= 1'b0;
                        DP_in  <= 1'b1;
                    end
                end  // end of falling_edge_write
                else if (oe && ~DP_in)
                begin
                    if (Instruct == RDSR)
                    begin //Read Status Register
                        sr_read = 1'b1;
                        SOut_zd = Status_reg1[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                    else if (Instruct == RDSR2)
                    begin
                        sr_read = 1'b1;
                        SOut_zd = Status_reg2[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                    else if (Instruct == READ || Instruct == FAST_READ)
                    begin
                        if (Instruct == READ)
                        begin
                            fast_read = 1'b0;
                            dual_read = 1'b0;
                            slow_read = 1'b1;
                            quad_read = 1'b0;
                            sr_read   = 1'b0;
                        end
                        else
                        begin
                            fast_read = 1'b1;
                            dual_read = 1'b0;
                            slow_read = 1'b0;
                            quad_read = 1'b0;
                            sr_read   = 1'b0;
                        end
                        if (Mem[read_addr] !== -1)
                        begin
                            data_out[7:0] = Mem[read_addr];
                            SOut_zd  = data_out[7-read_cnt];
                        end
                        else
                        begin
                            SOut_zd  = 8'bx;
                        end
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                        begin
                            read_cnt = 0;
                            if (read_addr == AddrRANGE)
                                read_addr = 0;
                            else
                                read_addr = read_addr + 1;
                        end
                    end
                    else if (Instruct==FAST_DREAD || Instruct==FAST_DREAD_2)
                    begin
                        fast_read = 1'b0;
                        dual_read = 1'b1;
                        slow_read = 1'b0;
                        quad_read = 1'b0;
                        sr_read   = 1'b0;
                        data_out[7:0] = Mem[read_addr];
                        SOut_zd       = data_out[7-2*read_cnt];
                        SIOut_zd      = data_out[6-2*read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 4)
                        begin
                            read_cnt = 0;
                            if (read_addr == AddrRANGE)
                                read_addr = 0;
                            else
                                read_addr = read_addr + 1;
                        end
                    end
                    else if ((Instruct==FAST_QREAD || Instruct==FAST_QREAD_4 ||
                              Instruct==W_QREAD    || Instruct==WOCT_QREAD) 
                            && QE)
                    begin
                        if ((Instruct==W_QREAD && Address[0]) ||
                           (Instruct==WOCT_QREAD && ~(Address[3:0] == 4'h0)))
                        begin
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 2)
                            begin
                                read_cnt = 0;
                                $display("Word Read could not execute");
                                $display("Wrong Read Address");
                            end
                        end
                        else
                        begin
                            fast_read = 1'b0;
                            dual_read = 1'b0;
                            slow_read = 1'b0;
                            quad_read = 1'b1;
                            sr_read   = 1'b0;
                            data_out[7:0] = Mem[read_addr];
                            HOLDNegOut_zd = data_out[7-4*read_cnt];
                            WPNegOut_zd   = data_out[6-4*read_cnt];
                            SOut_zd       = data_out[5-4*read_cnt];
                            SIOut_zd      = data_out[4-4*read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 2)
                            begin
                                read_cnt = 0;
                                if (wrap_byte[4]==1'b0 && 
                                (Instruct==FAST_QREAD_4 || Instruct==W_QREAD))
                                begin
                                    ADDRHILO_WRAP(AddrLo_wrap,AddrHi_wrap,
                                                  Address,w_size);
                                    if (read_addr == AddrHi_wrap)
                                        read_addr = AddrLo_wrap;
                                    else
                                        read_addr = read_addr + 1;
                                end
                                else
                                begin
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                            end
                        end
                    end
                    else if (Instruct==RDID || Instruct==RDID_DUAL || 
                             Instruct==RDID_QUAD)
                    begin
                        if (read_addr % 2 == 0)
                        begin
                            ident_out2 = {Manuf_ID,Device_ID1};
                        end
                        else
                        begin
                            ident_out2 = {Device_ID1,Manuf_ID};
                        end
                        read_id = 1'b1;
                        if (Instruct == RDID)
                        begin
                            fast_read = 1'b1;
                            dual_read = 1'b0;
                            slow_read = 1'b0;
                            quad_read = 1'b0;
                            sr_read   = 1'b0;
                            DataDriveOut_SO = ident_out2[15-read_cnt];
                            read_cnt  = read_cnt + 1;
                            if (read_cnt == 16)
                                read_cnt = 0;
                        end
                        else if (Instruct == RDID_DUAL)
                        begin
                            fast_read = 1'b0;
                            dual_read = 1'b1;
                            slow_read = 1'b0;
                            quad_read = 1'b0;
                            sr_read   = 1'b0;
                            DataDriveOut_SO  = ident_out2[15-2*read_cnt];
                            DataDriveOut_SI = ident_out2[14-2*read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                        else //  (Instruct == RDID_QUAD)
                        begin
                            fast_read = 1'b0;
                            dual_read = 1'b0;
                            slow_read = 1'b0;
                            quad_read = 1'b1;
                            sr_read   = 1'b0;
                            DataDriveOut_HOLD = ident_out2[15-4*read_cnt];
                            DataDriveOut_WP   = ident_out2[14-4*read_cnt];
                            DataDriveOut_SO       = ident_out2[13-4*read_cnt];
                            DataDriveOut_SI      = ident_out2[12-4*read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 4)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RD_UNIQ_ID)
                    begin
                    // unique ID number is not in data sheet
                        read_id = 1'b1;
                        DataDriveOut_SO = unique_id[63-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 64)
                            read_cnt = 0;
                    end
                    else if (Instruct == RDIDJ)
                    begin
                        read_id = 1'b1;
                        ident_out = {Manuf_ID,Device_ID2,Device_ID3};
                        DataDriveOut_SO = ident_out[23-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 24)
                            read_cnt = 0;
                    end
                    else if (Instruct == RD_SFDP)
                    begin
                        sfdp_addr = read_addr / 12'h100;
                        if (sfdp_addr == 0)
                        begin
                            Addr_tmp_2 = (read_addr % 12'h100);
                            data_out[7:0] = SFDP_array[Addr_tmp_2];
                            SOut_zd  = data_out[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                if (read_addr == SFDP_HiAddr)
                                    read_addr = 0;
                                else
                                    read_addr = read_addr + 1;
                            end
                        end
                        else
                        begin
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                $display("Given SFDP address is out of range");
                            end
                        end
                    end
                    else if (Instruct == RD_SCREG)
                    begin
                        Addr_tmp_2 = read_addr / 12'h100;
                        Addr_tmp_3 = read_addr % 12'h100;
                        if (Addr_tmp_2 == 16)
                        begin
                            // Security Register No.1
                            data_out[7:0] = Security_Reg1[Addr_tmp_3];
                            SOut_zd  = data_out[7-read_cnt];
                            read_cnt = read_cnt + 1;
                        end
                        else if (Addr_tmp_2 == 32)
                        begin
                            // Security Register No.2
                            data_out[7:0] = Security_Reg2[Addr_tmp_3];
                            SOut_zd  = data_out[7-read_cnt];
                            read_cnt = read_cnt + 1;
                        end
                        else if (Addr_tmp_2 == 48)
                            // Security Register No.2
                        begin
                            data_out[7:0] = Security_Reg3[Addr_tmp_3];
                            SOut_zd  = data_out[7-read_cnt];
                            read_cnt = read_cnt + 1;
                        end
                        else
                        begin
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                $display("Given Security Register Read ");
                                $display("address is out of range ");
                            end
                        end
                        if (read_cnt == 8)
                        begin
                            read_cnt = 0;
                            if (read_addr % 256 == SecReg_HiAddr)
                                read_addr = (read_addr/256)*(SecReg_HiAddr+1);
                            else
                                read_addr = read_addr + 1;
                        end
                    end
                    else if (Instruct == RES_RD_ID)
                    begin
                        read_id = 1'b1;
                        data_out[7:0] = Device_ID1;
                        DataDriveOut_SO = data_out[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end  // end of oe
                else if (rising_edge_DP_out)
                    DP_in = 1'b0;
            end  // end of IDLE state

            WRITE_SR:
            begin
                if (WDONE && !WSTART)	//A. Z. bugfix
                begin
                    Status_reg1[0] = 1'b0;
                    Status_reg1[1] = 1'b0;

                    Status_reg1[7:2] = Status_reg1_in[7:2];
                    Status_reg2[6] = Status_reg2_in[6];
                    Status_reg2[1] = Status_reg2_in[1];
                    // SRP1 bit will only change value from '0' to '1'
                    // if SRP1 is '1' than Status Register is protected
                    //and is not possible to write it
                    Status_reg2[0] = Status_reg2_in[0];
                    for(i=5;i>=3;i=i-1)
                    begin
                        if (Status_reg2[i] == 1'b0)
                            Status_reg2[i] = Status_reg2_in[i];
                        else
                        begin
                            $display("LB bit is set to '1'");
                            $display("No change allowed");
                        end
                    end
                    change_prot_bits = 1'b1;
                    #1000 change_prot_bits = 1'b0;
                end  // end of WDONE

                if (oe)
                begin
                    if (Instruct == RDSR)
                    begin
                    //Read Status Register 1
                        sr_read   = 1'b1;
                        SOut_zd = Status_reg1[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end   // end of oe
            end  // end of WRITE_SR 

            WRITE_SR_V:
            begin
                if (VLTDONE)
                begin
                    Status_reg1[7:2] = Status_reg1_in[7:2];
                    Status_reg2[6] = Status_reg2_in[6];
                    Status_reg2[1] = Status_reg2_in[1];
                    // SRP1 bit will only change value from '0' to '1'
                    // if SRP1 is '1' than Status Register is protected
                    //and is not possible to write it
                    Status_reg2[0] = Status_reg2_in[0];
                    for(i=5;i>=3;i=i-1)
                    begin
                        if (Status_reg2[i] == 1'b0)
                            Status_reg2[i] = Status_reg2_in[i];
                        else
                        begin
                            $display("LB bit is set to '1'");
                            $display("No change allowed");
                        end
                    end
                    change_prot_bits = 1'b1;
                    #1000 change_prot_bits = 1'b0;
                    wren_vlt_flag = 1'b0;
                end
            end

            PAGE_PG,
            ERS_SUSP_PG:
            begin
                if (current_state_event && ~PDONE)
                begin
                    if (Instruct !== PG_SCREG)
                    begin
                        ADDRHILO_PG(AddrLo, AddrHi, Addr);
                    end
                    cnt = 0;

                    for (i=0;i<=wr_cnt;i=i+1)
                    begin
                        new_int = WData[i];
                        if (Instruct == PG_SCREG)
                        begin
                            if (sect == 1)
                                old_int = Security_Reg1[Addr_screg + i - cnt];
                            else if (sect == 2)
                                old_int = Security_Reg2[Addr_screg + i - cnt];
                            else
                                old_int = Security_Reg3[Addr_screg + i - cnt];
                        end
                        else
                        begin
                            old_int = Mem[Addr + i - cnt];
                        end
                        if (new_int > -1)
                        begin
                            new_bit = new_int;
                            if (old_int > -1)
                            begin
                                old_bit = old_int;
                                for(j=0;j<=7;j=j+1)
                                begin
                                    if (~old_bit[j])
                                        new_bit[j]=1'b0;
                                end
                                new_int=new_bit;
                            end
                            WData[i]= new_int;
                        end
                        else
                        begin
                            WData[i] = -1;
                        end
                        if (Instruct == PG_SCREG)
                        begin
                            if (sect == 1)
                                Security_Reg1[Addr_screg + i - cnt] = - 1;
                            else if (sect == 2)
                                Security_Reg2[Addr_screg + i - cnt] = - 1;
                            else
                                Security_Reg3[Addr_screg + i - cnt] = - 1;
                        end
                        else
                            Mem[Addr + i - cnt] = - 1;
                        if ((Addr + i) == AddrHi)
                        begin

                            Addr = AddrLo;
                            cnt = i + 1;
                        end
                    end
                    cnt = 0;
                end  // end of current_state_event

                if (PDONE)
                begin
                    if (current_state !== ERS_SUSP_PG)
                    begin
                        Status_reg1[0] = 1'b0;
                    end
                    Status_reg1[1] = 1'b0;
                    for (i=0;i<=wr_cnt;i=i+1)
                    begin
                        if (pg_screg_flag )
                        begin
                            if (sect == 1)
                                Security_Reg1[Addr_screg + i - cnt] = WData[i];
                            else if (sect == 2)
                                Security_Reg2[Addr_screg + i - cnt] = WData[i];
                            else
                                Security_Reg3[Addr_screg + i - cnt] = WData[i];

                            if ((Addr_screg + i) == SecReg_HiAddr)
                            begin
                                Addr_screg = SecReg_LoAddr;
                                cnt = i + 1;
                            end
                        end
                        else
                        begin
                            Mem[Addr_tmp + i - cnt] = WData[i];
                            if ((Addr_tmp + i) == AddrHi)
                            begin
                                Addr_tmp = AddrLo;
                                cnt = i + 1;
                            end
                        end
                    end
                end  // end of PDONE

                if (Instruct == ERS_PG_SUSP && current_state == PAGE_PG 
                                                            && ~susp_flag)
                begin
                    PGSUSP = 1'b1;
                    PGSUSP <= #1000 1'b0;
                    PRGSUSP_in = 1'b1;
                end

                if (oe)
                begin
                    if (Instruct == RDSR)
                    begin
                    //Read Status Register 1
                        sr_read   = 1'b1;
                        SOut_zd = Status_reg1[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
            end  // end of PAGE_PG

            PG_SUSP:
            begin
                fast_read = 1'b1;
                dual_read = 1'b0;
                slow_read = 1'b0;
                quad_read = 1'b0;
                sr_read   = 1'b0;
                if (PRGSUSP_out == 1 && ~(Instruct == ERS_PG_RES))
                begin
                    PRGSUSP_in = 1'b0;
                    //The BUSY bit in the Status Register will indicate that
                    //the device is ready for another operation.
                    Status_reg1[0] = 1'b0;
                    //The Suspend (SUS) bit in the Status Register2 will
                    //be set to the logical “1” state to indicate that the
                    //program operation has been suspended.
                    Status_reg2[7] = 1'b1;
                end
                if (PRGRES_out_event && PRGRES_out == 1)
                begin
                   PRGRES_in = 1'b0;
                   Status_reg1[0] = 1'b1;
                end
                if (SUS)
                begin
                    if (falling_edge_write)
                    begin
                        if (Instruct == ERS_PG_RES)
                        begin
                            Status_reg2[7] = 1'b0;
                            PRGRES_in = 1'b1;
                            PGRES = 1'b1;
                            PGRES <= #1000 1'b0;
                        end
                        else if ((Instruct == SE || Instruct == BE_32 || 
                                Instruct == BE_64) && WEL)
                        begin
                            sect = Address / 16'h1000;
                            if (sect !== sect_tmp_pg && Sec_Prot[sect] == 0)
                            begin
                                ESTART = 1'b1;
                                ESTART <= #5 1'b0;
                                ESUSP     = 1'b0;
                                ERES      = 1'b0;
                                Status_reg1[0] = 1'b1;
                                Addr_ers = Address;
                            end
                            else
                            begin
                                Status_reg1[0] = 1'b0;
                                $display("Can't erase sector/block");
                                $display("Block is protected or suspended");
                            end
                        end
                    end
                    else if (oe)
                    begin
                        if (Instruct == RDSR)
                        begin
                            //Read Status Register 1
                            sr_read   = 1'b1;
                            SOut_zd = Status_reg1[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                        else if (Instruct == RDSR2)
                        begin
                            //Read Status Register 2
                            sr_read   = 1'b1;
                            SOut_zd = Status_reg2[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                        else if (Instruct == READ || Instruct == FAST_READ)
                        begin
                            if (sect_tmp_pg !== read_addr / 16'h1000)
                            begin
                                if (Instruct == READ)
                                begin
                                    fast_read = 1'b0;
                                    dual_read = 1'b0;
                                    slow_read = 1'b1;
                                    quad_read = 1'b0;
                                    sr_read   = 1'b0;
                                end
                                else
                                begin
                                    fast_read = 1'b1;
                                    dual_read = 1'b0;
                                    slow_read = 1'b0;
                                    quad_read = 1'b0;
                                    sr_read   = 1'b0;
                                end
                                if (Mem[read_addr] !== -1)
                                begin
                                    data_out[7:0] = Mem[read_addr];
                                    SOut_zd  = data_out[7-read_cnt];
                                end
                                else
                                begin
                                    SOut_zd  = 8'bx;
                                end
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    $display("Can't read suspended sector");
                                    read_cnt = 0;
                                end
                            end
                        end
                        else if (Instruct==FAST_DREAD || 
                                 Instruct==FAST_DREAD_2)
                        begin
                            if (sect_tmp_pg !== read_addr / 16'h1000)
                            begin
                                fast_read = 1'b0;
                                dual_read = 1'b1;
                                slow_read = 1'b0;
                                quad_read = 1'b0;
                                sr_read   = 1'b0;
                                if (Mem[read_addr] !== -1)
                                begin
                                    data_out[7:0] = Mem[read_addr];
                                    SOut_zd       = data_out[7-2*read_cnt];
                                    SIOut_zd      = data_out[6-2*read_cnt];
                                end
                                else
                                begin
                                    SOut_zd       = 1'bx;
                                    SIOut_zd      = 1'bx;
                                end
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 4)
                                begin
                                    read_cnt = 0;
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 4)
                                begin
                                    $display("Can't read suspended sector");
                                    read_cnt = 0;
                                end
                            end
                        end
                        else if ((Instruct==FAST_QREAD || Instruct==W_QREAD 
                             || Instruct==FAST_QREAD_4 || Instruct==WOCT_QREAD) 
                                && QE)
                        begin
                            if (sect_tmp_pg !== read_addr / 16'h1000)
                            begin
                                if ((Instruct==W_QREAD && Address[0]) ||
                                (Instruct==WOCT_QREAD &&
                                         ~(Address[3:0] == 4'h0)))
                                begin
                                    read_cnt = read_cnt + 1;
                                    if (read_cnt == 2)
                                    begin
                                        read_cnt = 0;
                                        $display("Word Read can't execute");
                                        $display("Wrong Read Address");
                                    end
                                end
                                else
                                begin
                                    fast_read = 1'b0;
                                    dual_read = 1'b0;
                                    slow_read = 1'b0;
                                    quad_read = 1'b1;
                                    sr_read   = 1'b0;
                                    data_out[7:0] = Mem[read_addr];
                                    HOLDNegOut_zd = data_out[7-4*read_cnt];
                                    WPNegOut_zd   = data_out[6-4*read_cnt];
                                    SOut_zd       = data_out[5-4*read_cnt];
                                    SIOut_zd      = data_out[4-4*read_cnt];
                                    read_cnt = read_cnt + 1;
                                    if (read_cnt == 2)
                                    begin
                                        read_cnt = 0;
                                        if (wrap_byte[4]==0 && 
                                        (Instruct==FAST_QREAD_4 || 
                                         Instruct==W_QREAD))
                                        begin
                                            ADDRHILO_WRAP(AddrLo_wrap,
                                                AddrHi_wrap, Address,w_size);
                                            if (read_addr == AddrHi_wrap)
                                                read_addr = AddrLo_wrap;
                                            else
                                                read_addr = read_addr + 1;
                                        end
                                        else
                                        begin
                                            if (read_addr == AddrRANGE)
                                                read_addr = 0;
                                            else
                                                read_addr = read_addr + 1;
                                        end
                                    end
                                end
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 2)
                                begin
                                    $display("Can't read suspended sector");
                                    read_cnt = 0;
                                end
                            end
                        end
                        else if (Instruct==RDID || Instruct==RDID_DUAL || 
                                Instruct==RDID_QUAD)
                        begin
                            if (read_addr % 2 == 0)
                            begin
                                ident_out2 = {Manuf_ID,Device_ID1};
                            end
                            else
                            begin
                                ident_out2 = {Device_ID1,Manuf_ID};
                            end
                            read_id = 1'b1;
                            if (Instruct == RDID)
                            begin
                                fast_read = 1'b1;
                                dual_read = 1'b0;
                                slow_read = 1'b0;
                                quad_read = 1'b0;
                                sr_read   = 1'b0;
                                DataDriveOut_SO = ident_out2[15-read_cnt];
                                read_cnt  = read_cnt + 1;
                                if (read_cnt == 16)
                                    read_cnt = 0;
                            end
                            else if (Instruct == RDID_DUAL)
                            begin
                                fast_read = 1'b0;
                                dual_read = 1'b1;
                                slow_read = 1'b0;
                                quad_read = 1'b0;
                                sr_read   = 1'b0;
                                DataDriveOut_SO = ident_out2[15-2*read_cnt];
                                DataDriveOut_SI = ident_out2[14-2*read_cnt];
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                    read_cnt = 0;
                            end
                            else //  (Instruct == RDID_QUAD)
                            begin
                                fast_read = 1'b0;
                                dual_read = 1'b0;
                                slow_read = 1'b0;
                                quad_read = 1'b1;
                                sr_read   = 1'b0;
                                DataDriveOut_HOLD = ident_out2[15-4*read_cnt];
                                DataDriveOut_WP   = ident_out2[14-4*read_cnt];
                                DataDriveOut_SO   = ident_out2[13-4*read_cnt];
                                DataDriveOut_SI   = ident_out2[12-4*read_cnt];
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 4)
                                    read_cnt = 0;
                            end
                        end
                        else if (Instruct == RD_UNIQ_ID)
                        begin
                        // unique ID number is not in data sheet
                            read_id = 1'b1;
                            DataDriveOut_SO = unique_id[63-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 64)
                                read_cnt = 0;
                        end
                        else if (Instruct == RDIDJ)
                        begin
                            read_id = 1'b1;
                            ident_out = {Manuf_ID,Device_ID2,Device_ID3};
                            DataDriveOut_SO = ident_out[23-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 24)
                                read_cnt = 0;
                        end
                        else if (Instruct == RD_SFDP)
                        begin
                            sfdp_addr = read_addr / 12'h100;
                            if (sfdp_addr == 0)
                            begin
                                Addr_tmp_2 = (read_addr % 12'h100);
                                data_out[7:0] = SFDP_array[Addr_tmp_2];
                                SOut_zd  = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    if (read_addr == SFDP_HiAddr)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    $display("SFDP address is out of range");
                                end
                            end
                        end
                        else if (Instruct == RD_SCREG)
                        begin
                            Addr_tmp_2 = read_addr / 12'h100;
                            Addr_tmp_3 = read_addr % 12'h100;
                            if (Addr_tmp_2 == 16)
                            begin
                                // Security Register No.1
                                data_out[7:0] = Security_Reg1[Addr_tmp_3];
                                SOut_zd  = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                            end
                            else if (Addr_tmp_2 == 32)
                            begin
                                // Security Register No.2
                                data_out[7:0] = Security_Reg2[Addr_tmp_3];
                                SOut_zd  = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                            end
                            else if (Addr_tmp_2 == 48)
                                // Security Register No.2
                            begin
                                data_out[7:0] = Security_Reg3[Addr_tmp_3];
                                SOut_zd  = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    $display("Given Security Register Read ");
                                    $display("address is out of range ");
                                end
                            end

                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                if (read_addr % 256 == SecReg_HiAddr)
                                    read_addr=(read_addr/256)*
                                                (SecReg_HiAddr+1);
                                else
                                    read_addr = read_addr + 1;
                            end
                        end
                    end  // end of 'oe'
                end
            end // end of PG_SUSP

            SECTOR_ERS,
            PG_SUSP_ERS:
            begin
                if (current_state_event && ~EDONE)
                begin
                    if (Instruct == SE)
                        ADDRHILO_SEC4(AddrLo_ers, AddrHi_ers, Addr_ers);
                    else if (Instruct == BE_32)
                        ADDRHILO_SEC32(AddrLo_ers, AddrHi_ers, Addr_ers);
                    else if (Instruct == BE_64)
                    begin
                        ADDRHILO_SEC64(AddrLo_ers, AddrHi_ers, Addr_ers);
                    end
                    if (Instruct !== ERS_SCREG)
                    begin
                        for (i=AddrLo_ers;i<=AddrHi_ers;i=i+1)
                        begin
                            Mem[i] = -1;
                        end
                    end
                    else
                    begin
                        if (sect == 1)
                        begin
                            for(i=SecReg_LoAddr;i<=SecReg_HiAddr;i=i+1)
                            begin
                                Security_Reg1[i] = -1;
                            end
                        end
                        else if (sect == 2)
                        begin
                            for(i=SecReg_LoAddr;i<=SecReg_HiAddr;i=i+1)
                            begin
                                Security_Reg2[i] = -1;
                            end
                        end
                        else
                        begin
                            for(i=SecReg_LoAddr;i<=SecReg_HiAddr;i=i+1)
                            begin
                                Security_Reg3[i] = -1;
                            end
                        end
                    end
                end

                if (EDONE == 1)
                begin
                    if (current_state !== PG_SUSP_ERS)
                    begin
                        Status_reg1[0] = 1'b0;
                    end
                    Status_reg1[1] = 1'b0;
                    if (ers_screg_flag )
                    begin
                        if (sect == 1)
                        begin
                            for(i=SecReg_LoAddr;i<=SecReg_HiAddr;i=i+1)
                            begin
                                Security_Reg1[i] = MaxData;
                            end
                        end
                        else if (sect == 2)
                            for(i=SecReg_LoAddr;i<=SecReg_HiAddr;i=i+1)
                            begin
                                Security_Reg2[i] = MaxData;
                            end
                        else
                            for(i=SecReg_LoAddr;i<=SecReg_HiAddr;i=i+1)
                            begin
                                Security_Reg3[i] = MaxData;
                            end

                    end
                    else
                    begin
                        for (i=AddrLo_ers;i<=AddrHi_ers;i=i+1)
                        begin
                            Mem[i] = MaxData;
                        end
                    end
                end

                if (Instruct == ERS_PG_SUSP && current_state == SECTOR_ERS)
                begin
                    ESUSP = 1'b1;
                    ESUSP <= #1000 1'b0;
                    ERSSUSP_in = 1'b1;
                end
                if (oe)
                begin
                    if (Instruct == RDSR)
                    begin
                    //Read Status Register 1
                        sr_read   = 1'b1;
                        SOut_zd = Status_reg1[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
            end  // end of SECTOR_ERS

            BULK_ERS:
            begin
                if (current_state_event && ~EDONE)
                begin
                    for (i=0;i<=AddrRANGE;i=i+1)
                    begin
                        Mem[i] = -1;
                    end
                end
                if (EDONE == 1)
                begin
                    Status_reg1[0] = 1'b0;
                    Status_reg1[1] = 1'b0;
                    for (i=0;i<=AddrRANGE;i=i+1)
                    begin
                        Mem[i] = MaxData;
                    end
                end
                if (oe)
                begin
                    if (Instruct == RDSR)
                    begin
                    //Read Status Register 1
                        sr_read   = 1'b1;
                        SOut_zd = Status_reg1[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
            end  // end of BULK_ERS

            ERS_SUSP:
            begin
                fast_read = 1'b1;
                dual_read = 1'b0;
                slow_read = 1'b0;
                quad_read = 1'b0;
                sr_read   = 1'b0;
                if (ERSSUSP_out == 1 && ~(Instruct == ERS_PG_RES))
                begin
                    ERSSUSP_in = 1'b0;
                    //The BUSY bit in the Status Register will indicate that
                    //the device is ready for another operation.
                    Status_reg1[0] = 1'b0;
                    //The Suspend (SUS) bit in the Status Register2 will
                    //be set to the logical “1” state to indicate that the
                    //program operation has been suspended.
                    Status_reg2[7] = 1'b1;
                end
                if (ERSRES_out_event && ERSRES_out == 1)
                begin
                   ERSRES_in = 1'b0;
                   Status_reg1[0] = 1'b1;
                end
                if (SUS)
                begin
                    if (falling_edge_write)
                    begin
                        if (Instruct == ERS_PG_RES)
                        begin
                            Status_reg2[7] = 1'b0;
                            ERSRES_in = 1'b1;
                            ERES = 1'b1;
                            ERES <= #1000 1'b0;
                        end
                        else if ((Instruct == PP || (Instruct==QPP && QE))
                                 && WEL)
                        begin
                            sect = Address / 16'h1000;
                            if (sect !== sect_tmp_ers && Sec_Prot[sect]==0)
                            begin
                                PSTART = 1'b1;
                                PSTART <= #5 1'b0;
                                PGSUSP  = 1'b0;
                                PGRES   = 1'b0;
                                Status_reg1[0] = 1'b1;
                                SA      = sect;
                                Addr    = Address;
                                Addr_tmp= Address;
                                wr_cnt  = Byte_number;
                                for (i=wr_cnt;i>=0;i=i-1)
                                begin
                                    if (Viol != 0)
                                        WData[i] = -1;
                                    else
                                        WData[i] = WByte[i];
                                end
                            end
                            else
                            begin
                                Status_reg1[0] = 1'b0;
                                $display("Can't program sector/block");
                                $display("Block is protected or suspended");
                            end
                        end
                        else if (Instruct == PG_SCREG)
                        begin
                            sect = Address / 16'h1000;
                            if ((sect <= 3 && sect >=1) && LB[sect-1]==0)
                            begin
                                PSTART = 1'b1;
                                PSTART <= #5 1'b0;
                                PGSUSP  = 1'b0;
                                PGRES   = 1'b0;
                                Status_reg1[0] = 1'b1;
                                SA      = sect;
                                wr_cnt  = Byte_number;
                                Addr_screg = Address % 16'h1000;
                                pg_screg_flag = 1'b1;
                                for (i=wr_cnt;i>=0;i=i-1)
                                begin
                                    if (Viol != 0)
                                        WData[i] = -1;
                                    else
                                        WData[i] = WByte[i];
                                end
                            end
                            else
                                Status_reg1[1] = 1'b0;
                        end
                    end
                    else if (oe)
                    begin
                        if (Instruct == RDSR)
                        begin
                            //Read Status Register 1
                            sr_read   = 1'b1;
                            SOut_zd = Status_reg1[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                        else if (Instruct == RDSR2)
                        begin
                            //Read Status Register 2
                            sr_read   = 1'b1;
                            SOut_zd = Status_reg2[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                        else if (Instruct == READ || Instruct == FAST_READ)
                        begin
                            if (sect !== read_addr / 16'h1000)
                            begin
                                if (Instruct == READ)
                                begin
                                    fast_read = 1'b0;
                                    dual_read = 1'b0;
                                    slow_read = 1'b1;
                                    quad_read = 1'b0;
                                    sr_read   = 1'b0;
                                end
                                else
                                begin
                                    fast_read = 1'b1;
                                    dual_read = 1'b0;
                                    slow_read = 1'b0;
                                    quad_read = 1'b0;
                                    sr_read   = 1'b0;
                                end
                                if (Mem[read_addr] !== -1)
                                begin
                                    data_out[7:0] = Mem[read_addr];
                                    SOut_zd  = data_out[7-read_cnt];
                                end
                                else
                                begin
                                    SOut_zd  = 8'bx;
                                end
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    $display("Can't read suspended sector");
                                    read_cnt = 0;
                                end
                            end
                        end
                        else if (Instruct==FAST_DREAD || 
                                 Instruct==FAST_DREAD_2)
                        begin
                            if (sect !== read_addr / 16'h1000)
                            begin
                                fast_read = 1'b0;
                                dual_read = 1'b1;
                                slow_read = 1'b0;
                                quad_read = 1'b0;
                                sr_read   = 1'b0;
                                if (Mem[read_addr] !== -1)
                                begin
                                    data_out[7:0] = Mem[read_addr];
                                    SOut_zd       = data_out[7-2*read_cnt];
                                    SIOut_zd      = data_out[6-2*read_cnt];
                                end
                                else
                                begin
                                    SOut_zd       = 1'bx;
                                    SIOut_zd      = 1'bx;
                                end
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 4)
                                begin
                                    read_cnt = 0;
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 4)
                                begin
                                    $display("Can't read suspended sector");
                                    read_cnt = 0;
                                end
                            end
                        end
                        else if ((Instruct==FAST_QREAD || Instruct==W_QREAD 
                             || Instruct==FAST_QREAD_4 || Instruct==WOCT_QREAD) 
                                && QE)
                        begin
                            if (sect_tmp_ers !== read_addr / 16'h1000)
                            begin
                                if ((Instruct==W_QREAD && Address[0]) ||
                                (Instruct==WOCT_QREAD && 
                                            ~(Address[3:0]==4'h0)))
                                begin
                                    read_cnt = read_cnt + 1;
                                    if (read_cnt == 2)
                                    begin
                                        read_cnt = 0;
                                        $display("Word Read can't execute");
                                        $display("Wrong Read Address");
                                    end
                                end
                                else
                                begin
                                    fast_read = 1'b0;
                                    dual_read = 1'b0;
                                    slow_read = 1'b0;
                                    quad_read = 1'b1;
                                    sr_read   = 1'b0;
                                    data_out[7:0] = Mem[read_addr];
                                    HOLDNegOut_zd = data_out[7-4*read_cnt];
                                    WPNegOut_zd   = data_out[6-4*read_cnt];
                                    SOut_zd       = data_out[5-4*read_cnt];
                                    SIOut_zd      = data_out[4-4*read_cnt];
                                    read_cnt = read_cnt + 1;
                                    if (read_cnt == 2)
                                    begin
                                        read_cnt = 0;
                                        if (wrap_byte[4]==0 && 
                                           (Instruct==FAST_QREAD_4 
                                           || Instruct==W_QREAD))
                                        begin
                                            ADDRHILO_WRAP(AddrLo_wrap,
                                            AddrHi_wrap,Address,w_size);
                                            if (read_addr == AddrHi_wrap)
                                                read_addr = AddrLo_wrap;
                                            else
                                                read_addr = read_addr + 1;
                                        end
                                        else
                                        begin
                                            if (read_addr == AddrRANGE)
                                                read_addr = 0;
                                            else
                                                read_addr = read_addr + 1;
                                        end
                                    end
                                end
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 2)
                                begin
                                    $display("Can't read suspended sector");
                                    read_cnt = 0;
                                end
                            end
                        end
                        else if (Instruct==RDID || Instruct==RDID_DUAL || 
                                Instruct==RDID_QUAD)
                        begin
                            if (read_addr % 2 == 0)
                            begin
                                ident_out2 = {Manuf_ID,Device_ID1};
                            end
                            else
                            begin
                                ident_out2 = {Device_ID1,Manuf_ID};
                            end
                            read_id = 1'b1;
                            if (Instruct == RDID)
                            begin
                                fast_read = 1'b1;
                                dual_read = 1'b0;
                                slow_read = 1'b0;
                                quad_read = 1'b0;
                                sr_read   = 1'b0;
                                DataDriveOut_SO = ident_out2[15-read_cnt];
                                read_cnt  = read_cnt + 1;
                                if (read_cnt == 16)
                                    read_cnt = 0;
                            end
                            else if (Instruct == RDID_DUAL)
                            begin
                                fast_read = 1'b0;
                                dual_read = 1'b1;
                                slow_read = 1'b0;
                                quad_read = 1'b0;
                                sr_read   = 1'b0;
                                DataDriveOut_SO  = ident_out2[15-2*read_cnt];
                                DataDriveOut_SI = ident_out2[14-2*read_cnt];
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                    read_cnt = 0;
                            end
                            else //  (Instruct == RDID_QUAD)
                            begin
                                fast_read = 1'b0;
                                dual_read = 1'b0;
                                slow_read = 1'b0;
                                quad_read = 1'b1;
                                sr_read   = 1'b0;
                                DataDriveOut_HOLD = ident_out2[15-4*read_cnt];
                                DataDriveOut_WP   = ident_out2[14-4*read_cnt];
                                DataDriveOut_SO       = ident_out2[13-4*read_cnt];
                                DataDriveOut_SI      = ident_out2[12-4*read_cnt];
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 4)
                                    read_cnt = 0;
                            end
                        end
                        else if (Instruct == RD_UNIQ_ID)
                        begin
                        // unique ID number is not in data sheet
                            read_id = 1'b1;
                            DataDriveOut_SO = unique_id[63-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 64)
                                read_cnt = 0;
                        end
                        else if (Instruct == RDIDJ)
                        begin
                            read_id = 1'b1;
                            ident_out = {Manuf_ID,Device_ID2,Device_ID3};
                            DataDriveOut_SO = ident_out[23-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 24)
                                read_cnt = 0;
                        end
                        else if (Instruct == RD_SFDP)
                        begin
                            sfdp_addr = read_addr / 12'h100;
                            if (sfdp_addr == 0)
                            begin
                                Addr_tmp_2 = (read_addr % 12'h100);
                                data_out[7:0] = SFDP_array[Addr_tmp_2];
                                SOut_zd  = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    if (read_addr == SFDP_HiAddr)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    $display("SFDP address is out of range");
                                end
                            end
                        end
                        else if (Instruct == RD_SCREG)
                        begin
                            Addr_tmp_2 = read_addr / 12'h100;
                            Addr_tmp_3 = read_addr % 12'h100;
                            if (Addr_tmp_2 == 16)
                            begin
                                // Security Register No.1
                                data_out[7:0] = Security_Reg1[Addr_tmp_3];
                                SOut_zd  = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                            end
                            else if (Addr_tmp_2 == 32)
                            begin
                                // Security Register No.2
                                data_out[7:0] = Security_Reg2[Addr_tmp_3];
                                SOut_zd  = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                            end
                            else if (Addr_tmp_2 == 48)
                                // Security Register No.2
                            begin
                                data_out[7:0] = Security_Reg3[Addr_tmp_3];
                                SOut_zd  = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                            end
                            else
                            begin
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    $display("Given Security Register Read ");
                                    $display("address is out of range ");
                                end
                            end
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                if (read_addr % 256 == SecReg_HiAddr)
                                    read_addr = (read_addr/256)*
                                                (SecReg_HiAddr+1);
                                else
                                    read_addr = read_addr + 1;
                            end
                        end
                    end  // end of 'oe'
                end // end of SUS
            end  // end of ERS_SUSP

            DP_DOWN:
            begin
                if (oe)
                begin
                    if (Instruct == RES_RD_ID)
                    begin
                        read_id = 1'b1;
                        data_out[7:0] = Device_ID1;
                        DataDriveOut_SO = data_out[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
                if (falling_edge_write)
                begin
                    if (Instruct == RES_RD_ID)
                    begin
                        RES_in = 1'b1;
                    end
                    else
                    begin
                        $display("Device is in Deep Power Down Mode");
                        $display("No instructions allowed");
                    end
                end
            end

        endcase
        //Output Disable Control
        if (CSNeg_ipd )
        begin
            SIOut_zd      = 1'bZ;
            HOLDNegOut_zd = 1'bZ;
            WPNegOut_zd   = 1'bZ;
            SOut_zd       = 1'bZ;
            DataDriveOut_SO = 1'bZ;
            DataDriveOut_SI = 1'bZ;
            DataDriveOut_HOLD = 1'bZ;
            DataDriveOut_WP = 1'bZ;
        end
    end  // end of Functionality

    ///////////////////////////////////////////////////////////////////////////
    always @(posedge change_prot_bits)
    begin
        case (Status_reg1[4:2])
            3'b000:
            begin
                if (Status_reg2[6] == 1'b0)
                    Sec_Prot[255:0] = {256{1'b0}};
                else
                    Sec_Prot[255:0] = {256{1'b1}};
            end

            3'b001:
            begin
                if (Status_reg2[6] ==1'b0)
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:240] = {16{1'b1}};
                            Sec_Prot[239:0] = {240{1'b0}};
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:16] = {240{1'b0}};
                            Sec_Prot[15:0] = {16{1'b1}};
                        end
                        2'b10:
                        begin
                            Sec_Prot[255] = 1'b1;
                            Sec_Prot[254:0] = {255{1'b0}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:1] = {255{1'b0}};
                            Sec_Prot[0] = 1'b1;
                        end
                    endcase
                end
                else
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:240] = {16{1'b0}};
                            Sec_Prot[239:0] = {240{1'b1}};
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:16] = {240{1'b1}};
                            Sec_Prot[15:0] = {16{1'b0}};
                        end
                        2'b10:
                        begin
                            Sec_Prot[255] = 1'b0;
                            Sec_Prot[254:0] = {255{1'b1}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:1] = {255{1'b1}};
                            Sec_Prot[0] = 1'b0;
                        end
                    endcase
                end
            end

            3'b010:
            begin
                if (Status_reg2[6] == 1'b0)
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:224] = {32{1'b1}} ;
                            Sec_Prot[223:0] = {224{1'b0}} ;
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:32] = {224{1'b0}} ;
                            Sec_Prot[31:0] = {32{1'b1}} ;
                        end
                        2'b10:
                        begin
                            Sec_Prot[255:254] = 2'b11;
                            Sec_Prot[253:0] = {254{1'b0}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:2] = {254{1'b0}};
                            Sec_Prot[1:0] = 2'b11;
                        end
                    endcase
                end
                else
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:224] = {32{1'b0}} ;
                            Sec_Prot[223:0] = {224{1'b1}} ;
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:32] = {224{1'b1}} ;
                            Sec_Prot[31:0] = {32{1'b0}} ;
                        end
                        2'b10:
                        begin
                            Sec_Prot[255:254] = 2'b00;
                            Sec_Prot[253:0] = {254{1'b1}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:2] = {254{1'b1}};
                            Sec_Prot[1:0] = 2'b00;
                        end
                    endcase
                end
            end

            3'b011:
            begin
                if (Status_reg2[6] == 1'b0)
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:192] = {64{1'b1}} ;
                            Sec_Prot[191:0] = {192{1'b0}} ;
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:64] = {192{1'b0}} ;
                            Sec_Prot[63:0] = {64{1'b1}} ;
                        end
                        2'b10:
                        begin
                            Sec_Prot[255:252] = 4'b1111;
                            Sec_Prot[251:0] = {252{1'b0}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:4] = {252{1'b0}};
                            Sec_Prot[3:0] = 4'b1111;
                        end
                    endcase
                end
                else
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:192] = {64{1'b0}} ;
                            Sec_Prot[191:0] = {192{1'b1}} ;
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:64] = {192{1'b1}} ;
                            Sec_Prot[63:0] = {64{1'b0}} ;
                        end
                        2'b10:
                        begin
                            Sec_Prot[255:252] = {4{1'b0}};
                            Sec_Prot[251:0] = {252{1'b1}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:4] = {252{1'b1}};
                            Sec_Prot[3:0] = {4{1'b0}};
                        end
                    endcase
                end
            end

            3'b100:
            begin
                if (Status_reg2[6] == 1'b0)
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:128] = {128{1'b1}} ;
                            Sec_Prot[127:0] = {128{1'b0}} ;
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:128] = {128{1'b0}} ;
                            Sec_Prot[127:0] = {128{1'b1}} ;
                        end
                        2'b10:
                        begin
                            Sec_Prot[255:248] = 8'hFF;
                            Sec_Prot[247:0] = {248{1'b0}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:8] = {248{1'b0}};
                            Sec_Prot[7:0] = 8'hFF;
                        end
                    endcase
                end
                else
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:128] = {128{1'b0}};
                            Sec_Prot[127:0] = {128{1'b1}};
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:128] = {128{1'b1}};
                            Sec_Prot[127:0] = {128{1'b0}};
                        end
                        2'b10:
                        begin
                            Sec_Prot[255:248] = {8{1'b0}};
                            Sec_Prot[247:0] = {248{1'b1}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:8] = {248{1'b1}};
                            Sec_Prot[7:0] = {8{1'b0}};
                        end
                    endcase
                end
            end

            3'b101:
            begin
                if (Status_reg2[6] == 1'b0)
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:0] = {256{1'b1}} ;
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:0] = {256{1'b1}} ;
                        end
                        2'b10:
                        begin
                            Sec_Prot[255:248] = 8'hFF;
                            Sec_Prot[247:0] = {248{1'b0}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:8] = {248{1'b0}};
                            Sec_Prot[7:0] = 8'hFF;
                        end
                    endcase
                end
                else
                begin
                    case (Status_reg1[6:5])
                        2'b00:
                        begin
                            Sec_Prot[255:0] = {256{1'b0}} ;
                        end
                        2'b01:
                        begin
                            Sec_Prot[255:0] = {256{1'b0}} ;
                        end
                        2'b10:
                        begin
                            Sec_Prot[255:248] = {8{1'b0}};
                            Sec_Prot[247:0] = {248{1'b1}};
                        end
                        2'b11:
                        begin
                            Sec_Prot[255:8] = {248{1'b1}};
                            Sec_Prot[7:0] = {8{1'b0}};
                        end
                    endcase
                end
            end

            3'b110, 3'b111:
            begin
                if (Status_reg2[6] == 1'b0)
                    Sec_Prot[255:0] = {256{1'b1}} ;
                else
                    Sec_Prot[255:0] = {256{1'b0}} ;
            end

        endcase
    end  // end of rising_edge_prot_bits
    ////////////////////////////////////////////////////////////////////////
    always @(SOut_zd or HOLDNeg_in or SIOut_zd)
    begin
        if (HOLDNeg_in == 0 && ~QE)
        begin
            hold_mode = 1'b1;
            SIOut_z   = 1'bZ;
            SOut_z    = 1'bZ;
        end
        else
        begin
            if (hold_mode == 1)
            begin
                SIOut_z <= #(tpd_HOLDNeg_SO) SIOut_zd;
                SOut_z  <= #(tpd_HOLDNeg_SO) SOut_zd;
                hold_mode = #(tpd_HOLDNeg_SO) 1'b0;
            end
            else
            begin
                SIOut_z = SIOut_zd;
                SOut_z  = SOut_zd;
                hold_mode = 1'b0;
            end
        end
    end

    ////////////////////////////////////////////////////////////////////////
    // functions & tasks
    ////////////////////////////////////////////////////////////////////////
    // Procedure ADDRHILO_SEC 4KB, 32KB, 64KB
    task ADDRHILO_SEC64;
    inout  AddrLOW;
    inout  AddrHIGH;
    input   Addr;
    integer AddrLOW;
    integer AddrHIGH;
    integer Addr;
    integer sector;
    begin
        sector = Addr / 20'h10000;
        AddrLOW = sector * 20'h10000;
        AddrHIGH = sector * 20'h10000 + 20'h0FFFF;
    end
    endtask

    task ADDRHILO_SEC32;
    inout  AddrLOW;
    inout  AddrHIGH;
    input   Addr;
    integer AddrLOW;
    integer AddrHIGH;
    integer Addr;
    integer sector;
    begin
        sector = Addr / 16'h8000;
        AddrLOW = sector * 16'h8000;
        AddrHIGH = sector * 16'h8000 + 16'h7FFF;
    end
    endtask

    task ADDRHILO_SEC4;
    inout  AddrLOW;
    inout  AddrHIGH;
    input   Addr;
    integer AddrLOW;
    integer AddrHIGH;
    integer Addr;
    integer sector;
    begin
        sector = Addr / 16'h1000;
        AddrLOW = sector * 16'h1000;
        AddrHIGH = sector * 16'h1000 + 16'h0FFF;
    end
    endtask

    // Procedure ADDRHILO_PG
    task ADDRHILO_PG;
    inout  AddrLOW;
    inout  AddrHIGH;
    input   Addr;
    integer AddrLOW;
    integer AddrHIGH;
    integer Addr;
    integer page;
    begin
        page = Addr / 16'h0100;
        AddrLOW = page * 16'h0100;
        AddrHIGH = page * 16'h0100 + 16'h00FF;
    end
    endtask

    // Procedure ADDRHILO_WRAP
    task ADDRHILO_WRAP;
    inout Addr_low_wrap;
    inout Addr_hi_wrap;
    input Address;
    input w_size;
    integer Addr_low_wrap;
    integer Addr_hi_wrap;
    integer Address;
    integer w_size;
    integer sect_wrap;
    begin
        sect_wrap = Address / w_size;
        Addr_low_wrap = sect_wrap * w_size;
        Addr_hi_wrap = sect_wrap * w_size + w_size - 1;
    end
    endtask

    ///////////////////////////////////////////////////////////////////////////
    // edge controll processes
    ///////////////////////////////////////////////////////////////////////////
    always @(posedge PoweredUp)
    begin
        rising_edge_PoweredUp = 1;
        #1000 rising_edge_PoweredUp = 0;
    end

    always @(posedge SCK_ipd)
    begin
       rising_edge_SCK_ipd = 1'b1;
       #1000 rising_edge_SCK_ipd = 1'b0;
    end

    always @(negedge SCK_ipd)
    begin
       falling_edge_SCK_ipd = 1'b1;
       #1000 falling_edge_SCK_ipd = 1'b0;
    end

    always @(posedge read_out)
    begin
        rising_edge_read_out = 1'b1;
        #1000 rising_edge_read_out = 1'b0;
    end

    always @(negedge write)
    begin
        falling_edge_write = 1'b1;
        #1000 falling_edge_write = 1'b0;
    end

    always @(posedge CSNeg_ipd)
    begin
        rising_edge_CSNeg_ipd = 1'b1;
        #1000 rising_edge_CSNeg_ipd = 1'b0;
    end

    always @(negedge CSNeg_ipd)
    begin
        falling_edge_CSNeg_ipd = 1'b1;
        #1000 falling_edge_CSNeg_ipd = 1'b0;
    end

    always @(posedge PDONE)
    begin
        rising_edge_PDONE = 1'b1;
        #1000 rising_edge_PDONE = 1'b0;
    end

    always @(posedge WDONE)
    begin
        rising_edge_WDONE = 1'b1;
        #1000 rising_edge_WDONE = 1'b0;
    end

    always @(posedge VLTDONE)
    begin
        rising_edge_VLTDONE = 1'b1;
        #1000 rising_edge_VLTDONE = 1'b0;
    end

    always @(posedge WSTART)
    begin
        rising_edge_WSTART = 1'b1;
        #1000 rising_edge_WSTART = 1'b0;
    end

    always @(posedge VLTSTART)
    begin
        rising_edge_VLTSTART = 1'b1;
        #1000 rising_edge_VLTSTART = 1'b0;
    end

    always @(posedge EDONE)
    begin
        rising_edge_EDONE = 1'b1;
        #1000 rising_edge_EDONE = 1'b0;
    end

    always @(posedge ESTART)
    begin
        rising_edge_ESTART = 1'b1;
        #1000 rising_edge_ESTART = 1'b0;
    end

    always @(posedge PSTART)
    begin
        rising_edge_PSTART = 1'b1;
        #1000 rising_edge_PSTART = 1'b0;
    end

    always @(posedge DP_out)
    begin
        rising_edge_DP_out = 1'b1;
        #1 rising_edge_DP_out = 1'b0;
    end

    always @(posedge RES_out)
    begin
        rising_edge_RES_out = 1'b1;
        #1000 rising_edge_RES_out = 1'b0;
    end

    always @(Instruct)
    begin
        Instruct_event = 1'b1;
        #1000 Instruct_event = 1'b0;
    end

    always @(change_addr)
    begin
        change_addr_event = 1'b1;
        #1000 change_addr_event = 1'b0;
    end

    always @(next_state)
    begin
        next_state_event = 1'b1;
        #1000 next_state_event = 1'b0;
    end

    always @(current_state)
    begin
        current_state_event = 1'b1;
        #1000 current_state_event = 1'b0;
    end

    always @(posedge PRGSUSP_out)
    begin
        PRGSUSP_out_event = 1;
        #1000 PRGSUSP_out_event = 0;
    end

    always @(posedge PRGRES_out)
    begin
        PRGRES_out_event = 1;
        #1000 PRGRES_out_event = 0;
    end

    always @(posedge ESUSP)
    begin
        ESUSP_event = 1'b1;
        #1000 ESUSP_event = 1'b0;
    end

    always @(posedge ERSSUSP_out)
    begin
        ERSSUSP_out_event = 1;
        #1000 ERSSUSP_out_event = 0;
    end

    always @(posedge ERSRES_out)
    begin
        ERSRES_out_event = 1;
        #1000 ERSRES_out_event = 0;
    end

    always @(posedge PGSUSP)
    begin
        PGSUSP_event = 1'b1;
        #1000 PGSUSP_event = 1'b0;
    end

    always @(posedge PGRES)
    begin
        PGRES_event = 1'b1;
        #1000 PGRES_event = 1'b0;
    end

    always @(posedge ERES)
    begin
        ERES_event = 1'b1;
        #1000 ERES_event = 1'b0;
    end

    always @(posedge change_prot_bits)
    begin
        rising_edge_prot_bits = 1'b1;
        #1000 rising_edge_prot_bits = 1'b0;
    end
    reg update_time = 1'b0;
    always @(posedge read_id)
    begin
        start_rdid = $time;
        update_time = 1'b1;
    end

    always @(SO_out)
    begin
        if (read_id && update_time )
            out_time = $time;
            SCK_SO_2 = out_time - start_rdid;
            update_time = 1'b0;
    end

    always @(DataDriveOut_SO,DataDriveOut_SI,DataDriveOut_HOLD,DataDriveOut_WP)
    begin
        if (SCK_SO_2 > SCK_cycle)
        begin
            glitch = 1;
            SOut_zd <= #SCK_SO_2 DataDriveOut_SO;
            SIOut_zd <= #SCK_SO_2 DataDriveOut_SI;
            HOLDNegOut_zd <= #SCK_SO_2 DataDriveOut_HOLD;
            WPNegOut_zd <= #SCK_SO_2 DataDriveOut_WP;
        end
        else
        begin
            glitch = 0;
            SOut_zd <= DataDriveOut_SO;
            SIOut_zd <= DataDriveOut_SI;
            HOLDNegOut_zd <=  DataDriveOut_HOLD;
            WPNegOut_zd <=  DataDriveOut_WP;
        end
    end

endmodule
