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
	@brief Declaration of XilinxSpartan3ADevice
 */

#ifndef XilinxSpartan3ADevice_h
#define XilinxSpartan3ADevice_h

#include "XilinxFPGA.h"

#include <list>

/**
	@brief Spartan-3A configuration frame header (see UG332 page 323)
	
	\ingroup libjtaghal
 */
union XilinxSpartan3ADeviceConfigurationFrame
{
	struct
	{
		/**
			@brief Count field
			
			\li Type 1 packets: word count
			\li Type 2 packets: don't care
		 */
		unsigned int count:5;
		
		///Register address
		unsigned int reg_addr:6;	
		
		/**
			@brief Opcode
			
			Must be one of the following:
			\li	XilinxSpartan3ADevice::S3_CONFIG_OP_NOP
			\li XilinxSpartan3ADevice::S3_CONFIG_OP_READ
			\li XilinxSpartan3ADevice::S3_CONFIG_OP_WRITE
		 */
		unsigned int op:2;			
		
		/**
			@brief Frame type
			
			Must be one of the following:
			\li XilinxSpartan3ADevice::S3A_CONFIG_FRAME_TYPE_1
			\li XilinxSpartan3ADevice::S3A_CONFIG_FRAME_TYPE_2
		 */
		unsigned int type:3;
	} __attribute__ ((packed)) bits;
	
	/// The raw configuration word
	uint16_t word;
	
} __attribute__ ((packed));

/**
	@brief Spartan-3A status register (see UG332 table 17-13, pages 327-328)
		
	\ingroup libjtaghal
 */
union XilinxSpartan3ADeviceStatusRegister
{
	struct
	{
		///Indicates that the device failed to configure due to a CRC error
		unsigned int crc_err:1;
		
		///Indicates that the device failed to configure due to the bitstream having the wrong ID code
		unsigned int idcode_err:1;
		
		///Asserted once all DCM/PLL instances used in the design have locked on
		unsigned int dcm_lock:1;
		
		///Status of global tristate net
		unsigned int gts_cfg_b:1;
		
		///Status of global write-enable net
		unsigned int gwe:1;
		
		///Status of GHIGH (TODO: describe what this is)
		unsigned int ghigh:1;
		
		///Status of the SPI variant select pins
		unsigned int vsel:3;
			
		///Status of the mode bits
		unsigned int mode:3;
				
		///Status of the INIT_B pin
		unsigned int init_b:1;
		
		///Status of the DONE pin
		unsigned int done:1;
		
		///True if there was a post-config CRC error
		unsigned int seu_err:1;
		
		///True if the config watchdog timer ran out
		unsigned int sync_timeout:1;			
	} __attribute__ ((packed)) bits;
	
	///The raw status register value
	uint32_t word;
} __attribute__ ((packed));

/** 
	@brief A Xilinx Spartan-3A FPGA device
	
	\ingroup libjtaghal
 */
