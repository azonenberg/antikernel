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
#ifndef NOCPacket_h
#define NOCPacket_h

class NOCPacket
{
public:
	//Type of message (to make sim a bit more realistic)
	enum msgType
	{
		TYPE_RPC_CALL,
		TYPE_RPC_RETURN,
		TYPE_RPC_INTERRUPT,
		TYPE_DMA_READ,
		TYPE_DMA_RDATA,
		TYPE_DMA_WRITE,
		TYPE_DMA_ACK
	};

	NOCPacket(
		uint16_t f = 0,
		uint16_t t = 0,
		unsigned int s = 0,
		msgType type = TYPE_RPC_CALL,
		unsigned int replysize = 4);
	virtual ~NOCPacket();

	uint16_t m_from;
	uint16_t m_to;
	unsigned int m_size;
	unsigned int m_replysize;	//for DMA read

	msgType m_type;

	unsigned int m_timeSent;

	//Indicate that this message has been received and handled by the final destination
	void Processed();

	static void PrintStats();

protected:
	static unsigned int m_minLatency;
	static unsigned int m_maxLatency;
	static unsigned int m_totalPackets;
	static unsigned long m_totalLatency;
};

#endif

