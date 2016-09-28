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
	@brief Declaration of MicrochipPIC32Device
 */

#ifndef MicrochipPIC32Device_h
#define MicrochipPIC32Device_h

#include "MicrochipMicrocontroller.h"

#include <list>
#include <string>

/** 
	@brief Status register for a Microchip PIC32 device
	
	\ingroup libjtaghal
 */
union MicrochipPIC32DeviceStatusRegister
{
	struct
	{
		/*
		
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
		
		*/
	} __attribute__ ((packed)) bits;
	
	///The raw status register value
	uint8_t word;
} __attribute__ ((packed));

struct MicrochipPIC32DeviceInfo
{
	///JTAG device ID
	uint16_t devid;
	
	///String name of device
	const char* name;
	
	///Device family
	unsigned int family;
	
	///CPU type
	unsigned int cpu;
	
	///SRAM capacity (kB)
	unsigned int sram_size;
	
	///Main program flash size (kB)
	unsigned int program_flash_size;
	
	///Boot flash size (kB)
	unsigned int boot_flash_size;
};

/** 
	@brief A Xilinx CoolRunner-II device
	
	\ingroup libjtaghal
 */
class MicrochipPIC32Device	: public MicrochipMicrocontroller
{
public:
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Construction / destruction
	MicrochipPIC32Device(
		unsigned int devid,
		unsigned int stepping,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	virtual ~MicrochipPIC32Device();

	static JtagDevice* CreateDevice(
		unsigned int devid,
		unsigned int stepping,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
		
	///Device families
	enum families
	{
		FAMILY_MX12,		//PIC32MX 1xx/2xx
		FAMILY_MX34,		//PIC32MX 3xx/4xx
		FAMILY_MX567,		//PIC32MX 5xx/6xx/7xx
		
		FAMILY_MZ			//All PIC32MZ devices
	};
	
	///CPU types
	enum cpus
	{
		CPU_M4K,
		CPU_MAPTIV
	};
	
	///JTAG device IDs (from BSDL files)
	enum deviceids
	{
		PIC32MX110F016B = 0x4a07,
		PIC32MX110F016C = 0x4a09,
		PIC32MX110F016D = 0x4a0b,
		PIC32MX120F032B = 0x4a06,
		PIC32MX120F032C = 0x4a08,
		PIC32MX120F032D = 0x4a0a,
		PIC32MX130F064B = 0x4d07,
		PIC32MX130F064C = 0x4d09,
		PIC32MX130F064D = 0x4d0b,
		PIC32MX150F128B = 0x4d06,
		PIC32MX150F128C = 0x4d08,
		PIC32MX150F128D = 0x4d0a,
		PIC32MX210F016B = 0x4a01,
		PIC32MX210F016C = 0x4a03,
		PIC32MX210F016D = 0x4a05,
		PIC32MX220F032B = 0x4a00,
		PIC32MX220F032C = 0x4a02,
		PIC32MX220F032D = 0x4a04,
		PIC32MX230F064B = 0x4d01,
		PIC32MX230F064C = 0x4d03,
		PIC32MX230F064D = 0x4d05,
		PIC32MX250F128B = 0x4d00,
		PIC32MX250F128C = 0x4d02,
		PIC32MX250F128D = 0x4d04,
		PIC32MX330F064H = 0x5600,
		PIC32MX330F064L = 0x5601,
		PIC32MX340F512H = 0x0916,
		PIC32MX350F128H = 0x570c,
		//PIC32MX350F128L = 0x570d,	//350F128L and 350F256H have same IDCODE... BSDL error?
		PIC32MX350F256H = 0x570d,
		PIC32MX350F256L = 0x5705,
		PIC32MX430F064H = 0x5602,
		PIC32MX430F064L = 0x5603,
		PIC32MX450F128H = 0x570e,
		PIC32MX450F128L = 0x570f,
		PIC32MX450F256H = 0x5706,
		PIC32MX450F256L = 0x5707,
		PIC32MX534F064H = 0x440c,	//H and L have same IDCODE... BSDL error?
		//PIC32MX534F064L = 0x440c,
		PIC32MX564F064H = 0x4401,
		PIC32MX564F064L = 0x440d,
		PIC32MX564F128H = 0x4403,
		PIC32MX564F128L = 0x440f,
		PIC32MX664F064H = 0x4405,
		PIC32MX664F064L = 0x4411,
		PIC32MX664F128H = 0x4407,
		PIC32MX664F128L = 0x4413,
		PIC32MX695F512L = 0x4341,
		PIC32MX764F128H = 0x440b,
		PIC32MX764F128L = 0x4417,
		PIC32MX795F512L = 0x4307
	};
	
	///5-bit-wide JTAG instructions (from BSDL file and datasheet)
	enum instructions 
	{
		///Standard JTAG bypass
		INST_BYPASS				= 0x1F,
		
		///Read ID code
		INST_IDCODE				= 0x01,
		
		///Selects Microchip scan chain
		INST_MTAP_SW_MCHP		= 0x04,
		
		///Selects EJTAG scan chain
		INST_MTAP_SW_EJTAG		= 0x05,
		
		///Command to Microchip virtualized JTAG
		INST_MTAP_COMMAND		= 0x07,
		
		///Data to Microchip virtualized JTAG
		INST_MCHP_SCAN			= 0x08
	};
	
	///8-bit instructions for Microchip virtual TAP (write to INST_MTAP_COMMAND data register)
	enum mtap_instructions
	{
		///Get status
		MCHP_STATUS				= 0x00,
		
		///Begin chip reset
		MCHP_ASSERT_RST			= 0xD1,
		
		///End chip reset
		MCHP_DE_ASSERT_RST		= 0xD0,
		
		///Bulk-erase flash
		MCHP_ERASE				= 0xFC,
		
		///Enable connecting the CPU to flash
		MCHP_FLASH_ENABLE		= 0xFE,
		
		///Disconnect the CPU from flash
		MCHP_FLASH_DISABLE		= 0xFD,
		
		///Force re-read of device config
		MCHP_READ_CONFIG		= 0xFF
	};
	
	///8-bit instructions for EJTAG virtual TAP
	enum ejtag_instructions
	{
		///Get CPU core ID code
		EJTAG_IDCODE			= 0x01,
		
		///Select address register for memory ops
		EJTAG_ADDRESS			= 0x08,
		
		///Select data register for memory ops
		EJTAG_DATA				= 0x09,
		
		///Control register of some sort?
		EJTAG_CONTROL			= 0x0A,
		
		///Selects address, data, control end to end in one DR
		EJTAG_ALL				= 0x0B,
		
		///Resets the CPU and makes it trap to the debugger
		EJTAG_DEBUGBOOT			= 0x0C,
		
		///Resets the CPU and boots normally
		EJTAG_NORMALBOOT		= 0x0D,
		
		///No idea what this does
		EJTAG_FASTDATA			= 0x0E
	};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General device info
	
	virtual std::string GetDescription();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MCU stuff
	
	virtual bool IsProgrammed();
	virtual void Erase(bool bVerbose = false);

	virtual FirmwareImage* LoadFirmwareImage(const unsigned char* data, size_t len, bool bVerbose);
	virtual void Program(FirmwareImage* image);
	
	//MicrochipPIC32DeviceStatusRegister GetStatusRegister();
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// No NoC interfaces
	
	virtual bool HasRPCInterface();
	virtual bool HasDMAInterface();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helpers for chain manipulation
public:	
	void SetIR(unsigned char irval)
	{ JtagDevice::SetIR(&irval, m_irlength); }

protected:
	void EnterMtapMode();
	uint8_t SendMchpCommand(uint8_t cmd);
	void EnterEjtagMode();

protected:
	
	///Device ID code
	unsigned int m_devid;
	
	///Stepping number
	unsigned int m_stepping;
	
	///Device info
	const MicrochipPIC32DeviceInfo* m_devinfo;
};

#endif
