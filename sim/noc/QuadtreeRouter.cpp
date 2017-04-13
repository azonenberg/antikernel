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
	@brief A router on one of the networks
 */

#include "nocsim.h"
#include <math.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

QuadtreeRouter::QuadtreeRouter(QuadtreeRouter* parent, uint16_t low, uint16_t high, uint16_t mask, xypos pos)
	: NOCRouter(low, high, pos)
	, m_subnetMask(mask)
	, m_parentRouter(parent)
{
	if(m_parentRouter)
		m_parentRouter->AddChild(this);

	for(int i=0; i<4; i++)
		m_children[i] = NULL;
	for(int i=0; i<5; i++)
	{
		m_outboxBlocked[i] = false;
		m_inboxValid[i] = false;
		m_inboxForwardTime[i] = 0;
		m_outboxClearTime[i] = 0;
	}

	unsigned int size = GetSubnetSize();
	uint16_t childMask = 0xffff & ~( (size/4) - 1);
	m_portMask = childMask & ~mask;
	m_portShift = log2(size) - 2;

	m_rrcount = 0;
}

QuadtreeRouter::~QuadtreeRouter()
{
}

void QuadtreeRouter::AddChild(SimNode* child)
{
	unsigned int port = GetPortNumber(child);

	if( port <= 3 )
		m_children[port] = child;

	else
		LogWarning("Can't add child (invalid address)\n");
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

void QuadtreeRouter::ExpandBoundingBox(unsigned int& width, unsigned int& height)
{
	const unsigned int nodesize = 10;
	const unsigned int radius = nodesize / 2;
	const unsigned int right = m_renderPosition.first + radius;
	const unsigned int bottom = m_renderPosition.second + radius;

	if(width < right)
		width = right;
	if(height < bottom)
		height = bottom;
}

void QuadtreeRouter::RenderSVGNodes(FILE* fp)
{
	const unsigned int nodesize = 10;
	const unsigned int radius = nodesize / 2;

	fprintf(
		fp,
		"<circle cx=\"%u\" cy=\"%u\" r=\"%u\" stroke=\"black\" stroke-width=\"1\" fill=\"white\"/>\n",
		m_renderPosition.first,
		m_renderPosition.second,
		radius);
}

void QuadtreeRouter::RenderSVGLines(FILE* fp)
{
	for(int i=0; i<4; i++)
	{
		auto c = m_children[i];
		fprintf(fp,
			"<line x1=\"%u\" y1=\"%u\" x2=\"%u\" y2=\"%u\" stroke=\"blue\" stroke-width=\"1\" />\n",
			c->m_renderPosition.first,
			c->m_renderPosition.second,
			m_renderPosition.first,
			m_renderPosition.second);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simulation

/**
	@brief See which port a given node is attached to
 */
unsigned int QuadtreeRouter::GetPortNumber(SimNode* node)
{
	auto router = dynamic_cast<QuadtreeRouter*>(node);
	auto host = dynamic_cast<NOCHost*>(node);

	//Figure out the base address of our target node
	uint16_t addr = 0;
	if(router)
		addr = router->m_subnetLow;

	else if(host)
		addr = host->GetAddress();

	else
	{
		LogError("Invalid sim node (not a quadtree router or host)\n");
		return 4;
	}

	return GetPortNumber(addr);
}

/**
	@brief See which port a given address is attached to
 */
unsigned int QuadtreeRouter::GetPortNumber(uint16_t addr)
{
	//Not in our subnet? Go up
	if( (addr & m_subnetMask) != m_subnetLow)
		return 4;

	return (addr & m_portMask) >> m_portShift;
}

bool QuadtreeRouter::AcceptMessage(NOCPacket packet, SimNode* from)
{
	unsigned int srcport = GetPortNumber(from);

	//If inbox is already full, reject it!
	if(m_inboxValid[srcport])
	{
		LogError("[%5u] QuadtreeRouter %04x/%d: rejecting %d-word message from %04x (on port %d): bus fight!\n",
			g_time, m_subnetLow, 16 - m_portShift, packet.m_size, packet.m_from, srcport);
		return false;
	}

	//We're good, accept it
	LogDebug("[%5u] QuadtreeRouter %04x/%d: accepting %d-word message from %04x to %04x (on port %d)\n",
		g_time, m_subnetLow, 16 - m_portShift, packet.m_size, packet.m_from, packet.m_to, srcport);
	m_inboxes[srcport] = packet;
	m_inboxValid[srcport] = true;
	m_inboxForwardTime[srcport] = g_time + 4;	//4 cycle forwarding latency assuming 32-bit bus width
	return true;
}

void QuadtreeRouter::Timestep()
{
	//Clear any outboxes that became available this clock
	for(int i=0; i<5; i++)
	{
		if(m_outboxBlocked[i] && (m_outboxClearTime[i] >= g_time) )
			m_outboxBlocked[i] = false;
	}

	//Try forwarding from our round-robin winner first, they always have first priority
	if(TryForwardFrom(m_rrcount))
		m_rrcount = (m_rrcount + 1);

	//Try forwarding from every other port
	for(int i=0; i<5; i++)
	{
		if(TryForwardFrom(i))
			m_rrcount = (m_rrcount + 1);
	}
}

/**
	@brief Try forwarding the message located in the specified port's inbox (if present)
 */
bool QuadtreeRouter::TryForwardFrom(unsigned int nport)
{
	//If inbox is empty, nothing to do
	if(!m_inboxValid[nport])
		return false;

	//If we're still receiving this packet, nothing to do
	if(m_inboxForwardTime[nport] > g_time)
		return false;

	auto& packet = m_inboxes[nport];

	//Packet is forwardable. See where it goes.
	unsigned int dstaddr = m_inboxes[nport].m_to;
	unsigned int dstport = GetPortNumber(dstaddr);

	//If the destination port is currently occupied, we can't do anything this cycle
	if(m_outboxBlocked[dstport])
		return false;

	//If message is unforwardable, drop it
	if( (dstport == 4) && (m_parentRouter == NULL) )
	{
		LogDebug("[%5u] QuadtreeRouter %04x/%d: cannot forward message to %d: address isn't in root subnet!\n",
			g_time, m_subnetLow, 16 - m_portShift, packet.m_to);
		m_inboxValid[nport] = false;
	}

	//Forward the packet
	//TODO: allow empty/NULL child ports?
	LogDebug("[%5u] QuadtreeRouter %04x/%d: forwarding %d-word message from %04x to %04x (out port %d)\n",
		g_time, m_subnetLow, 16 - m_portShift, packet.m_size, packet.m_from, packet.m_to, dstport);
	if(dstport == 4)
		m_parentRouter->AcceptMessage(packet, this);
	else if(m_children[dstport])
		m_children[dstport]->AcceptMessage(packet, this);
	else
		LogError("child port %d is NULL\n", dstport);

	//Output port is busy for the next 4 clocks
	m_outboxBlocked[dstport] = true;
	m_outboxClearTime[dstport] = g_time + 4;

	//Inbox is now available
	m_inboxValid[nport] = false;
	return true;
}
