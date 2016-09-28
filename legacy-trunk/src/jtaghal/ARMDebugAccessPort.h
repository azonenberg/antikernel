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
	@brief Declaration of ARMDebugAccessPort
 */

#ifndef ARMDebugAccessPort_h
#define ARMDebugAccessPort_h

#include <stdlib.h>

class ARMDebugPort;

/**
	@brief ARM debug port identification register (see ADIv5 Architecture Specification figure 6-3)
 */
union ARMDebugPortIDRegister
{
	struct
	{
		///Type of AP
		unsigned int type:4;
		
		///Variant of AP
		unsigned int variant:4;
		
		///Reserved, SBZ
		unsigned int reserved_zero:8;
		
		///Class (1 = mem-AP, 0=not mem-AP)
		unsigned int is_mem_ap:1;
		
		///Identity code (must be 0x3B)
		unsigned int identity:7;
		
		///Continuation code (must be 0x4)
		unsigned int continuation:4;
		
		///Revision of the AP design
		unsigned int revision : 4;
		
	} __attribute__ ((packed)) bits;
	
	///The raw status register value
	uint32_t word;
} __attribute__ ((packed));

/**
	@brief An AP attached to an ADIv5 DP
	
	\ingroup libjtaghal
 */
class ARMDebugAccessPort
{
public:
	ARMDebugAccessPort(ARMDebugPort* dp, uint8_t apnum, ARMDebugPortIDRegister id);
	virtual ~ARMDebugAccessPort();
	
	enum dap_type
	{
		DAP_JTAG = 0,
		DAP_AHB = 1,
		DAP_APB = 2,
		DAP_INVALID
	};
	
	dap_type GetBusType()
	{ return m_daptype; }
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General device info
	
	virtual void PrintStatusRegister() =0;
	virtual bool IsEnabled() =0;
	
	virtual std::string GetDescription() =0;
	
	ARMDebugPort* GetDebugPort()
	{ return m_dp; }
	
protected:
	ARMDebugPort* m_dp;
	uint8_t m_apnum;
	ARMDebugPortIDRegister m_id;
	dap_type m_daptype;
};

#endif
