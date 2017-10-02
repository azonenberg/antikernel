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
	@brief Implementation of EthernetRenderer
 */

#include "../scopehal/scopehal.h"
#include "../scopehal/ChannelRenderer.h"
#include "../scopehal/TextRenderer.h"
#include "EthernetRenderer.h"
#include "Ethernet10BaseTDecoder.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

EthernetRenderer::EthernetRenderer(OscilloscopeChannel* channel)
	: TextRenderer(channel)
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

string EthernetRenderer::GetText(int i)
{
	EthernetCapture* data = dynamic_cast<EthernetCapture*>(m_channel->GetData());
	if(data == NULL)
		return "";
	if(i >= (int)data->m_samples.size())
		return "";

	auto sample = data->m_samples[i];
	switch(sample.m_sample.m_type)
	{
		case EthernetFrameSegment::TYPE_PREAMBLE:
			return "PREAMBLE";
			
		case EthernetFrameSegment::TYPE_SFD:
			return "SFD";
			
		case EthernetFrameSegment::TYPE_DST_MAC:
			{
				if(sample.m_sample.m_data.size() != 6)
					return "[invalid dest MAC length]";

				char tmp[32];
				snprintf(tmp, sizeof(tmp), "Dest MAC: %02x:%02x:%02x:%02x:%02x:%02x",
					sample.m_sample.m_data[0],
					sample.m_sample.m_data[1],
					sample.m_sample.m_data[2],
					sample.m_sample.m_data[3],
					sample.m_sample.m_data[4],
					sample.m_sample.m_data[5]);
				return tmp;
			}

		case EthernetFrameSegment::TYPE_SRC_MAC:
			{
				if(sample.m_sample.m_data.size() != 6)
					return "[invalid src MAC length]";

				char tmp[32];
				snprintf(tmp, sizeof(tmp), "Src MAC: %02x:%02x:%02x:%02x:%02x:%02x",
					sample.m_sample.m_data[0],
					sample.m_sample.m_data[1],
					sample.m_sample.m_data[2],
					sample.m_sample.m_data[3],
					sample.m_sample.m_data[4],
					sample.m_sample.m_data[5]);
				return tmp;
			}

		case EthernetFrameSegment::TYPE_ETHERTYPE:
			{
				if(sample.m_sample.m_data.size() != 2)
					return "[invalid Ethertype length]";

				char tmp[32];
				uint16_t ethertype = (sample.m_sample.m_data[0] << 8) | sample.m_sample.m_data[1];
				snprintf(tmp, sizeof(tmp), "Ethertype: %04x", ethertype);

				string ret = tmp;

				//TODO: look up a table of common Ethertype values
				
				return ret;
			}

		case EthernetFrameSegment::TYPE_PAYLOAD:
			{
				string ret;
				for(auto b : sample.m_sample.m_data)
				{
					char tmp[32];
					snprintf(tmp, sizeof(tmp), "%02x ", b);
					ret += tmp;
				}
				return ret;
			}

		default:
			break;
	}

	return "";
}
