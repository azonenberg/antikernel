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
	@brief A node on one of the networks
 */

#include "nocsim.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

NOCHost::NOCHost(uint16_t addr, NOCRouter* parent)
	: m_address(addr)
	, m_parent(parent)
{
	m_parent->AddChild(this);
}

NOCHost::~NOCHost()
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simulation

bool NOCHost::AcceptMessage(NOCPacket packet, SimNode* /*from*/)
{
	LogDebug("[%5u] NOCHost %04x: accepting %d-word message from %04x\n",
		g_time, m_address, packet.m_size, packet.m_from);

	//silently discard
	return true;
}

void NOCHost::Timestep()
{
	//DEBUG: generate a single packet crossing the network from end to end
	if( (g_time == 4) && (m_address == 0) )
	{
		NOCPacket message(m_address, 0xff, 4);
		if(!m_parent->AcceptMessage(message, this))
			LogWarning("Couldn't send initial message\n");
	}
}
