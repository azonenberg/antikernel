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
	@brief Declaration of XilinxCoolRunnerIIDevice
 */

#ifndef XilinxCoolRunnerIIDevice_h
#define XilinxCoolRunnerIIDevice_h

#include "XilinxCPLD.h"

#include <list>
#include <string>

class XilinxCPLDBitstream;

/** 
	@brief Status register for a Xilinx CoolRunner-II device
	
	\ingroup libjtaghal
 */
union XilinxCoolRunnerIIDeviceStatusRegister
{
	struct
	{
		///Constant '01'
		unsigned int padding_one:2;
		
		///True if configured
		unsigned int done:1;
		
		///True if secured
		unsigned int sec:1;
		
		///True if in ISC_ENABLE state
		unsigned int isc_en:1;
		
		///True if in ISC_DISABLE state
		unsigned int isc_dis:1;
		
		///Constant '00'
		unsigned int padding_zero:2;
	} __attribute__ ((packed)) bits;
	
	///The raw status register value
	uint8_t word;
} __attribute__ ((packed));

/** 
	@brief A Xilinx CoolRunner-II device
	
	\ingroup libjtaghal
 */
class XilinxCoolRunnerIIDevice	: public XilinxCPLD
{
public:
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Construction / destruction
	XilinxCoolRunnerIIDevice(
		unsigned int devid,
		unsigned int package_decoded,
		unsigned int stepping,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	virtual ~XilinxCoolRunnerIIDevice();

	static JtagDevice* CreateDevice(
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	
	///JTAG device IDs
	enum deviceids
	{
		XC2C32		= 0x01,
		XC2C32A		= 0x21,
		XC2C64		= 0x05,
		XC2C64A		= 0x25,
		XC2C128		= 0x18,
		XC2C256		= 0x14,
		XC2C384		= 0x15,
		XC2C512		= 0x17,
	};
	
	//Package IDs (not device dependent, unrelated to JTAG ID code)
	//Cannot tell Pb / Pb-free over JTAG, using Pb-free names here for uniformity
	enum packages
	{
		///32-pin QFN (0.5mm pitch)
		QFG32		= 1,
		
		///44-pin VQFP (0.8mm pitch)
		VQG44		= 2,
		
		///48-pin QFN (0.5mm pitch)
		QFG48 		= 3,
		
		///56-ball CSBGA (0.5mm pitch)
		CPG56		= 4,
		
		///100-pin VQFP (0.5mm pitch)
		VQG100		= 5,
		
		///132-ball CSBGA (0.5mm pitch)
		CPG132		= 6,
		
		///144-pin TQFP (0.5mm pitch)
		TQG144		= 7,
		
		///208-pin PQFP (0.5mm pitch)
		PQG208		= 8,
		
		///256-ball FTBGA (1mm pitch)
		FTG256		= 9,
		
		///324-ball FGBGA (1mm pitch)
		FGG324		= 10
	};
	
	///6-bit-wide JTAG instructions (from BSDL file)
	enum instructions
	{
		///Standard JTAG bypass
		INST_BYPASS				= 0xFF,
		
		///Enter in-system configuration mode
		INST_ISC_ENABLE			= 0xE8,
		
		//Enter in-system configuration mode without shutting down
		INST_ISC_ENABLEOTF		= 0xE4,
		
		//Read configuration SRAM
		INST_ISC_SRAM_READ		= 0xE7,
		
		//Write configuration SRAM
		INST_ISC_SRAM_WRITE		= 0xE6,
		
		///Erase the EEPROM array
		INST_ISC_ERASE			= 0xED,
		
		///Program the EEPROM array
		INST_ISC_PROGRAM		= 0xEA,
		
		///Discharge high voltage and/or boot device (depends on context)
		INST_ISC_INIT			= 0xF0,
		
		///Leave ISC mode
		INST_ISC_DISABLE		= 0xC0,
		
		///Verify
		INST_ISC_READ			= 0xEE
		
		/*
			"INTEST         (00000010)," &
			"SAMPLE         (00000011)," &
			"EXTEST         (00000000)," &
			"IDCODE         (00000001)," &
			"USERCODE       (11111101)," &
			"HIGHZ          (11111100)," &
			"ISC_ENABLE_CLAMP (11101001)," &
			"TEST_ENABLE    (00010001)," &
			"BULKPROG       (00010010)," &
			"ERASE_ALL      (00010100)," &
			"MVERIFY        (00010011)," &
			"TEST_DISABLE   (00010101)," &
			"ISC_NOOP       (11100000)";
		*/
	};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General device info
	
	virtual std::string GetDescription();
	
	static std::string GetPackageName(int pknum);
	std::string GetDeviceName();
	std::string GetDevicePackage();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// CPLD stuff
	virtual bool IsProgrammed();
	virtual void Erase(bool bVerbose = false);

	virtual FirmwareImage* LoadFirmwareImage(const unsigned char* data, size_t len, bool bVerbose);
	virtual void Program(FirmwareImage* image);
	
	XilinxCoolRunnerIIDeviceStatusRegister GetStatusRegister();
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// No NoC interfaces
	
	virtual bool HasRPCInterface();
	virtual bool HasDMAInterface();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helpers for chain manipulation
public:	
	void SetIR(unsigned char irval)
	{ JtagDevice::SetIR(&irval, m_irlength); }
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helpers for permutation of programming data
public:

	enum fusevalues
	{
		FUSE_VALUE_TRANSFER = -1,
		FUSE_VALUE_DONTCARE = -2
	};

	int GetShiftRegisterWidth();
	int GetShiftRegisterDepth();

	int GetFuseCount();
	
	int GetAddressSize();
	int GetPaddingSize();
	unsigned char* GeneratePermutedFuseData(XilinxCPLDBitstream* bit, int* permtable);
	unsigned char* GenerateVerificationTable();
	int* GeneratePermutationTable();
	
	int GetZIAWidth();
	int GetFunctionBlockCount();
	int GetFunctionBlockPairCount();
	int GetFunctionBlockGridWidth();
	int GetFunctionBlockGridHeight();

	int MirrorCoordinate(int x, int end, bool mirror);
	
	int GrayEncode(int address);
	
	unsigned int GetDensity()
	{ return m_devid; }
	
protected:
	
	///Device ID code
	unsigned int m_devid;
	
	///Package code
	unsigned int m_package;
	
	///Stepping number
	unsigned int m_stepping;
};

#endif
