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

GridRouter::GridRouter(uint16_t low, uint16_t high, xypos pos)
	: NOCRouter(low, high, pos)
{
	for(int i=0; i<4; i++)
		m_neighbors[i] = NULL;
	for(int i=0; i<16; i++)
		m_children[i] = NULL;

	for(int i=0; i<20; i++)
	{
		m_outboxBlocked[i] = false;
		m_inboxValid[i] = false;
		m_inboxForwardTime[i] = 0;
		m_outboxClearTime[i] = 0;
	}

	m_rrcount = 0;

	m_ypos = m_subnetLow >> 6;
	m_xpos = (m_subnetLow >> 4) & 0x3;
}

GridRouter::~GridRouter()
{
}

void GridRouter::AddChild(SimNode* child)
{
	auto node = dynamic_cast<NOCHost*>(child);
	if(node == NULL)
	{
		LogWarning("Can't add child (not a host)\n");
		return;
	}

	m_children[node->GetAddress() & 0xf] = child;
}

void GridRouter::AddNeighbor(int direction, GridRouter* peer)
{
	m_neighbors[direction] = peer;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

void GridRouter::ExpandBoundingBox(unsigned int& width, unsigned int& height)
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

void GridRouter::RenderSVGNodes(FILE* fp)
{
	const unsigned int nodesize = 10;
	const unsigned int radius = nodesize / 2;

	fprintf(
		fp,
		"<circle cx=\"%u\" cy=\"%u\" r=\"%u\" stroke=\"green\" stroke-width=\"1\" fill=\"white\"/>\n",
		m_renderPosition.first,
		m_renderPosition.second,
		radius);
}

void GridRouter::RenderSVGLines(FILE* fp)
{
	for(int i=0; i<4; i++)
	{
		auto c = m_neighbors[i];
		if(c == NULL)	//null neighbors are legal at edge of network
			continue;
		fprintf(fp,
			"<line x1=\"%u\" y1=\"%u\" x2=\"%u\" y2=\"%u\" stroke=\"cyan\" stroke-width=\"1\" />\n",
			c->m_renderPosition.first,
			c->m_renderPosition.second,
			m_renderPosition.first,
			m_renderPosition.second);
	}

	for(int i=0; i<16; i++)
	{
		auto c = m_children[i];
		if(c == NULL)
			continue;
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

unsigned int GridRouter::GetPortNumber(SimNode* node)
{
	auto router = dynamic_cast<GridRouter*>(node);
	if(router)
		return GetPortNumber(router->GetSubnetBase());

	auto host = dynamic_cast<NOCHost*>(node);
	if(!host)
	{
		LogWarning("Node is not a router or host\n");
		return 0;
	}
	return GetPortNumber(host->GetAddress());
}

unsigned int GridRouter::GetPortNumber(uint16_t addr)
{
	//In our subnet? Just use the low LSBs
	if( (addr & 0xfff0) == m_subnetLow)
		return (addr & 0x000f);

	//Not in our subnet. Find the Manhattan vector between us and them
	unsigned int target_ypos = addr >> 6;
	unsigned int target_xpos = (addr >> 4) & 0x3;
	int dx = target_xpos - m_xpos;
	int dy = target_ypos - m_ypos;

	/*
	LogDebug("[%5u] GridRouter (%u, %u): routing to (%u, %u), vector (%d, %d)\n",
		g_time,
		m_xpos, m_ypos,
		target_xpos, target_ypos,
		dx, dy);
	*/

	//Easy case: if offset along one axis only, move in that direction
	if( (dx > 0) && (dy == 0) )	//target is east of us
		return 17;
	if( (dx < 0) && (dy == 0) )	//target is west of us
		return 19;
	if( (dx == 0) && (dy > 0) )	//target is south of us
		return 18;
	if( (dx == 0) && (dy < 0) )	//target is north of us
		return 16;

	//Target is diagonal from us, we have to decide which axis to move on first

	//If doing X-Y routing, move along the X axis and only do Y once they're due north/south from us
	if(true)
	{
		if(dx > 0)				//target is north/southeast, move east
			return 17;
		else					//target is north/southwest, move west
			return 19;
	}

	//TODO: pseudorandom routing based on some hash of the addresses
	else
	{
	}
}

bool GridRouter::AcceptMessage(NOCPacket packet, SimNode* from)
{
	unsigned int srcport = GetPortNumber(from);

	//If inbox is already full, reject it!
	if(m_inboxValid[srcport])
	{
		LogError(
			"[%5u] GridRouter (%u, %u): rejecting %d-word message from %04x to %04x (on port %d): bus fight!\n",
			g_time, m_xpos, m_ypos, packet.m_size, packet.m_from, packet.m_to, srcport);
		return false;
	}

	//We're good, accept it
	//LogDebug("[%5u] GridRouter (%u, %u): accepting %d-word message from %04x to %04x (on port %d)\n",
	//	g_time, m_xpos, m_ypos, packet.m_size, packet.m_from, packet.m_to, srcport);
	m_inboxes[srcport] = packet;
	m_inboxValid[srcport] = true;
	m_inboxForwardTime[srcport] = g_time + 4;	//4 cycle forwarding latency assuming 32-bit bus width
	return true;
}

void GridRouter::Timestep()
{
	//Clear any outboxes that became available this clock
	for(int i=0; i<20; i++)
	{
		if(m_outboxBlocked[i] && (m_outboxClearTime[i] < g_time) )
			m_outboxBlocked[i] = false;
	}

	//Try forwarding from our round-robin winner first, they always have first priority
	if(TryForwardFrom(m_rrcount))
		m_rrcount = (m_rrcount + 1);

	//Try forwarding from every other port
	for(int i=0; i<20; i++)
	{
		if(TryForwardFrom(i))
			m_rrcount = (m_rrcount + 1) % 20;
	}
}

/**
	@brief Try forwarding the message located in the specified port's inbox (if present)
 */
bool GridRouter::TryForwardFrom(unsigned int nport)
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
	if( (dstport < 16) && (m_children[dstport] == NULL) )
	{
		LogDebug("[%5u] GridRouter (%u, %u): cannot forward message to %04x: child port is null!\n",
			g_time, m_xpos, m_ypos, packet.m_to);
		m_inboxValid[nport] = false;
		return false;
	}
	else if((dstport >= 16) && (m_neighbors[dstport & 3] == NULL) )
	{
		LogDebug("[%5u] GridRouter (%u, %u): cannot forward message to %04x: neighbor port %d (%d) is null!\n",
			g_time, m_xpos, m_ypos, packet.m_to, dstport & 3, dstport);
		m_inboxValid[nport] = false;
		return false;
	}

	//Forward the packet
	//LogDebug("[%5u] GridRouter (%u, %u): forwarding %d-word message from %04x to %04x (out port %d)\n",
	//	g_time, xpos, ypos, packet.m_size, packet.m_from, packet.m_to, dstport);
	if(dstport >= 16)
		m_neighbors[dstport & 3]->AcceptMessage(packet, this);
	else
		m_children[dstport]->AcceptMessage(packet, this);

	//Output port is busy for the next 4 clocks
	m_outboxBlocked[dstport] = true;
	m_outboxClearTime[dstport] = g_time + 4;

	//Inbox is now available
	m_inboxValid[nport] = false;
	return true;
}