class XilinxSpartan3ADevice	: public XilinxFPGA
{
public:
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Construction / destruction
	XilinxSpartan3ADevice(
		unsigned int arraysize,
		unsigned int rev,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	virtual ~XilinxSpartan3ADevice();

	static JtagDevice* CreateDevice(
		unsigned int arraysize,
		unsigned int rev,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
		
	///JTAG device IDs
	enum deviceids
	{
		///XC3S50A
		SPARTAN3A_50A  = 0x10
	};
	
	//WARNING: XAPP452 does not apply to Spartan-3A!!!
	
	///6-bit-wide JTAG instructions (see UG332 table 9-5 on page 207)
	enum instructions
	{
		///User-defined instruction 1
		INST_USER1				= 0x02,
		
		///User-defined instruction 2
		INST_USER2				= 0x03,
	
		//no USER3/USER4 in Spartan-3 series!
		
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
		///Note that this opcode isn't the same as Spartan-6.
		INST_ISC_DNA			= 0x31,
		
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
	/*
	void ReadWordsConfigRegister(unsigned int reg, uint16_t* dout, unsigned int count);
	void WriteWordConfigRegister(unsigned int reg, uint16_t value);
	*/
	virtual XilinxFPGABitstream* ParseBitstreamInternals(const unsigned char* data, size_t len, XilinxFPGABitstream* bitstream, size_t fpos, bool bVerbose = false);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Configuration type definitions
protected:
	
	/**
		@brief Spartan-3A configuration opcodes (see UG332 page 323)
	 */
	enum spartan3a_config_opcodes
	{
		S3A_CONFIG_OP_NOP	= 0,
		S3A_CONFIG_OP_READ	= 1,
		S3A_CONFIG_OP_WRITE	= 2
	};

	/** 
		@brief Spartan-3A configuration frame types (see UG332 page 323)
	 */
	enum spartan3a_config_frame_types
	{
		S3A_CONFIG_FRAME_TYPE_1 = 1,
		S3A_CONFIG_FRAME_TYPE_2 = 2
	};

	/**
		@brief Spartan-3A configuration registers (see UG332 page 325)
	 */
	enum spartan3a_config_regs
	{
		S3A_CONFIG_REG_CRC		= 0x00,
		S3A_CONFIG_REG_FAR_MAJ	= 0x01,
		S3A_CONFIG_REG_FAR_MIN	= 0x02,
		S3A_CONFIG_REG_FDRI		= 0x03,
		S3A_CONFIG_REG_FDRO		= 0x04,
		S3A_CONFIG_REG_CMD		= 0x05,
		S3A_CONFIG_REG_CTL		= 0x06,
		S3A_CONFIG_REG_MASK		= 0x07,
		S3A_CONFIG_REG_STAT		= 0x08,
		S3A_CONFIG_REG_LOUT		= 0x09,
		S3A_CONFIG_REG_COR1		= 0x0a,
		S3A_CONFIG_REG_COR2		= 0x0b,
		S3A_CONFIG_REG_PWRDN	= 0x0c,
		S3A_CONFIG_REG_FLR		= 0x0d,
		S3A_CONFIG_REG_IDCODE	= 0x0e,
		//SNOWPLOW = 0x0f, undocumented/unimplemented
		S3A_CONFIG_REG_HCOPT	= 0x10,
		//0x11 reserved
		S3A_CONFIG_REG_CSBO		= 0x12,
		S3A_CONFIG_REG_GENERAL1	= 0x13,
		S3A_CONFIG_REG_GENERAL2 = 0x14,
		S3A_CONFIG_REG_MODE_REG	= 0x15,
		S3A_CONFIG_REG_PU_GWE	= 0x16,
		S3A_CONFIG_REG_PU_GTS	= 0x17,
		S3A_CONFIG_REG_MFWR		= 0x18,
		S3A_CONFIG_REG_CCLK_FREQ = 0x19,
		S3A_CONFIG_REG_SEU_OPT	= 0x1a,
		S3A_CONFIG_REG_EXP_SIGN	= 0x1b,
		S3A_CONFIG_REG_RDBK_SIGN = 0x1c,
		
		S3A_CONFIG_REG_MAX		//max config reg value
	};
	
	/**
		@brief Spartan-3A CMD register values (see UG332 page 325-326)
	 */
	enum spartan3a_cmd_values
	{
		S3A_CMD_NULL		= 0x0,
		S3A_CMD_WCFG		= 0x1,
		S3A_CMD_MFWR		= 0x2,
		S3A_CMD_LFRM		= 0x3,
		S3A_CMD_RCFG		= 0x4,
		S3A_CMD_START		= 0x5,
		S3A_CMD_RCAP		= 0x6,
		S3A_CMD_RCRC		= 0x7,
		S3A_CMD_AGHIGH		= 0x8,
		//value 0x9 reserved
		S3A_CMD_GRESTORE	= 0xa,
		S3A_CMD_SHUTDOWN	= 0xb,
		S3A_CMD_GCAPTURE	= 0xc,
		S3A_CMD_DESYNC		= 0xd,
		S3A_CMD_REBOOT		= 0xe,
		//value 0xf not used
	};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helpers for chain manipulation
protected:	
	void SetIR(unsigned char irval)
	{ JtagDevice::SetIR(&irval, m_irlength); }
	
	void SetIRDeferred(unsigned char irval)
	{ JtagDevice::SetIRDeferred(&irval, m_irlength); }
	
public:
	unsigned int GetArraySize()
	{ return m_arraysize; }
	
protected:
	///Array size (the specific Spartan-6 device we are)
	unsigned int m_arraysize;
	
	///Stepping number
	unsigned int m_rev;
};

#endif
