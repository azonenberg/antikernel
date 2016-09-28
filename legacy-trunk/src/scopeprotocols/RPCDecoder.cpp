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
	@brief Implementation of RPCDecoder
 */

#include "../scopehal/scopehal.h"
#include "RPCDecoder.h"
#include "RPCRenderer.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

RPCDecoder::RPCDecoder(
	std::string hwname, std::string color, NameServer& namesrvr)
	: ProtocolDecoder(hwname, OscilloscopeChannel::CHANNEL_TYPE_COMPLEX, color, namesrvr)
{
	//Set up channels
	m_signalNames.push_back("en");
	m_signalNames.push_back("ack");
	m_signalNames.push_back("data");
	m_channels.push_back(NULL);	
	m_channels.push_back(NULL);
	m_channels.push_back(NULL);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Factory methods

ChannelRenderer* RPCDecoder::CreateRenderer()
{
	return new RPCRenderer(this);
}

std::string RPCDecoder::GetProtocolName()
{
	return "RPC link-layer";
}

bool RPCDecoder::ValidateChannel(size_t i, OscilloscopeChannel* channel)
{
	switch(i)
	{
	case 0:
		if( (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL) && (channel->GetWidth() == 1) )
			return true;
		break;
	case 1:
		if( (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL) && (channel->GetWidth() == 2) )
			return true;
		break;
	case 2:
		if( (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL) && (channel->GetWidth() == 32) )
			return true;
		break;
	}	
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Actual decoder logic

void RPCDecoder::Refresh()
{
	//Get the input data
	if( (m_channels[0] == NULL) || (m_channels[1] == NULL) || (m_channels[2] == NULL) )
	{
		SetData(NULL);
		return;
	}

	DigitalCapture* en = dynamic_cast<DigitalCapture*>(m_channels[0]->GetData());
	DigitalBusCapture* ack = dynamic_cast<DigitalBusCapture*>(m_channels[1]->GetData());
	DigitalBusCapture* data = dynamic_cast<DigitalBusCapture*>(m_channels[2]->GetData());
	if( (en == NULL) || (ack == NULL) || (data == NULL) )
	{
		SetData(NULL);
		return;
	}
	
	//Verify all three are the same length
	if(
		(en->m_samples.size() != ack->m_samples.size()) ||
		(en->m_samples.size() != data->m_samples.size())
		)
	{
		throw JtagExceptionWrapper(
			"Input channels must be same length",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	
	//RPC processing
	RPCCapture* cap = new RPCCapture;
	cap->m_timescale = en->m_timescale;
	
	//Time-domain processing to reflect potentially variable sampling rate for RLE captures
	size_t isample = 0;
	while(isample < en->m_samples.size())
	{
		//Wait for EN to go high (start bit)
		while( (isample < en->m_samples.size()) && !en->m_samples[isample].m_sample)
			isample ++;
			
		//If we're near the end of the capture stop, can't decode incomplete packets
		if( (isample + 3) >= en->m_samples.size())
			break;
			
		size_t istart = isample;
		
		//Start the message
		int64_t tstart = en->m_samples[isample].m_offset;
		
		//Get the data
		uint32_t value = 0;
		DigitalBusSample dsample = data->m_samples[isample];
		for(int j=0; j<32; j++)
			value = (value << 1) | dsample.m_sample[j];
		
		//Save the header
		RPCMessage msg;
		msg.from = value >> 16;
		msg.to = value & 0xFFFF;
		
		//For now, assume sampling clock is the NoC clock so we want x+1, x+2, x+3
		for(int k=0; k<3; k++)
		{
			if( (en->m_samples[isample].m_offset + en->m_samples[isample].m_duration) <= tstart+k+1)
				isample ++;
			dsample = data->m_samples[isample];
			for(int j=0; j<32; j++)
				value = (value << 1) | dsample.m_sample[j];
			
			//Sample #0 is special
			if(k == 0)
			{
				msg.callnum = value >> 24;
				msg.type = (value >> 21) & 0x7;
				msg.data[0] = value & 0x001FFFFF;
			}
			else
				msg.data[k] = value;
		}
		
		//Wait for the acknowledgement
		//ACK may come during or up to 32 clocks after the message body
		int nack = 0;
		int64_t tmax = tstart + 32 + 4;
		size_t isearch = istart;
		for(int k=0; k<32; k++)
		{
			//Stop if 32 clocks have passed even if it's not 32 samples
			if( (ack->m_samples[isearch].m_offset + ack->m_samples[isearch].m_duration) > tmax)
				break;
				
			//Stop if at end of capture
			if(isearch >= ack->m_samples.size())
				break;
			
			//Read the sample
			dsample = ack->m_samples[isearch];
			for(int j=0; j<2; j++)
				nack = (nack << 1) | dsample.m_sample[j];
			if(nack != 0)
				break;
				
			isearch ++;
		}

		//End whenever the ACK finishes
		if(isearch > isample)
			isample = isearch;
		
		//Don't decode NAK'd packets
		if(nack != 1)
			continue;
		
		//Save the sample (fixed length of 4 for now)
		//TODO: make sample run until end or ACK as appropriate?
		cap->m_samples.push_back(RPCSample(tstart, 4, msg));
	}
	
	SetData(cap);
}

