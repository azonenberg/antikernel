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
	@brief Declaration of RPCMessage
 */

#ifndef RPCMessage_h
#define RPCMessage_h

#include <stdint.h>
#include <string>

/**
	@brief A single packet on the RPCv2 network

	The RPC network is a packet-switched NoC intended for low-latency control-plane operations in which high (25%)
	protocol overhead is acceptable as long as latency is minimized.

	Reliable, in-order delivery is guaranteed by the network.

	\ingroup libjtaghal
 */
class RPCMessage
{
public:
	RPCMessage();

	///Source address
	uint16_t from;

	///Destination address
	uint16_t to;

	///RPC call number or IRQ number
	uint8_t callnum;

	///Type
	unsigned int type;

	///Application-layer data. Note that only the low 21 bits of data[0] are transmitted; the high 11 must be all zeros.
	uint32_t data[3];

	void Pack(unsigned char* buf) const;
	void Pack(uint32_t* buf) const;
	void Unpack(unsigned char* buf);
	void Unpack(uint32_t* buf);

	std::string Format() const;

	bool operator==(const RPCMessage& rhs) const;
};

#endif
