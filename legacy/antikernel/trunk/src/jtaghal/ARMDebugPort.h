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
	@brief Declaration of ARMDebugPort
 */

#ifndef ARMDebugPort_h
#define ARMDebugPort_h

#include <stdlib.h>

#include "ARMDevice.h"
#include "DebuggerInterface.h"
#include "ARMDebugAccessPort.h"

/**
	@brief ARM debug port status register (see ADIv5 Architecture Specification figure 6-3)
 */
union ARMDebugPortStatusRegister
{
	struct
	{
		///Set to 1 to enable overrun detection
		unsigned int sticky_overrun_en:1;
		
		///Sticky buffer overrun (if enabled)
		unsigned int sticky_overrun:1;
		
		///Transfer mode
		unsigned int transfer_mode:2;
		
		///Sticky compare bit
		unsigned int sticky_compare:1;
		
		///Sticky error bit
		unsigned int sticky_err:1;
		
		///Read status flag
		unsigned int read_ok:1;
		
		///Write data error flag
		unsigned int wr_data_err:1;
		
		///Byte mask
		unsigned int mask_lane:4;
		
		///Transaction counter
		unsigned int trans_count:12;
		
		///Reserved, should be zero
		unsigned int reserved_zero:2;
		
		///Debug reset request
		unsigned int debug_reset_req:1;
		
		///Debug reset acknowledgement
		unsigned int debug_reset_ack:1;
		
		///Powerup request
		unsigned int debug_pwrup_req:1;
		
		///Powerup acknowledgement
		unsigned int debug_pwrup_ack:1;
		
		///Powerup request
		unsigned int sys_pwrup_req:1;
		
		///Powerup acknowledgement
		unsigned int sys_pwrup_ack:1;
		
	} __attribute__ ((packed)) bits;
	
	///The raw status register value
	uint32_t word;
} __attribute__ ((packed));

class ARMDebugMemAccessPort;

/**
	@brief An ARM debug port (contains one or more APs and a DP)
	
	\ingroup libjtaghal
 */
class ARMDebugPort		: public ARMDevice
						, public DebuggerInterface
{
public:

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Construction / destruction

	ARMDebugPort(
		unsigned int partnum,
		unsigned int rev,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
	virtual ~ARMDebugPort();
	
	static JtagDevice* CreateDevice(
		unsigned int partnum,
		unsigned int rev,
		unsigned int idcode,
		JtagInterface* iface,
		size_t pos);
		
	enum instructions
	{
		INST_IDCODE = 0x0e,
		INST_ABORT = 0x08,
		INST_DPACC = 0x0a,
		INST_APACC = 0x0b,
	};
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General device info

	virtual std::string GetDescription();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Memory access
	
	///Read a single 32-bit word of memory (TODO support smaller sizes)
	virtual uint32_t ReadMemory(uint32_t address);
	
	///Writes a single 32-bit word of memory (TODO support smaller sizes)
	virtual void WriteMemory(uint32_t address, uint32_t value);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helpers for debug port manipulation
	
	//Results from DAP commands
	enum DapResult
	{
		OK_OR_FAULT = 2,
		WAIT = 1
	};
	
	//Read-write flags
	enum RWFlag
	{
		OP_WRITE = 0,
		OP_READ = 1
	};
	
	//Well-defined DP registers
	enum DpReg
	{
		REG_CTRL_STAT = 1,
		REG_AP_SELECT = 2,
		REG_RDBUFF = 3
	};
	
	//Well-defined AP registers
	enum ApReg
	{
		REG_MEM_CSW	 = 0x00,
		REG_MEM_TAR  = 0x04,
		REG_MEM_DRW  = 0x0C,
		REG_MEM_BASE = 0xF8,
		
		REG_IDR		= 0xFC
	};
	
protected:
	ARMDebugPortStatusRegister GetStatusRegister();
	void ClearStatusRegisterErrors();
	void PrintStatusRegister(ARMDebugPortStatusRegister reg);
	
	uint32_t DPRegisterRead(DpReg addr);
	void DPRegisterWrite(DpReg addr, uint32_t wdata);
	
	//need to be a friend so that the Mem-AP can poke registers
	//TODO: try to find a cleaner way to expose this?
	friend class ARMDebugMemAccessPort;
	uint32_t APRegisterRead(uint8_t ap, ApReg addr);
	void APRegisterWrite(uint8_t ap, ApReg addr, uint32_t wdata);
	
	void EnableDebugging();
	
	void DebugAbort();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helpers for chain manipulation
protected:	
	void SetIR(unsigned char irval)
	{ JtagDevice::SetIR(&irval, m_irlength); }
	
	void SetIRDeferred(unsigned char irval)
	{ JtagDevice::SetIRDeferred(&irval, m_irlength); }
	
protected:
	
	///Stepping number
	unsigned int m_rev;
	
	///Part number (normally IDCODE_ARM_DAP_JTAG)
	unsigned int m_partnum;
	
	///Access ports
	std::map<uint8_t, ARMDebugAccessPort*> m_aps;
	
	///The default Mem-AP used for memory access
	ARMDebugMemAccessPort* m_defaultMemAP;
};

#endif

