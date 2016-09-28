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
	@brief Implementation of RPCNameserverDecoder
 */

#include "../scopehal/scopehal.h"
#include "RPCDecoder.h"
#include "RPCNameserverDecoder.h"
#include "RPCNameserverRenderer.h"

bool RPCNameserverMessage::operator==(const RPCNameserverMessage& rhs) const
{
	if(
		(from != rhs.from)		||
		(to != rhs.to)			||
		(opcode != rhs.opcode)	||
		(count != rhs.count)	||
		(address != rhs.address)	||
		strncmp(hostname, rhs.hostname, 9)
		)
	{
		return false;
	}
	return true;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

RPCNameserverDecoder::RPCNameserverDecoder(
	std::string hwname, std::string color, NameServer& namesrvr)
	: ProtocolDecoder(hwname, OscilloscopeChannel::CHANNEL_TYPE_COMPLEX, color, namesrvr)
{
	//Set up channels
	m_signalNames.push_back("tx");
	m_signalNames.push_back("rx");
	m_channels.push_back(NULL);	
	m_channels.push_back(NULL);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Factory methods

ChannelRenderer* RPCNameserverDecoder::CreateRenderer()
{
	return new RPCNameserverRenderer(this);
}

bool RPCNameserverDecoder::ValidateChannel(size_t i, OscilloscopeChannel* channel)
{
	if( (i == 0 || i == 1) && (NULL != dynamic_cast<RPCDecoder*>(channel)) && (channel->GetWidth() == 1) )
		return true;
	return false;
}

std::string RPCNameserverDecoder::GetProtocolName()
{
	return "RPC nameserver";
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Actual decoder logic

void RPCNameserverDecoder::Refresh()
{
	//Get the input data
	if( (m_channels[0] == NULL) || (m_channels[1] == NULL) )
	{
		SetData(NULL);
		return;
	}

	RPCCapture* tx = dynamic_cast<RPCCapture*>(m_channels[0]->GetData());
	RPCCapture* rx = dynamic_cast<RPCCapture*>(m_channels[1]->GetData());
	if( (tx == NULL) || (rx == NULL) )
	{
		SetData(NULL);
		return;
	}

	//RPC processing
	RPCNameserverCapture* cap = new RPCNameserverCapture;
	cap->m_timescale = rx->m_timescale;
	for(size_t i=0; i<rx->m_samples.size(); i++)
	{	
		/*
		//TODO: Ignore packets sent to other addresses
		
		//Get the request message
		RPCSample request = rx->m_samples[i];
		
		//Find the corresponding response packet
		RPCSample* presponse = NULL;
		for(size_t j=0; j<tx->m_samples.size(); j++)
		{
			if(tx->m_samples[j].m_offset >= (request.m_offset+request.m_duration))
			{
				presponse = &tx->m_samples[j];
				break;
			}
		}
		if(presponse == NULL)
		{
			//transaction is not entirely there, skip it
			break;
		}
		RPCSample& response = *presponse;
		
		//Word 1			opcode[7:0] | count[7:0] | address[15:0]
		
		//Crack the messages
		RPCNameserverMessagePair pair;
		pair.request.from = request.m_sample.from;
		pair.request.to = request.m_sample.to;
		pair.request.opcode = request.m_sample.data[0] >> 24;
		pair.request.count = (request.m_sample.data[0] >> 16) & 0xFF;
		pair.request.address = request.m_sample.data[0] & 0xFFFF;
		pair.request.hostname[8] = 0;
		memcpy(pair.request.hostname, &request.m_sample.data[1], 4);
		memcpy(pair.request.hostname+4, &request.m_sample.data[2], 4);
		FlipByteArray((unsigned char*)pair.request.hostname, 4);
		FlipByteArray((unsigned char*)pair.request.hostname+4, 4);
		
		pair.response.from = response.m_sample.from;
		pair.response.to = response.m_sample.to;
		pair.response.opcode = response.m_sample.data[0] >> 24;
		pair.response.count = (response.m_sample.data[0] >> 16) & 0xFF;
		pair.response.address = response.m_sample.data[0] & 0xFFFF;
		pair.response.hostname[8] = 0;
		memcpy(pair.response.hostname, &response.m_sample.data[1], 4);
		memcpy(pair.response.hostname+4, &response.m_sample.data[2], 4);
		FlipByteArray((unsigned char*)pair.response.hostname, 4);
		FlipByteArray((unsigned char*)pair.response.hostname+4, 4);
		
		//Generate the sample
		cap->m_samples.push_back(RPCNameserverSample(request.m_offset, (response.m_offset + response.m_duration) - request.m_offset, pair));
		*/
	}
	
	SetData(cap);
}

