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

NOCHost::NOCHost(uint16_t addr, NOCRouter* parent, xypos pos)
	: SimNode(pos)
	, m_address(addr)
	, m_parent(parent)
{
	m_parent->AddChild(this);
}

NOCHost::~NOCHost()
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

void NOCHost::ExpandBoundingBox(unsigned int& width, unsigned int& height)
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

void NOCHost::RenderSVGNodes(FILE* fp)
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

void NOCHost::RenderSVGLines(FILE* /*fp*/)
{
	//not a router, nothing to do
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simulation

bool NOCHost::AcceptMessage(NOCPacket packet, SimNode* /*from*/)
{
	//LogDebug("[%5u] NOCHost %04x: accepting %d-word message from %04x\n",
	//	g_time, m_address, packet.m_size, packet.m_from);
	packet.Processed();

	switch(packet.m_type)
	{
		//Respond with a 4-word return
		case NOCPacket::TYPE_RPC_CALL:
			{
				NOCPacket message(m_address, packet.m_from, 4, NOCPacket::TYPE_RPC_RETURN);
				if(!m_parent->AcceptMessage(message, this))
					LogWarning("Couldn't send reply to function call\n");
			}
			break;

		//No action required
		case NOCPacket::TYPE_RPC_RETURN:
			break;

		//No action required
		case NOCPacket::TYPE_RPC_INTERRUPT:
			break;

		//Respond with a DMA read data
		case NOCPacket::TYPE_DMA_READ:
			{
				NOCPacket message(m_address, packet.m_from, packet.m_replysize, NOCPacket::TYPE_DMA_RDATA);
				if(!m_parent->AcceptMessage(message, this))
					LogWarning("Couldn't send reply to DMA read\n");
			}
			break;

		//No action required
		case NOCPacket::TYPE_DMA_RDATA:
			break;

		//Respond with a DMA ack (headers only, no payload)
		case NOCPacket::TYPE_DMA_WRITE:
			{
				NOCPacket message(m_address, packet.m_from, 3, NOCPacket::TYPE_DMA_ACK);
				if(!m_parent->AcceptMessage(message, this))
					LogWarning("Couldn't send reply to DMA write\n");
			}
			break;

		//No action required
		case NOCPacket::TYPE_DMA_ACK:
			break;
	}

	//silently discard
	return true;
}

void NOCHost::Timestep()
{
	//Nothing to do, we don't originate messages
}
