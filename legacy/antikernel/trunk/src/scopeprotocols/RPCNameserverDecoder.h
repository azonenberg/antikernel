/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2016 Andrew D. Zonenberg                                                                          *
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
	@brief Declaration of RPCNameserverDecoder
 */

#ifndef RPCNameserverDecoder_h
#define RPCNameserverDecoder_h

#include "../scopehal/ProtocolDecoder.h"

//A single message
class RPCNameserverMessage
{
public:
	uint16_t from;
	uint16_t to;
	uint8_t opcode;
	uint8_t count;
	uint16_t address;
	char hostname[9];	//last is always null
	
	bool operator==(const RPCNameserverMessage& rhs) const;
};

class RPCNameserverMessagePair
{
public:
	RPCNameserverMessage request;
	RPCNameserverMessage response;
	
	bool operator==(const RPCNameserverMessagePair& rhs) const
	{
		return (request == rhs.request) && (response == rhs.response);
	}
};

typedef OscilloscopeSample<RPCNameserverMessagePair> RPCNameserverSample;
typedef CaptureChannel<RPCNameserverMessagePair> RPCNameserverCapture;

class RPCNameserverDecoder : public ProtocolDecoder
{
public:
	RPCNameserverDecoder(std::string hwname, std::string color, NameServer& namesrvr);
	
	virtual void Refresh();
	virtual ChannelRenderer* CreateRenderer();
	
	static std::string GetProtocolName();
	
	virtual bool ValidateChannel(size_t i, OscilloscopeChannel* channel);
	
	PROTOCOL_DECODER_INITPROC(RPCNameserverDecoder)
};

#endif

