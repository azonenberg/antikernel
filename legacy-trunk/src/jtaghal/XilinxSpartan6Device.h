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
	@brief Declaration of XilinxSpartan6Device
 */

#ifndef XilinxSpartan6Device_h
#define XilinxSpartan6Device_h

#include "XilinxFPGA.h"

#include <list>

/**
	@brief Spartan-6 configuration frame (see UG380 page 91)
	
	For type 2 packets, the header is followed by a 32-bit big-endian length value
	
	\ingroup libjtaghal
 */
union XilinxSpartan6DeviceConfigurationFrame
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
			\li	XilinxSpartan6Device::S6_CONFIG_OP_NOP
			\li XilinxSpartan6Device::S6_CONFIG_OP_READ
			\li XilinxSpartan6Device::S6_CONFIG_OP_WRITE
		 */
		unsigned int op:2;			
		
		/**
			@brief Frame type
			
			Must be one of the following:
			\li XilinxSpartan6Device::S6_CONFIG_FRAME_TYPE_1
			\li XilinxSpartan6Device::S6_CONFIG_FRAME_TYPE_2
		 */
		unsigned int type:3;
	} __attribute__ ((packed)) bits;
	
	/// The raw configuration word
	uint16_t word;
} __attribute__ ((packed));

/**
	@brief Spartan-6 status register (see UG380 table 5-35)
	
	Typical status register bits:
		\li [0] CRC ERROR                                                              :         0
		\li [1] IDCODE ERROR                                                           :         0
		\li [2] DCM LOCK STATUS                                                        :         1
		\li [3] GTS_CFG_B STATUS                                                       :         1
		\li [4] GWE STATUS                                                             :         1
		\li [5] GHIGH STATUS                                                           :         1
		\li [6] DECRYPTION ERROR                                                       :         0
		\li [7] DECRYPTOR ENABLE                                                       :         0
		\li [8] HSWAPEN PIN                                                            :         1
		\li [9] MODE PIN M[0]                                                          :         1
		\li [10] MODE PIN M[1]                                                         :         1
		\li [11] RESERVED                                                              :         0
		\li [12] INIT_B PIN                                                            :         1
		\li [13] DONE PIN                                                              :         1
		\li [14] SUSPEND STATUS                                                        :         0
		\li [15] FALLBACK STATUS                                                       :         0
		
	\ingroup libjtaghal
 */
union XilinxSpartan6DeviceStatusRegister
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
		
		///Decryption error flag
		unsigned int decrypt_err:1;
		
		///Bitstream encryption enable flag
		unsigned int decrypt_en:1;
		
		///Status of the HSWAPEN pin
		unsigned int hswapen:1;
		
		///Status of the M0 mode bit
		unsigned int m0:1;
		
		///Status of the M1 mode bit
		unsigned int m1:1;
		
		///Reserved
		unsigned int reserved:1;
		
		///Status of the INIT_B pin
		unsigned int init_b:1;
		
		///Status of the DONE pin
		unsigned int done:1;
		
		///Suspend state
		unsigned int suspend:1;
		
		///Configuration fallback state
		unsigned int fallback:1;			
	} __attribute__ ((packed)) bits;
	
	///The raw status register value
	uint16_t word;
} __attribute__ ((packed));

/** 
	@brief A Xilinx Spartan-6 FPGA device
	
	\ingroup libjtaghal
 */
