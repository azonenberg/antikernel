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
	//, m_subnetMask(mask)
	//, m_parentRouter(parent)
{
	for(int i=0; i<4; i++)
		m_neighbors[i] = NULL;
	for(int i=0; i<16; i++)
		m_children[i] = NULL;

	/*
	if(m_parentRouter)
		m_parentRouter->AddChild(this);

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
	*/
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


bool GridRouter::AcceptMessage(NOCPacket packet, SimNode* from)
{
	return true;
}

void GridRouter::Timestep()
{
}
