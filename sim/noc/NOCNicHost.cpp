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
	@brief A host that simulates an Ethernet interface
 */

#include "nocsim.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

NOCNicHost::NOCNicHost(uint16_t addr, NOCRouter* parent, xypos pos)
	: NOCHost(addr, parent, pos)
	, m_rxstate(RX_STATE_IDLE)
	, m_frameBuffers(0)
	, m_cyclesIdle(0)
	, m_cyclesWaitingForMalloc(0)
	, m_cyclesWaitingForWrite(0)
	, m_cyclesWaitingForChown(0)
	, m_cyclesWaitingForSend(0)
	, m_framesProcessed(0)
	, m_framesDropped(0)
	, m_framesTotal(0)
	, m_pendingFrame(false)
	, m_pendingFrameSize(0)
	, m_nextFrame(200)
	, m_nextFrameSize(65)
	, m_returnToIdle(0)
{

}

NOCNicHost::~NOCNicHost()
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simulation

void NOCNicHost::PrintStats()
{
	LogDebug("[NIC] Cycles spent:\n");
	{
		LogIndenter li;
		LogDebug("Idle                     : %5lu (%5.2f %%)\n",
			m_cyclesIdle, (m_cyclesIdle * 100.0f) / g_time);
		LogDebug("Waiting for RPC malloc   : %5lu (%5.2f %%)\n",
			m_cyclesWaitingForMalloc, (m_cyclesWaitingForMalloc * 100.0f) / g_time);
		LogDebug("Waiting for DMA write    : %5lu (%5.2f %%)\n",
			m_cyclesWaitingForWrite, (m_cyclesWaitingForWrite * 100.0f) / g_time);
		LogDebug("Waiting for RPC chown    : %5lu (%5.2f %%)\n",
			m_cyclesWaitingForChown, (m_cyclesWaitingForChown * 100.0f) / g_time);
		LogDebug("Waiting for RPC IRQ send : %5lu (%5.2f %%)\n",
			m_cyclesWaitingForSend, (m_cyclesWaitingForSend * 100.0f) / g_time);
	}

	LogDebug("[NIC] Frames:\n");
	{
		LogIndenter li;
		LogDebug("Processed                : %5lu (%5.2f %%)\n",
			m_framesProcessed, (m_framesProcessed * 100.0f) / m_framesTotal);
		LogDebug("Dropped                  : %5lu (%5.2f %%)\n",
			m_framesDropped, (m_framesDropped * 100.0f) / m_framesTotal);
	}
}

bool NOCNicHost::AcceptMessage(NOCPacket packet, SimNode* /*from*/)
{
	//We got this message
	//LogDebug("[%5u] NOCNicHost %04x: accepting %d-word message from %04x\n",
	//	g_time, m_address, packet.m_size, packet.m_from);
	packet.Processed();

	//State transitions based on incoming messages
	switch(m_rxstate)
	{
		case RX_STATE_IDLE:
			break;

		case RX_STATE_WAIT_ALLOC:

			//If we get a message from RAM, we have a new frame buffer
			if( (packet.m_type == NOCPacket::TYPE_RPC_RETURN) && (packet.m_from == RAM_ADDR) )
			{
				m_frameBuffers ++;
				m_rxstate = RX_STATE_IDLE;
			}

			break;

		case RX_STATE_WAIT_WRITE:

			//If we get a message from RAM, the write is complete.
			//Chown it to the CPU.
			if( (packet.m_type == NOCPacket::TYPE_DMA_ACK) && (packet.m_from == RAM_ADDR) )
			{
				//LogDebug("[%5u] NOCNicHost: Write complete, chowning to CPU\n", g_time);
				NOCPacket message(m_address, RAM_ADDR, 4, NOCPacket::TYPE_RPC_CALL, 4);
				if(!m_parent->AcceptMessage(message, this))
					LogWarning("Couldn't send chown message\n");
				m_rxstate = RX_STATE_WAIT_CHOWN;
			}
			else
			{
				LogWarning("[%5u] NOCNicHost: Don't know what to do with message of type %d from %d\n",
					g_time, packet.m_type, packet.m_from);
			}

			break;

		case RX_STATE_WAIT_CHOWN:

			//If we get a message from RAM, the chown is complete.
			//Send the packet to the CPU
			//LogDebug("[%5u] NOCNicHost: chown complete, sending to CPU\n", g_time);
			if( (packet.m_type == NOCPacket::TYPE_RPC_RETURN) && (packet.m_from == RAM_ADDR) )
			{
				NOCPacket message(m_address, RAM_ADDR, 4, NOCPacket::TYPE_RPC_CALL, 4);
				if(!m_parent->AcceptMessage(message, this))
					LogWarning("Couldn't send chown message\n");
				m_rxstate = RX_STATE_WAIT_SEND;
				m_returnToIdle = g_time + 4;
				m_frameBuffers --;	//we just used a frame buffer
			}

			break;

		case RX_STATE_WAIT_SEND:
			break;
	}

	return true;
}

