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

QuadtreeRouter::QuadtreeRouter(QuadtreeRouter* parent, uint16_t low, uint16_t high, uint16_t mask)
	: NOCRouter(low, high)
	, m_parentRouter(parent)
	, m_subnetMask(mask)
{
	for(int i=0; i<4; i++)
		m_children[i] = NULL;

	unsigned int size = GetSubnetSize();
	uint16_t childMask = 0xffff & ~( (size/4) - 1);
	m_portMask = childMask & ~mask;
	m_portShift = log2(size) - 2;
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
// Simulation

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

	return (addr & m_portMask) >> m_portShift;
}

bool QuadtreeRouter::AcceptMessage(NOCPacket packet, SimNode* from)
{
	//silently discard
	return true;
}

void QuadtreeRouter::Timestep()
{

}
