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
	@brief A packet on one of the networks
 */

#include "nocsim.h"

unsigned int NOCPacket::m_minLatency = 0xffffffff;
unsigned int NOCPacket::m_maxLatency = 0;
unsigned int NOCPacket::m_totalPackets = 0;
unsigned long NOCPacket::m_totalLatency = 0;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

NOCPacket::NOCPacket(uint16_t f, uint16_t t, unsigned int s, msgType type, unsigned int replysize)
	: m_from(f)
	, m_to(t)
	, m_size(s)
	, m_replysize(replysize)
	, m_type(type)
	, m_timeSent(g_time)
{
}

NOCPacket::~NOCPacket()
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simulation

void NOCPacket::Processed()
{
	unsigned int latency = g_time - m_timeSent;
	if(m_minLatency > latency)
		m_minLatency = latency;
	if(m_maxLatency < latency)
		m_maxLatency = latency;
	m_totalPackets ++;
	m_totalLatency += latency;
}

void NOCPacket::PrintStats()
{
	if(m_totalPackets == 0)
		return;

	LogDebug("[NOC] Packets:\n");
	LogIndenter li;
	LogDebug("Sent                     : %5u\n", m_totalPackets);
	LogDebug("Latency (min/avg/max)    : %5u / %5lu / %5u\n", m_minLatency, m_totalLatency/m_totalPackets, m_maxLatency);
}
