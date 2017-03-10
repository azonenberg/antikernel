/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
	@brief Implementation of JTAGNOCBridgeInterface
 */
#include "nocbridge.h"
#include "JtagDebugBridge_addresses_enum.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

JTAGNOCBridgeInterface::JTAGNOCBridgeInterface()
{
	//Populate free list
	for(unsigned int i = DEBUG_LOW_ADDR; i <= DEBUG_HIGH_ADDR; i++)
		m_freeAddresses.emplace(i);
}

JTAGNOCBridgeInterface::~JTAGNOCBridgeInterface()
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Address allocation

bool JTAGNOCBridgeInterface::AllocateClientAddress(uint16_t& addr)
{
	//Pop free list, if we have anything there
	if(m_freeAddresses.empty())
		return false;

	addr = *m_freeAddresses.begin();
	m_freeAddresses.erase(addr);

	return true;
}

void JTAGNOCBridgeInterface::FreeClientAddress(uint16_t addr)
{
	//Disable "comparison is always false due to limited range of data type" warnings for here
	//If DEBUG_*_ADDR are at the low/high ends of the address range some comparisons are pointless
	//but we need them there to keep the code generic.
	#pragma GCC diagnostic push
	#pragma GCC diagnostic ignored "-Wtype-limits"

	//Warn if we try to do something stupid
	if( (addr < DEBUG_LOW_ADDR) || (addr > DEBUG_HIGH_ADDR) )
	{
		LogWarning("JTAGNOCBridgeInterface: Attempted to free client address %04x, which isn't in the debug subnet\n",
			addr);
		return;
	}

	#pragma GCC diagnostic pop

	//If it's already free, something is funky
	if(m_freeAddresses.find(addr) != m_freeAddresses.end())
	{
		LogWarning("JTAGNOCBridgeInterface: Attempted to free client address %04x, which was already free\n",
			addr);
		return;
	}

	//Nope, we're good
	m_freeAddresses.emplace(addr);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// The actual JTAG bridge stuff

void JTAGNOCBridgeInterface::Poll()
{

}
