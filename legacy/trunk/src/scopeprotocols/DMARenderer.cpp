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
	@brief Implementation of DMARenderer
 */

#include "../scopehal/scopehal.h"
#include "DMARenderer.h"
#include "DMADecoder.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction
DMARenderer::DMARenderer(OscilloscopeChannel* channel)
	: TextRenderer(channel)
{
	m_height = 30;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

std::string DMARenderer::GetText(int i)
{
	ProtocolDecoder* decoder = dynamic_cast<ProtocolDecoder*>(m_channel);
	DMACapture* capture = dynamic_cast<DMACapture*>(m_channel->GetData());
	if(capture != NULL && decoder != NULL)
	{
		const DMASample& sample = capture->m_samples[i];
		const DMAMessage& msg = sample.m_sample;
		
		//Get name strings
		std::string namefrom = decoder->GetNameOfAddress(msg.from);
		std::string nameto = decoder->GetNameOfAddress(msg.to);
		
		//Format opcode
		std::string opcode;
		switch(msg.opcode)
		{
			case DMA_OP_WRITE_REQUEST:
				opcode = "write data";
				break;
			case DMA_OP_READ_REQUEST:
				opcode = "read request";
				break;
			case DMA_OP_READ_DATA:
				opcode = "read data";
				break;
			default:
				opcode = "invalid opcode";
				break;
		}			
		
		//Format text
		//TODO: support other formats
		std::string str;
		char sbuf[256] = "";
		snprintf(sbuf, 256, "From %s to %s: %d words of %s (address %08x) ",
			namefrom.c_str(), nameto.c_str(), msg.len, opcode.c_str(), msg.address);
		str = sbuf;
		if(msg.opcode != DMA_OP_READ_REQUEST)
		{
			for(int j=0; j<msg.len; j++)
			{
				snprintf(sbuf, 256, "%08x ", msg.data[j]);
				str += sbuf;
			}
		}
		return str;
	}
	return "";
}