void NOCNicHost::Timestep()
{
	//At time 0: generate an RPC request to allocate a page of RAM
	if(g_time == 0)
	{
		//LogDebug("[%5u] Sending initial malloc request\n", g_time);

		NOCPacket message(m_address, RAM_ADDR, 4, NOCPacket::TYPE_RPC_CALL, 4);
		if(!m_parent->AcceptMessage(message, this))
			LogWarning("Couldn't send initial message\n");
		m_rxstate = RX_STATE_WAIT_ALLOC;
	}

	//If a new frame just arrived, deal with it.
	if(g_time == m_nextFrame)
	{
		m_framesTotal ++;

		//If we already had a pending frame, this one gets dropped b/c we don't have a buffer to write it to :(
		if(m_pendingFrame)
		{
			m_framesDropped ++;
			LogWarning("[%5u] NOCNicHost: Dropping packet (no rx buffer)\n", g_time);
		}

		//Good to go, process this one
		else
		{
			m_framesProcessed ++;
			m_pendingFrame = true;
			m_pendingFrameSize = m_nextFrameSize;
			//LogDebug("[%5u] NOCNicHost: Got a packet\n", g_time);
		}

		//Next frame is a random size between 64 and 1500 bytes
		m_nextFrameSize = 64 + (rand() % 1436);

		//We're simulating a 125 MHz system clock so 8 bits data per clock will arrive on the network.
		//Add a random inter-frame gap between 8 and 128 bytes
		m_nextFrame = g_time + m_nextFrameSize + 8 + (rand() % 120);
	}

	//Main state machine
	switch(m_rxstate)
	{
		case RX_STATE_IDLE:
			m_cyclesIdle ++;

			//If we have no frame buffers, request allocation of a new buffer
			if(m_frameBuffers == 0)
			{
				//LogDebug("[%5u] NOCNicHost: No frame buffers, sending malloc request\n", g_time);
				NOCPacket message(m_address, RAM_ADDR, 4, NOCPacket::TYPE_RPC_CALL, 4);
				if(!m_parent->AcceptMessage(message, this))
					LogWarning("Couldn't send initial message\n");
				m_rxstate = RX_STATE_WAIT_ALLOC;
			}

			//If we have a pending frame, process it
			else if(m_pendingFrame)
			{
				//Send the write request to RAM
				//LogDebug("[%5u] NOCNicHost: Writing packet to RAM\n", g_time);
				NOCPacket message(m_address, RAM_ADDR, 3 + m_pendingFrameSize, NOCPacket::TYPE_DMA_WRITE, 3);
				if(!m_parent->AcceptMessage(message, this))
					LogWarning("Couldn't send write-to-RAM message\n");
				m_rxstate = RX_STATE_WAIT_WRITE;
			}

			break;

		case RX_STATE_WAIT_ALLOC:
			m_cyclesWaitingForMalloc ++;
			break;

		case RX_STATE_WAIT_WRITE:
			m_cyclesWaitingForWrite ++;
			break;

		case RX_STATE_WAIT_CHOWN:
			m_cyclesWaitingForChown ++;
			break;

		case RX_STATE_WAIT_SEND:
			if(g_time >= m_returnToIdle)
			{
				m_pendingFrame = false;
				m_rxstate = RX_STATE_IDLE;
			}
			m_cyclesWaitingForSend ++;
			break;
	}
}
