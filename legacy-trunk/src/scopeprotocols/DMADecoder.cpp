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
	@brief Implementation of DMADecoder
 */

#include "../scopehal/scopehal.h"
#include "DMADecoder.h"
#include "DMARenderer.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

DMADecoder::DMADecoder(
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

ChannelRenderer* DMADecoder::CreateRenderer()
{
	return new DMARenderer(this);
}

std::string DMADecoder::GetProtocolName()
{
	return "DMA link-layer";
}

bool DMADecoder::ValidateChannel(size_t i, OscilloscopeChannel* channel)
{
	switch(i)
	{
	case 0:
	case 1:
		if( (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL) && (channel->GetWidth() == 1) )
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

void DMADecoder::Refresh()
{
	//Get the input data
	if( (m_channels[0] == NULL) || (m_channels[1] == NULL) || (m_channels[2] == NULL) )
	{
		SetData(NULL);
		return;
	}
	
	DigitalCapture* en = dynamic_cast<DigitalCapture*>(m_channels[0]->GetData());
	DigitalCapture* ack = dynamic_cast<DigitalCapture*>(m_channels[1]->GetData());
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
	DMACapture* cap = new DMACapture;
	cap->m_timescale = en->m_timescale;
	
	//Time-domain processing to reflect potentially variable sampling rate for RLE captures
	size_t isample = 0;
	while(isample < en->m_samples.size())
	{
		//Wait for EN to go high (start bit)
		while( (isample < en->m_samples.size()) && !en->m_samples[isample].m_sample)
			isample ++;
			
		//Wait for ACK to go high
		while( (isample < ack->m_samples.size()) && !ack->m_samples[isample].m_sample)
			isample ++;
			
		//If EN is no longer high, this is an invalid packet - drop it for now
		//TODO: Decide how to handle error conditions
		if(!en->m_samples[isample].m_sample)
			continue;
			
		//Start the message
		int64_t tstart = en->m_samples[isample].m_offset;
		
		//Get the data
		uint32_t value = 0;
		DigitalBusSample dsample = data->m_samples[isample];
		for(int j=0; j<32; j++)
			value = (value << 1) | dsample.m_sample[j];
		
		//Save the routing header
		DMAMessage msg;
		msg.from = value >> 16;
		msg.to = value & 0xFFFF;
		
		//Read the DMA header
		//Opcode (8 bits) | Padding (14 bits) | Payload length in words (10 bits)
		if( (en->m_samples[isample].m_offset + en->m_samples[isample].m_duration) <= tstart+1)
			isample ++;
		dsample = data->m_samples[isample];
		for(int j=0; j<32; j++)
			value = (value << 1) | dsample.m_sample[j];
		msg.opcode = value >> 30;
		msg.len = value & 0x3FF;
		
		//Read the address
		if( (en->m_samples[isample].m_offset + en->m_samples[isample].m_duration) <= tstart+2)
			isample ++;
		dsample = data->m_samples[isample];
		for(int j=0; j<32; j++)
			value = (value << 1) | dsample.m_sample[j];
		msg.address = value;
		
		//If opcode is "read request" or "nak" there's no data - stop now
		//Otherwise, read data
		int noff = tstart + 3;
		if(msg.opcode != DMA_OP_READ_REQUEST)
		{
			//For now, assume sampling clock is the NoC clock so we want x+1, x+2, x+3
			for(int k=0; k<msg.len; k++)
			{
				if( (en->m_samples[isample].m_offset + en->m_samples[isample].m_duration) <= tstart+k+3)
					isample ++;
				dsample = data->m_samples[isample];
				for(int j=0; j<32; j++)
					value = (value << 1) | dsample.m_sample[j];
				
				msg.data[k] = value;
			}
			noff += msg.len;
		}
		
		//Save the sample
		cap->m_samples.push_back(DMASample(tstart, noff - tstart, msg));
	}
	
	SetData(cap);
}

