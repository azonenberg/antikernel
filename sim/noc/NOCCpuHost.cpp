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
	@brief A host that simulates a CPU
 */

#include "nocsim.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

NOCCpuHost::NOCCpuHost(uint16_t addr, NOCRouter* parent, xypos pos)
	: NOCHost(addr, parent, pos)
	, m_state(STATE_WAIT_RAM)
	, m_cyclesExecuting(0)
	, m_cyclesWaiting(0)
{

}

NOCCpuHost::~NOCCpuHost()
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simulation

void NOCCpuHost::PrintStats()
{
	LogDebug("[CPU] Cycles spent:\n");
	LogIndenter li;
	LogDebug("Executing                : %5lu (%5.2f %%)\n", m_cyclesExecuting, (m_cyclesExecuting * 100.0f) / g_time);
	LogDebug("Waiting for RAM          : %5lu (%5.2f %%)\n", m_cyclesWaiting, (m_cyclesWaiting * 100.0f) / g_time);
}

bool NOCCpuHost::AcceptMessage(NOCPacket packet, SimNode* /*from*/)
{
	//We got this message
	//LogDebug("[%5u] NOCCpuHost %04x: accepting %d-word message from %04x\n",
	//	g_time, m_address, packet.m_size, packet.m_from);
	packet.Processed();

	//If we get a DMA data message and were waiting on RAM, then unblock
	if( (m_state == STATE_WAIT_RAM) && (packet.m_type == NOCPacket::TYPE_DMA_RDATA) )
	{
		//LogDebug("[%5u] Got cache line, unblocking CPU\n", g_time);
		m_state = STATE_EXECUTING;
	}

	return true;
}

void NOCCpuHost::Timestep()
{
	//Stat collection
	switch(m_state)
	{
		case STATE_WAIT_RAM:
			m_cyclesWaiting ++;
			break;

		case STATE_EXECUTING:
			m_cyclesExecuting ++;
			break;
	}

	//At time 0: generate a DMA read request for our first cache line
	if(g_time == 0)
	{
		//LogDebug("[%5u] Sending initial RAM read request\n", g_time);

		NOCPacket message(m_address, RAM_ADDR, 3, NOCPacket::TYPE_DMA_READ, 3+32);
		if(!m_parent->AcceptMessage(message, this))
			LogWarning("Couldn't send initial message\n");
	}

	//If executing, do stuff
	if(m_state == STATE_EXECUTING)
	{
		//For now: 1% L1 cache miss rate
		if(0 == (rand() % 100) )
		{
			//LogDebug("[%5u] Cache miss, requesting new data\n", g_time);
			NOCPacket message(m_address, RAM_ADDR, 3, NOCPacket::TYPE_DMA_READ, 3+32);
			if(!m_parent->AcceptMessage(message, this))
				LogWarning("Couldn't send RAM read message\n");

			m_state = STATE_WAIT_RAM;
		}

		//TODO: talk to peripherals
	}
}
