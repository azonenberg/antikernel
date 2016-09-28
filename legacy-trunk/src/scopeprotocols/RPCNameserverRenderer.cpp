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
	@brief Implementation of RPCNameserverRenderer
 */

#include "../scopehal/scopehal.h"
#include "RPCNameserverRenderer.h"
#include "RPCNameserverDecoder.h"

#include <NOCNameServer_constants.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction
RPCNameserverRenderer::RPCNameserverRenderer(OscilloscopeChannel* channel)
	: TextRenderer(channel)
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

std::string RPCNameserverRenderer::GetText(int /*i*/)
{
	/*
	RPCNameserverCapture* capture = dynamic_cast<RPCNameserverCapture*>(m_channel->GetData());
	if(capture != NULL)
	{
		//Get the current sample
		const RPCNameserverSample& sample = capture->m_samples[i];
		const RPCNameserverMessagePair& pair = sample.m_sample;
		
		//TODO: nameserver integration for from/to addresses
		std::string str;
		char buf[256];
		switch(pair.request.opcode)
		{
		case NAMESERVER_OP_LIST:
			str = "LIST op not implemented";
			break;
		
		case NAMESERVER_OP_FQUERY:
			snprintf(buf, 256, "Forward lookup (from %04x) of %s, tag %02x: ",
				pair.request.from,
				pair.request.hostname,
				pair.request.count);
			str = buf;
			if(std::string(pair.response.hostname) == "")
				str += "Not found";
			else
			{
				snprintf(buf, 256, "%04x", pair.response.address);
				str += buf;
			}
			break;
		
		case NAMESERVER_OP_RQUERY:
			snprintf(buf, 256, "Reverse lookup (from %04x) of %04x, tag 0x%02x: ",
				pair.request.from,
				pair.request.address,
				pair.request.count
				);
			str = buf;
			
			//Look at the response
			if(pair.response.count != pair.request.count)
				str += "Invalid response tag";
			else if(pair.response.hostname[0] == 0)
				str += "Not found";
			else
				str += pair.response.hostname;
			break;
		
		default:
			str = "Invalid opcode";
			break;
		}
		
		return str;
	}
	*/
	return "";
}
