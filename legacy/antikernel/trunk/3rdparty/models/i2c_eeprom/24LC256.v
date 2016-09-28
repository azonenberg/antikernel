// *******************************************************************************************************
// **                                                                                                   **
// **   24LC256.v - Microchip 24LC256 256K-BIT I2C SERIAL EEPROM (VCC = +2.5V TO +5.5V)                 **
// **                                                                                                   **
// *******************************************************************************************************
// **                                                                                                   **
// **                   This information is distributed under license from Young Engineering.           **
// **                              COPYRIGHT (c) 2006 YOUNG ENGINEERING                                 **
// **                                      ALL RIGHTS RESERVED                                          **
// **                                                                                                   **
// **                                                                                                   **
// **   Young Engineering provides design expertise for the digital world                               **
// **   Started in 1990, Young Engineering offers products and services for your electronic design      **
// **   project.  We have the expertise in PCB, FPGA, ASIC, firmware, and software design.              **
// **   From concept to prototype to production, we can help you.                                       **
// **                                                                                                   **
// **   http://www.young-engineering.com/                                                               **
// **                                                                                                   **
// *******************************************************************************************************
// **   This information is provided to you for your convenience and use with Microchip products only.  **
// **   Microchip disclaims all liability arising from this information and its use.                    **
// **                                                                                                   **
// **   THIS INFORMATION IS PROVIDED "AS IS." MICROCHIP MAKES NO REPRESENTATION OR WARRANTIES OF        **
// **   ANY KIND WHETHER EXPRESS OR IMPLIED, WRITTEN OR ORAL, STATUTORY OR OTHERWISE, RELATED TO        **
// **   THE INFORMATION PROVIDED TO YOU, INCLUDING BUT NOT LIMITED TO ITS CONDITION, QUALITY,           **
// **   PERFORMANCE, MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR PURPOSE.                         **
// **   MICROCHIP IS NOT LIABLE, UNDER ANY CIRCUMSTANCES, FOR SPECIAL, INCIDENTAL OR CONSEQUENTIAL      **
// **   DAMAGES, FOR ANY REASON WHATSOEVER.                                                             **
// **                                                                                                   **
// **   It is your responsibility to ensure that your application meets with your specifications.       **
// **                                                                                                   **
// *******************************************************************************************************
// **   Revision       : 1.0                                                                            **
// **   Modified Date  : 12/04/2006                                                                     **
// **   Revision History:                                                                               **
// **                                                                                                   **
// **   12/04/2006:  Initial design                                                                     **
// **                                                                                                   **
// *******************************************************************************************************
// **                                       TABLE OF CONTENTS                                           **
// *******************************************************************************************************
// **---------------------------------------------------------------------------------------------------**
// **   DECLARATIONS                                                                                    **
// **---------------------------------------------------------------------------------------------------**
// **---------------------------------------------------------------------------------------------------**
// **   INITIALIZATION                                                                                  **
// **---------------------------------------------------------------------------------------------------**
// **---------------------------------------------------------------------------------------------------**
// **   CORE LOGIC                                                                                      **
// **---------------------------------------------------------------------------------------------------**
// **   1.01:  START Bit Detection                                                                      **
// **   1.02:  STOP Bit Detection                                                                       **
// **   1.03:  Input Shift Register                                                                     **
// **   1.04:  Input Bit Counter                                                                        **
// **   1.05:  Control Byte Register                                                                    **
// **   1.06:  Byte Address Register                                                                    **
// **   1.07:  Write Data Buffer                                                                        **
// **   1.08:  Acknowledge Generator                                                                    **
// **   1.09:  Acknowledge Detect                                                                       **
// **   1.10:  Write Cycle Timer                                                                        **
// **   1.11:  Write Cycle Processor                                                                    **
// **   1.12:  Read Data Multiplexor                                                                    **
// **   1.13:  Read Data Processor                                                                      **
// **   1.14:  SDA Data I/O Buffer                                                                      **
// **                                                                                                   **
// **---------------------------------------------------------------------------------------------------**
// **   DEBUG LOGIC                                                                                     **
// **---------------------------------------------------------------------------------------------------**
// **   2.01:  Memory Data Bytes                                                                        **
// **   2.02:  Write Data Buffer                                                                        **
// **                                                                                                   **
// **---------------------------------------------------------------------------------------------------**
// **   TIMING CHECKS                                                                                   **
// **---------------------------------------------------------------------------------------------------**
// **                                                                                                   **
// *******************************************************************************************************


