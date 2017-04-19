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
#ifndef GridRouter_h
#define GridRouter_h

class GridRouter : public NOCRouter
{
public:
	GridRouter(
		uint16_t low,
		uint16_t high,
		xypos pos,
		bool random);
	virtual ~GridRouter();

	virtual bool AcceptMessage(NOCPacket packet, SimNode* from);
	virtual void Timestep();

	virtual void AddChild(SimNode* child);

	virtual void ExpandBoundingBox(unsigned int& width, unsigned int& height);
	virtual void RenderSVGNodes(FILE* fp);
	virtual void RenderSVGLines(FILE* fp);

	void AddNeighbor(int direction, GridRouter* peer);

protected:
	GridRouter* m_neighbors[4];	//0=north, 1=east, 2=south, 3=west

	SimNode* m_children[16];

	//We have a total of 20 peers... 15:0 are children, 19:16 are neighbors
	unsigned int GetPortNumber(SimNode* node);
	unsigned int GetPortNumber(uint16_t addr);

	bool TryForwardFrom(unsigned int nport);

	//Incoming messages (not yet forwarded)
	NOCPacket m_inboxes[20];
	bool m_inboxValid[20];
	unsigned int m_inboxForwardTime[20];

	//Outgoing messages
	bool m_outboxBlocked[20];
	unsigned int m_outboxClearTime[20];

	//Round-robin counter
	unsigned int m_rrcount;

	unsigned int m_xpos;
	unsigned int m_ypos;

	bool m_randomRouting;
};

#endif

