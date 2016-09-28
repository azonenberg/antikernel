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
	@brief Implementation of RPCRenderer
 */

#include "../scopehal/scopehal.h"
#include "RPCRenderer.h"
#include "RPCDecoder.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction
RPCRenderer::RPCRenderer(OscilloscopeChannel* channel)
	: TextRenderer(channel)
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

std::string RPCRenderer::GetText(int i)
{
	ProtocolDecoder* decoder = dynamic_cast<ProtocolDecoder*>(m_channel);
	RPCCapture* capture = dynamic_cast<RPCCapture*>(m_channel->GetData());
	if(capture != NULL && decoder != NULL)
	{
		const RPCSample& sample = capture->m_samples[i];
		const RPCMessage& msg = sample.m_sample;
		
		//Get name strings
		std::string namefrom = decoder->GetNameOfAddress(msg.from);
		std::string nameto = decoder->GetNameOfAddress(msg.to);
		
		static const char* types[] = 
		{
			"Function call",
			"Function return - success",
			"Function return - fail",
			"Function return - retry",
			"Interrupt",
			"Reserved",
			"Host prohibited",
			"Host unreachable"
		};
		
		//Format text - hex, 4 bits at a time
		//TODO: support other formats
		char str[256];
		snprintf(
			str,
			sizeof(str),
			"From %s to %s: %s %02x %08x %08x %08x",
			namefrom.c_str(),
			nameto.c_str(),
			types[msg.type],
			msg.callnum,
			msg.data[0],
			msg.data[1],
			msg.data[2]);
			
		return str;
	}
	return "";
}