`timescale 1ns/10ps

module M24LC256 (A0, A1, A2, WP, SDA, SCL, RESET);

   input                A0;                             // chip select bit
   input                A1;                             // chip select bit
   input                A2;                             // chip select bit

   input                WP;                             // write protect pin

   inout                SDA;                            // serial data I/O
   input                SCL;                            // serial data clock

   input                RESET;                          // system reset


// *******************************************************************************************************
// **   DECLARATIONS                                                                                    **
// *******************************************************************************************************

   reg                  SDA_DO;                         // serial data - output
   reg                  SDA_OE;                         // serial data - output enable

   wire                 SDA_DriveEnable;                // serial data output enable
   reg                  SDA_DriveEnableDlyd;            // serial data output enable - delayed

   wire [02:00]         ChipAddress;                    // hardwired chip address

   reg  [03:00]         BitCounter;                     // serial bit counter

   reg                  START_Rcvd;                     // START bit received flag
   reg                  STOP_Rcvd;                      // STOP bit received flag
   reg                  CTRL_Rcvd;                      // control byte received flag
   reg                  ADHI_Rcvd;                      // byte address hi received flag
   reg                  ADLO_Rcvd;                      // byte address lo received flag
   reg                  MACK_Rcvd;                      // master acknowledge received flag

   reg                  WrCycle;                        // memory write cycle
   reg                  RdCycle;                        // memory read cycle

   reg  [07:00]         ShiftRegister;                  // input data shift register

   reg  [07:00]         ControlByte;                    // control byte register
   wire                 RdWrBit;                        // read/write control bit

   reg  [14:00]         StartAddress;                   // memory access starting address
   reg  [05:00]         PageAddress;                    // memory page address

   reg  [07:00]         WrDataByte [0:63];              // memory write data buffer
   wire [07:00]         RdDataByte;                     // memory read data

   reg  [15:00]         WrCounter;                      // write buffer counter

   reg  [05:00]         WrPointer;                      // write buffer pointer
   reg  [14:00]         RdPointer;                      // read address pointer

   reg                  WriteActive;                    // memory write cycle active

   reg  [07:00]         MemoryBlock [0:32767];          // EEPROM data memory array

   integer              LoopIndex;                      // iterative loop index

   integer              tAA;                            // timing parameter
   integer              tWC;                            // timing parameter


// *******************************************************************************************************
// **   INITIALIZATION                                                                                  **
// *******************************************************************************************************

   initial tAA = 900;                                   // SCL to SDA output delay
   initial tWC = 5000000;                               // memory write cycle time

   initial begin
      SDA_DO = 0;
      SDA_OE = 0;
   end

   initial begin
      START_Rcvd = 0;
      STOP_Rcvd  = 0;
      CTRL_Rcvd  = 0;
      ADHI_Rcvd  = 0;
      ADLO_Rcvd  = 0;
      MACK_Rcvd  = 0;
   end

   initial begin
      BitCounter  = 0;
      ControlByte = 0;
   end

   initial begin
      WrCycle = 0;
      RdCycle = 0;

      WriteActive = 0;
   end

   assign ChipAddress = {A2,A1,A0};


// *******************************************************************************************************
// **   CORE LOGIC                                                                                      **
// *******************************************************************************************************
// -------------------------------------------------------------------------------------------------------
//      1.01:  START Bit Detection
// -------------------------------------------------------------------------------------------------------

   always @(negedge SDA) begin
      if (SCL == 1) begin
         START_Rcvd <= 1;
         STOP_Rcvd  <= 0;
         CTRL_Rcvd  <= 0;
         ADHI_Rcvd  <= 0;
         ADLO_Rcvd  <= 0;
         MACK_Rcvd  <= 0;

         WrCycle <= #1 0;
         RdCycle <= #1 0;

         BitCounter <= 0;
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.02:  STOP Bit Detection
// -------------------------------------------------------------------------------------------------------

   always @(posedge SDA) begin
      if (SCL == 1) begin
         START_Rcvd <= 0;
         STOP_Rcvd  <= 1;
         CTRL_Rcvd  <= 0;
         ADHI_Rcvd  <= 0;
         ADLO_Rcvd  <= 0;
         MACK_Rcvd  <= 0;

         WrCycle <= #1 0;
         RdCycle <= #1 0;

         BitCounter <= 10;
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.03:  Input Shift Register
// -------------------------------------------------------------------------------------------------------

   always @(posedge SCL) begin
      ShiftRegister[00] <= SDA;
      ShiftRegister[01] <= ShiftRegister[00];
      ShiftRegister[02] <= ShiftRegister[01];
      ShiftRegister[03] <= ShiftRegister[02];
      ShiftRegister[04] <= ShiftRegister[03];
      ShiftRegister[05] <= ShiftRegister[04];
      ShiftRegister[06] <= ShiftRegister[05];
      ShiftRegister[07] <= ShiftRegister[06];
   end

// -------------------------------------------------------------------------------------------------------
//      1.04:  Input Bit Counter
// -------------------------------------------------------------------------------------------------------

   always @(posedge SCL) begin
      if (BitCounter < 10) BitCounter <= BitCounter + 1;
   end

// -------------------------------------------------------------------------------------------------------
//      1.05:  Control Byte Register
// -------------------------------------------------------------------------------------------------------

   always @(negedge SCL) begin
      if (START_Rcvd & (BitCounter == 8)) begin
         if (!WriteActive & (ShiftRegister[07:01] == {4'b1010,ChipAddress[02:00]})) begin
            if (ShiftRegister[00] == 0) WrCycle <= 1;
            if (ShiftRegister[00] == 1) RdCycle <= 1;

            ControlByte <= ShiftRegister[07:00];

            CTRL_Rcvd <= 1;
         end

         START_Rcvd <= 0;
      end
   end

   assign RdWrBit = ControlByte[00];

// -------------------------------------------------------------------------------------------------------
//      1.06:  Byte Address Register
// -------------------------------------------------------------------------------------------------------

   always @(negedge SCL) begin
      if (CTRL_Rcvd & (BitCounter == 8)) begin
         if (RdWrBit == 0) begin
            StartAddress[14:08] <= ShiftRegister[06:00];
            RdPointer[14:08]    <= ShiftRegister[06:00];

            ADHI_Rcvd <= 1;
         end

         WrCounter <= 0;
         WrPointer <= 0;

         CTRL_Rcvd <= 0;
      end
   end

   always @(negedge SCL) begin
      if (ADHI_Rcvd & (BitCounter == 8)) begin
         if (RdWrBit == 0) begin
            StartAddress[07:00] <= ShiftRegister[07:00];
            RdPointer[07:00]    <= ShiftRegister[07:00];

            ADLO_Rcvd <= 1;
         end

         WrCounter <= 0;
         WrPointer <= 0;

         ADHI_Rcvd <= 0;
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.07:  Write Data Buffer
// -------------------------------------------------------------------------------------------------------

   always @(negedge SCL) begin
      if (ADLO_Rcvd & (BitCounter == 8)) begin
         if (RdWrBit == 0) begin
            WrDataByte[WrPointer] <= ShiftRegister[07:00];

            WrCounter <= WrCounter + 1;
            WrPointer <= WrPointer + 1;
         end
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.08:  Acknowledge Generator
// -------------------------------------------------------------------------------------------------------

   always @(negedge SCL) begin
      if (!WriteActive) begin
         if (BitCounter == 8) begin
            if (WrCycle | (START_Rcvd & (ShiftRegister[07:01] == {4'b1010,ChipAddress[02:00]}))) begin
               SDA_DO <= 0;
               SDA_OE <= 1;
            end 
         end
         if (BitCounter == 9) begin
            BitCounter <= 0;

            if (!RdCycle) begin
               SDA_DO <= 0;
               SDA_OE <= 0;
            end
         end
      end
   end 

// -------------------------------------------------------------------------------------------------------
//      1.09:  Acknowledge Detect
// -------------------------------------------------------------------------------------------------------

   always @(posedge SCL) begin
      if (RdCycle & (BitCounter == 8)) begin
         if ((SDA == 0) & (SDA_OE == 0)) MACK_Rcvd <= 1;
      end
   end

   always @(negedge SCL) MACK_Rcvd <= 0;

// -------------------------------------------------------------------------------------------------------
//      1.10:  Write Cycle Timer
// -------------------------------------------------------------------------------------------------------

   always @(posedge STOP_Rcvd) begin
      if (WrCycle & (WP == 0) & (WrCounter > 0)) begin
         WriteActive = 1;
         #(tWC);
         WriteActive = 0;
      end
   end

   always @(posedge STOP_Rcvd) begin
      #(1.0);
      STOP_Rcvd = 0;
   end

// -------------------------------------------------------------------------------------------------------
//      1.11:  Write Cycle Processor
// -------------------------------------------------------------------------------------------------------

   always @(negedge WriteActive) begin
      for (LoopIndex = 0; LoopIndex < WrCounter; LoopIndex = LoopIndex + 1) begin
         PageAddress = StartAddress[05:00] + LoopIndex;

         MemoryBlock[{StartAddress[14:06],PageAddress[05:00]}] = WrDataByte[LoopIndex[05:00]];
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.12:  Read Data Multiplexor
// -------------------------------------------------------------------------------------------------------

   always @(negedge SCL) begin
      if (BitCounter == 8) begin
         if (WrCycle & ADLO_Rcvd) begin
            RdPointer <= StartAddress + WrPointer + 1;
         end
         if (RdCycle) begin
            RdPointer <= RdPointer + 1;
         end
      end
   end

   assign RdDataByte = MemoryBlock[RdPointer[14:00]];

// -------------------------------------------------------------------------------------------------------
//      1.13:  Read Data Processor
// -------------------------------------------------------------------------------------------------------

   always @(negedge SCL) begin
      if (RdCycle) begin
         if (BitCounter == 8) begin
            SDA_DO <= 0;
            SDA_OE <= 0;
         end
         else if (BitCounter == 9) begin
            SDA_DO <= RdDataByte[07];

            if (MACK_Rcvd) SDA_OE <= 1;
         end
         else begin
            SDA_DO <= RdDataByte[7-BitCounter];
         end
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.14:  SDA Data I/O Buffer
// -------------------------------------------------------------------------------------------------------

   bufif1 (SDA, 1'b0, SDA_DriveEnableDlyd);

   assign SDA_DriveEnable = !SDA_DO & SDA_OE;
   always @(SDA_DriveEnable) SDA_DriveEnableDlyd <= #(tAA) SDA_DriveEnable;


// *******************************************************************************************************
// **   DEBUG LOGIC                                                                                     **
// *******************************************************************************************************
// -------------------------------------------------------------------------------------------------------
//      2.01:  Memory Data Bytes
// -------------------------------------------------------------------------------------------------------

   wire [07:00] MemoryByte_000 = MemoryBlock[00];
   wire [07:00] MemoryByte_001 = MemoryBlock[01];
   wire [07:00] MemoryByte_002 = MemoryBlock[02];
   wire [07:00] MemoryByte_003 = MemoryBlock[03];
   wire [07:00] MemoryByte_004 = MemoryBlock[04];
   wire [07:00] MemoryByte_005 = MemoryBlock[05];
   wire [07:00] MemoryByte_006 = MemoryBlock[06];
   wire [07:00] MemoryByte_007 = MemoryBlock[07];
   wire [07:00] MemoryByte_008 = MemoryBlock[08];
   wire [07:00] MemoryByte_009 = MemoryBlock[09];
   wire [07:00] MemoryByte_00A = MemoryBlock[10];
   wire [07:00] MemoryByte_00B = MemoryBlock[11];
   wire [07:00] MemoryByte_00C = MemoryBlock[12];
   wire [07:00] MemoryByte_00D = MemoryBlock[13];
   wire [07:00] MemoryByte_00E = MemoryBlock[14];
   wire [07:00] MemoryByte_00F = MemoryBlock[15];

// -------------------------------------------------------------------------------------------------------
//      2.02:  Write Data Buffer
// -------------------------------------------------------------------------------------------------------

   wire [07:00] WriteData_00 = WrDataByte[00];
   wire [07:00] WriteData_01 = WrDataByte[01];
   wire [07:00] WriteData_02 = WrDataByte[02];
   wire [07:00] WriteData_03 = WrDataByte[03];
   wire [07:00] WriteData_04 = WrDataByte[04];
   wire [07:00] WriteData_05 = WrDataByte[05];
   wire [07:00] WriteData_06 = WrDataByte[06];
   wire [07:00] WriteData_07 = WrDataByte[07];
   wire [07:00] WriteData_08 = WrDataByte[08];
   wire [07:00] WriteData_09 = WrDataByte[09];
   wire [07:00] WriteData_0A = WrDataByte[10];
   wire [07:00] WriteData_0B = WrDataByte[11];
   wire [07:00] WriteData_0C = WrDataByte[12];
   wire [07:00] WriteData_0D = WrDataByte[13];
   wire [07:00] WriteData_0E = WrDataByte[14];
   wire [07:00] WriteData_0F = WrDataByte[15];

   wire [07:00] WriteData_10 = WrDataByte[16];
   wire [07:00] WriteData_11 = WrDataByte[17];
   wire [07:00] WriteData_12 = WrDataByte[18];
   wire [07:00] WriteData_13 = WrDataByte[19];
   wire [07:00] WriteData_14 = WrDataByte[20];
   wire [07:00] WriteData_15 = WrDataByte[21];
   wire [07:00] WriteData_16 = WrDataByte[22];
   wire [07:00] WriteData_17 = WrDataByte[23];
   wire [07:00] WriteData_18 = WrDataByte[24];
   wire [07:00] WriteData_19 = WrDataByte[25];
   wire [07:00] WriteData_1A = WrDataByte[26];
   wire [07:00] WriteData_1B = WrDataByte[27];
   wire [07:00] WriteData_1C = WrDataByte[28];
   wire [07:00] WriteData_1D = WrDataByte[29];
   wire [07:00] WriteData_1E = WrDataByte[30];
   wire [07:00] WriteData_1F = WrDataByte[31];

   wire [07:00] WriteData_20 = WrDataByte[32];
   wire [07:00] WriteData_21 = WrDataByte[33];
   wire [07:00] WriteData_22 = WrDataByte[34];
   wire [07:00] WriteData_23 = WrDataByte[35];
   wire [07:00] WriteData_24 = WrDataByte[36];
   wire [07:00] WriteData_25 = WrDataByte[37];
   wire [07:00] WriteData_26 = WrDataByte[38];
   wire [07:00] WriteData_27 = WrDataByte[39];
   wire [07:00] WriteData_28 = WrDataByte[40];
   wire [07:00] WriteData_29 = WrDataByte[41];
   wire [07:00] WriteData_2A = WrDataByte[42];
   wire [07:00] WriteData_2B = WrDataByte[43];
   wire [07:00] WriteData_2C = WrDataByte[44];
   wire [07:00] WriteData_2D = WrDataByte[45];
   wire [07:00] WriteData_2E = WrDataByte[46];
   wire [07:00] WriteData_2F = WrDataByte[47];

   wire [07:00] WriteData_30 = WrDataByte[48];
   wire [07:00] WriteData_31 = WrDataByte[49];
   wire [07:00] WriteData_32 = WrDataByte[50];
   wire [07:00] WriteData_33 = WrDataByte[51];
   wire [07:00] WriteData_34 = WrDataByte[52];
   wire [07:00] WriteData_35 = WrDataByte[53];
   wire [07:00] WriteData_36 = WrDataByte[54];
   wire [07:00] WriteData_37 = WrDataByte[55];
   wire [07:00] WriteData_38 = WrDataByte[56];
   wire [07:00] WriteData_39 = WrDataByte[57];
   wire [07:00] WriteData_3A = WrDataByte[58];
   wire [07:00] WriteData_3B = WrDataByte[59];
   wire [07:00] WriteData_3C = WrDataByte[60];
   wire [07:00] WriteData_3D = WrDataByte[61];
   wire [07:00] WriteData_3E = WrDataByte[62];
   wire [07:00] WriteData_3F = WrDataByte[63];


// *******************************************************************************************************
// **   TIMING CHECKS                                                                                   **
// *******************************************************************************************************

   wire TimingCheckEnable = (RESET == 0) & (SDA_OE == 0);
   wire tstSTOP = STOP_Rcvd;

   specify
      specparam
         tHI = 600,                                     // SCL pulse width - high
         tLO = 1300,                                    // SCL pulse width - low
         tSU_STA = 600,                                 // SCL to SDA setup time
         tHD_STA = 600,                                 // SCL to SDA hold time
         tSU_DAT = 100,                                 // SDA to SCL setup time
         tSU_STO = 600,                                 // SCL to SDA setup time
         tSU_WP  = 600,                                 // WP setup time
         tHD_WP  = 1300,                                // WP hold time
         tBUF = 1300;                                   // Bus free time

      $width (posedge SCL, tHI);
      $width (negedge SCL, tLO);

      $width (posedge SDA &&& SCL, tBUF);

      $setup (posedge SCL, negedge SDA &&& TimingCheckEnable, tSU_STA);
      $setup (SDA, posedge SCL &&& TimingCheckEnable, tSU_DAT);
      $setup (posedge SCL, posedge SDA &&& TimingCheckEnable, tSU_STO);
      $setup (WP, posedge tstSTOP &&& TimingCheckEnable, tSU_WP);

      $hold  (negedge SDA &&& TimingCheckEnable, negedge SCL, tHD_STA);
      $hold  (posedge tstSTOP &&& TimingCheckEnable, WP, tHD_WP);
   endspecify

endmodule
