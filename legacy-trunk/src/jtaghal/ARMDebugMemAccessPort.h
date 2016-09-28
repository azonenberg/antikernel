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
	@brief Declaration of ARMDebugMemAccessPort
 */

#ifndef ARMDebugMemAccessPort_h
#define ARMDebugMemAccessPort_h

#include <stdlib.h>

/**
	@brief ARM debug port identification register (see ADIv5 Architecture Specification figure 6-3)
 */
union ARMDebugMemAPControlStatusWord
{
	struct
	{
		///Size of the access to perform
		unsigned int size:3;
		
		///Reserved, should be zero
		unsigned int reserved_zero_1:1;
		
		///Address increment/pack mode
		unsigned int auto_increment:2;
		
		///Debug port enable (RO)
		unsigned int enable:1;
		
		///Transfer in progress
		unsigned int busy:1;
		
		///Operating mode (write as zero, read undefined)
		unsigned int mode:4;
		
		///Reserved, should be zero
		unsigned int reserved_zero_2:11;
		
		///Secure privileged debug flag (not sure what this is)
		unsigned int secure_priv_debug:1;
		
		///Bus access protection (implementation defined)
		unsigned int bus_protect:7;
		
		///Debug software access enable (implementation defined)
		unsigned int debug_sw_enable:1;
		
	} __attribute__ ((packed)) bits;
	
	///The raw status register value
	uint32_t word;
} __attribute__ ((packed));

#include "ARMDebugPeripheralIDRegister.h"

class ARMDebugAccessPort;
class ARMAPBDevice;

/**
	@brief A memory mapped debug interface
	
	\ingroup libjtaghal
 */
class ARMDebugMemAccessPort : public ARMDebugAccessPort
{
public:
	ARMDebugMemAccessPort(ARMDebugPort* dp, uint8_t apnum, ARMDebugPortIDRegister id);
	virtual ~ARMDebugMemAccessPort();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Memory access
	
	uint32_t ReadWord(uint32_t addr);
	
	void WriteWord(uint32_t addr, uint32_t value);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General device info
	
	enum AccessSize
	{
		ACCESS_BYTE		= 0,
		ACCESS_HALFWORD = 1,
		ACCESS_WORD		= 2,
		ACCESS_INVALID	= 3,
	};
	
	enum ComponentClass
	{
		CLASS_ROMTABLE = 1,
		CLASS_CORESIGHT	= 9
	};
	
	virtual void PrintStatusRegister();
	
	virtual std::string GetDescription();
	
	ARMDebugMemAPControlStatusWord GetStatusRegister();
	
	virtual bool IsEnabled();
	
protected:

	void FindRootRomTable();
	void LoadROMTable(uint32_t baseAddress);
	
	void ProcessDebugBlock(uint32_t base_address);

	bool m_debugBusIsDedicated;
	bool m_hasDebugRom;
	uint32_t m_debugBaseAddress;
	
	///The list of devices found on the AP
	std::vector<ARMAPBDevice*> m_debugDevices;
};

#endif