class XilinxSpartan6Device	: public XilinxFPGA
{
public:
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Construction / destruction
	XilinxSpartan6Device(
		unsigned int arraysize,
		unsigned int rev,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	virtual ~XilinxSpartan6Device();

	static JtagDevice* CreateDevice(
		unsigned int arraysize,
		unsigned int rev,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	
	///JTAG device IDs
	enum deviceids
	{
		///XC6SLX9
		SPARTAN6_LX9  = 1,
		
		///XC6SLX16
		SPARTAN6_LX16 = 2,
		
		///XC6SLX25
		SPARTAN6_LX25 = 4,
		
		///XC6SLX45
		SPARTAN6_LX45 = 8
	};
	
	///6-bit-wide JTAG instructions (see UG380 table 10-2)
	enum instructions
	{
		///User-defined instruction 1
		INST_USER1				= 0x02,
		
		///User-defined instruction 2
		INST_USER2				= 0x03,
		
		///User-defined instruction 3
		INST_USER3				= 0x1A,
		
		///User-defined instruction 4
		INST_USER4				= 0x1B,
		
		///Read configuration register
		INST_CFG_OUT			= 0x04,
		
		///Write configuration register
		INST_CFG_IN				= 0x05,
		
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
		INST_ISC_DNA			= 0x30,
		
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
	uint16_t ReadWordConfigRegister(unsigned int reg);
	void ReadWordsConfigRegister(unsigned int reg, uint16_t* dout, unsigned int count);
	void WriteWordConfigRegister(unsigned int reg, uint16_t value);
	
	virtual XilinxFPGABitstream* ParseBitstreamInternals(const unsigned char* data, size_t len, XilinxFPGABitstream* bitstream, size_t fpos, bool bVerbose = false);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Configuration type definitions
protected:
	
	/**
		@brief Spartan-6 configuration opcodes (see UG380 page 90)
	 */
	enum spartan6_config_opcodes
	{
		S6_CONFIG_OP_NOP	= 0,
		S6_CONFIG_OP_READ	= 1,
		S6_CONFIG_OP_WRITE	= 2
	};

	/** 
		@brief Spartan-6 configuration frame types (see UG380 page 91)
	 */
	enum spartan6_config_frame_types
	{
		S6_CONFIG_FRAME_TYPE_1 = 1,
		S6_CONFIG_FRAME_TYPE_2 = 2
	};

	/**
		@brief Spartan-6 configuration registers (see UG380 page 92)
	 */
	enum spartan6_config_regs
	{
		S6_CONFIG_REG_CRC		= 0x00,
		S6_CONFIG_REG_FAR_MAJ	= 0x01,
		S6_CONFIG_REG_FAR_MIN	= 0x02,
		S6_CONFIG_REG_FDRI		= 0x03,
		S6_CONFIG_REG_FDRO		= 0x04,
		S6_CONFIG_REG_CMD		= 0x05,
		S6_CONFIG_REG_CTL		= 0x06,
		S6_CONFIG_REG_MASK		= 0x07,
		S6_CONFIG_REG_STAT		= 0x08,
		S6_CONFIG_REG_LOUT		= 0x09,
		S6_CONFIG_REG_COR1		= 0x0a,
		S6_CONFIG_REG_COR2		= 0x0b,
		S6_CONFIG_REG_PWRDN		= 0x0c,
		S6_CONFIG_REG_FLR		= 0x0d,
		S6_CONFIG_REG_IDCODE	= 0x0e,
		S6_CONFIG_REG_CWDT		= 0x0f,
		S6_CONFIG_REG_HC_OPT	= 0x10,
		//0x11 not used or undocumented
		S6_CONFIG_REG_CSBO		= 0x12,
		S6_CONFIG_REG_GENERAL1	= 0x13,
		S6_CONFIG_REG_GENERAL2	= 0x14,
		S6_CONFIG_REG_GENERAL3	= 0x15,
		S6_CONFIG_REG_GENERAL4	= 0x16,
		S6_CONFIG_REG_GENERAL5	= 0x17,
		S6_CONFIG_REG_MODE		= 0x18,
		S6_CONFIG_REG_PU_GWE	= 0x19,
		S6_CONFIG_REG_PU_GTS	= 0x1a,
		S6_CONFIG_REG_MFWR		= 0x1b,
		S6_CONFIG_REG_CCLK_FREQ	= 0x1c,
		S6_CONFIG_REG_SEU_OPT	= 0x1d,
		S6_CONFIG_REG_EXP_SIGN	= 0x1e,
		S6_CONFIG_REG_RDBK_SIGN	= 0x1f,
		S6_CONFIG_REG_BOOTSTS	= 0x20,
		S6_CONFIG_REG_EYE_MASK	= 0x21,
		S6_CONFIG_REG_CBC		= 0x22,
		
		S6_CONFIG_REG_MAX		//max config reg value
	};
	
	/**
		@brief Spartan-6 CMD register values (see UG380 page 94-95)
	 */
	enum spartan6_cmd_values
	{
		S6_CMD_NULL			= 0x0,
		S6_CMD_WCFG			= 0x1,
		S6_CMD_MFW			= 0x2,
		S6_CMD_LFRM			= 0x3,
		S6_CMD_RCFG			= 0x4,
		S6_CMD_START		= 0x5,
		//value 0x6 not used
		S6_CMD_RCRC			= 0x7,
		S6_CMD_AGHIGH		= 0x8,
		//value 0x9 not used
		S6_CMD_GRESTORE		= 0xa,
		S6_CMD_SHUTDOWN		= 0xb,
		//value 0xc not used
		S6_CMD_DESYNC		= 0xd,
		S6_CMD_IPROG		= 0xe,
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
