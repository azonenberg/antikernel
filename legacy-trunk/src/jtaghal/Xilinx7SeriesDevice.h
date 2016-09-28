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
	@brief Declaration of Xilinx7SeriesDevice
 */

#ifndef Xilinx7SeriesDevice_h
#define Xilinx7SeriesDevice_h

#include "XilinxFPGA.h"

#include <list>

/**
	@brief 7-series configuration frame (see UG470 page 87)
	
	\ingroup libjtaghal
 */
union Xilinx7SeriesDeviceConfigurationFrame
{
	struct
	{
		/**
			@brief Count field
		 */
		unsigned int count:11;
		
		///Reserved, must be zero
		unsigned int reserved:2;
		
		///Register address
		unsigned int reg_addr:14;	
		
		/**
			@brief Opcode
			
			Must be one of the following:
			\li	Xilinx7SeriesDevice::X7_CONFIG_OP_NOP
			\li Xilinx7SeriesDevice::X7_CONFIG_OP_READ
			\li Xilinx7SeriesDevice::X7_CONFIG_OP_WRITE
		 */
		unsigned int op:2;			
		
		/**
			@brief Frame type
			
			Must be Xilinx7SeriesDevice::X7_CONFIG_FRAME_TYPE_1
		 */
		unsigned int type:3;
	} __attribute__ ((packed)) bits;
	
	struct
	{
		/**
			@brief Count field
		 */
		unsigned int count:27;
		
		/**
			@brief Opcode
			
			Must be zero
		 */
		unsigned int op:2;			
		
		/**
			@brief Frame type
			
			Must be Xilinx7SeriesDevice::X7_CONFIG_FRAME_TYPE_2
		 */
		unsigned int type:3;
	} __attribute__ ((packed)) bits_type2;
	
	/// The raw configuration word
	uint32_t word;
} __attribute__ ((packed));

/**
	@brief 7-series status register (see UG470 table 5-28)
		
	\ingroup libjtaghal
 */

union Xilinx7SeriesDeviceStatusRegister
{
	struct
	{
		///Indicates that the device failed to configure due to a CRC error
		unsigned int crc_err:1;
		
		///Indicates that the device is in secure mode (encrypted bitstream)
		unsigned int part_secured:1;
		
		///Indicates MMCMs are locked
		unsigned int mmcm_lock:1;
		
		///Indicates DCI is matched
		unsigned int dci_match:1;
		
		///End-of-Startup signal
		unsigned int eos:1;
		
		///Status of GTS_CFG net
		unsigned int gts_cfg_b:1;
		
		///Status of GWE net
		unsigned int gwe:1;
		
		///Status of GHIGH_B net
		unsigned int ghigh_b:1;
		
		///Status of mode pins
		unsigned int mode_pins:3;
		
		///Internal init-finished signal
		unsigned int init_complete:1;
		
		///Status of INIT_B pin
		unsigned int init_b:1;
		
		///Indicates DONE was released
		unsigned int release_done:1;
		
		///Actual value on DONE pin
		unsigned int done:1;
		
		///Indicates an ID code error occurred (write with wrong bitstream)
		unsigned int id_error:1;
		
		///Decryption error
		unsigned int dec_error:1;
		
		///Indicates board is too hot
		unsigned int xadc_over_temp:1;
		
		///Status of startup state machine
		unsigned int startup_state:3;
		
		///Reserved
		unsigned int reserved_1:4;
		
		///Config bus width (see table 5-26)
		unsigned int bus_width:2;
		
		///Reserved
		unsigned int reserved_2:5;
		
	} __attribute__ ((packed)) bits;
	
	///The raw status register value
	uint32_t word;
} __attribute__ ((packed));

/** 
	@brief A Xilinx 7-series FPGA device
	
	\ingroup libjtaghal
 */
class Xilinx7SeriesDevice	: public XilinxFPGA
{
public:

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Construction / destruction
	Xilinx7SeriesDevice(
		unsigned int arraysize,
		unsigned int rev,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	virtual ~Xilinx7SeriesDevice();

	static JtagDevice* CreateDevice(
		unsigned int arraysize,
		unsigned int rev,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	
	///JTAG device IDs
	enum deviceids
	{		
		///XC7A200T
		ARTIX7_200T 	= 0x36,
		
		///XC7K160T
		KINTEX7_70T		= 0x47,
		
		///XC7Z010
		ZYNQ_010		= 0x122
	};
	
	///6-bit-wide JTAG instructions (see BSDL file). Mostly, but not entirely, same as Spartan-6.
	enum instructions
	{
		///User-defined instruction 1
		INST_USER1				= 0x02,
		
		///User-defined instruction 2
		INST_USER2				= 0x03,
		
		///User-defined instruction 3
		///Not same as Spartan-6
		INST_USER3				= 0x22,
		
		///User-defined instruction 4
		///Not same as Spartan-6
		INST_USER4				= 0x23,
		
		///Read configuration register
		INST_CFG_OUT			= 0x04,
		
		///Write configuration register
		INST_CFG_IN				= 0x05,
		
		///Read user ID code
		INST_USERCODE			= 0x08,
		
		///Read ID code
		INST_IDCODE				= 0x09,
		
		///Enters programming mode (erases FPGA configuration)
		INST_JPROGRAM			= 0x0B,
		
		///Runs the FPGA startup sequence (must supply dummy clocks after)
		INST_JSTART				= 0x0C,
		
		///Runs the FPGA shutdown sequence (must supply dummy clocks after)
		INST_JSHUTDOWN			= 0x0D,
		
		///Enters In-System Configuration mode (must load INST_JPROGRAM before)
		INST_ISC_ENABLE			= 0x10,
		
		///Leaves In-System Configuration mode
		INST_ISC_DISABLE		= 0x16,
		
		///Read device DNA (must load INST_ISC_ENABLE before and INST_ISC_DISABLE after)
		///Not same as Spartan-6
		INST_XSC_DNA			= 0x17,
		
		///Access to the ADC
		///Not present in Spartan-6
		INST_XADC_DRP			= 0x37,
		
		///Standard JTAG bypass
		INST_BYPASS				= 0x3F
	};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General device info
	
	virtual std::string GetDescription();
	virtual void PrintStatusRegister();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General programmable device properties
	
	virtual bool IsProgrammed();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FPGA-specific device properties
	
	virtual bool HasSerialNumber();
	virtual int GetSerialNumberLength();
	virtual int GetSerialNumberLengthBits();
	virtual void GetSerialNumber(unsigned char* data);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC helpers

protected:
	virtual void SetOCDInstruction();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Public configuration interface
public:	
	virtual void Erase(bool bVerbose = false);
	virtual void InternalErase(bool bVerbose = false);
	virtual FirmwareImage* LoadFirmwareImage(const unsigned char* data, size_t len, bool bVerbose = false);
	virtual void Program(FirmwareImage* image);
	
	virtual void Reboot();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Internal configuration helpers
protected:
	uint32_t ReadWordConfigRegister(unsigned int reg);
	void ReadWordsConfigRegister(unsigned int reg, uint32_t* dout, unsigned int count);
	void WriteWordConfigRegister(unsigned int reg, uint32_t value);

	virtual XilinxFPGABitstream* ParseBitstreamInternals(const unsigned char* data, size_t len, XilinxFPGABitstream* bitstream, size_t fpos, bool bVerbose = false);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Configuration type definitions
protected:
	
	/**
		@brief 7-series configuration opcodes (see UG470 page 87). Same as for Spartan-6.
	 */
	enum x7_config_opcodes
	{
		X7_CONFIG_OP_NOP	= 0,
		X7_CONFIG_OP_READ	= 1,
		X7_CONFIG_OP_WRITE	= 2
	};

	/** 
		@brief 7-series configuration frame types (see UG470 page 87). Same as for Spartan-6.
	 */
	enum x7_config_frame_types
	{
		X7_CONFIG_FRAME_TYPE_1 = 1,
		X7_CONFIG_FRAME_TYPE_2 = 2
	};

	/**
		@brief 7-series configuration registers (see UG470 page 104). Not same as Spartan-6.
	 */
	enum x7_config_regs
	{
		X7_CONFIG_REG_CRC		= 0x00,
		X7_CONFIG_REG_FAR		= 0x01,
		X7_CONFIG_REG_FDRI		= 0x02,
		X7_CONFIG_REG_FDRO		= 0x03,
		X7_CONFIG_REG_CMD		= 0x04,
		X7_CONFIG_REG_CTL0		= 0x05,
		X7_CONFIG_REG_MASK		= 0x06,
		X7_CONFIG_REG_STAT		= 0x07,
		X7_CONFIG_REG_LOUT		= 0x08,
		X7_CONFIG_REG_COR0		= 0x09,
		X7_CONFIG_REG_MFWR		= 0x0A,
		X7_CONFIG_REG_CBC		= 0x0B,
		X7_CONFIG_REG_IDCODE	= 0x0C,
		X7_CONFIG_REG_AXSS		= 0x0D,
		X7_CONFIG_REG_COR1		= 0x0E,
		//0x0F reserved or usused
		X7_CONFIG_REG_WBSTAR	= 0x10,
		X7_CONFIG_REG_TIMER		= 0x11,
		//0x12 reserved or unused
		//0x13 reserved or unused
		//0x14 reserved or unused
		//0x15 reserved or unused
		X7_CONFIG_REG_BOOTSTS	= 0x16,
		//0x17 reserved or unused
		X7_CONFIG_REG_CTL1		= 0x18,
		//0x19 and up reserved or unused
		
		X7_CONFIG_REG_BSPI		= 0x1F,
		
		X7_CONFIG_REG_MAX		//max config reg value
	};

	/**
		@brief 7-series CMD register values (see UG470 page 89-90)
	 */
	enum x7_cmd_values
	{
		X7_CMD_NULL			= 0x00,
		X7_CMD_WCFG			= 0x01,
		X7_CMD_MFW			= 0x02,
		X7_CMD_LFRM			= 0x03,
		X7_CMD_RCFG			= 0x04,
		X7_CMD_START		= 0x05,
		X7_CMD_RCAP			= 0x06,
		X7_CMD_RCRC			= 0x07,
		X7_CMD_AGHIGH		= 0x08,
		X7_CMD_SWITCH		= 0x09,
		X7_CMD_GRESTORE		= 0x0a,
		X7_CMD_SHUTDOWN		= 0x0b,
		X7_CMD_GCAPTURE		= 0x0c,
		X7_CMD_DESYNC		= 0x0d,
		//0x0e is reserved
		X7_CMD_IPROG		= 0x0f,
		X7_CMD_CRCC			= 0x10,
		X7_CMD_LTIMER		= 0x11,
		X7_CMD_MAX
	};
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helpers for chain manipulation
protected:	
	void SetIR(unsigned char irval)
	{ JtagDevice::SetIR(&irval, m_irlength); }
	
	void SetIRDeferred(unsigned char irval)
	{ JtagDevice::SetIRDeferred(&irval, m_irlength); }
	
protected:
	
	///Array size (the specific 7-series device we are)
	unsigned m_arraysize;
	
	///Stepping number
	unsigned int m_rev;
};

#endif
