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
	@brief Implementation of SPIDecoder
 */

#include "../scopehal/scopehal.h"
#include "../scopehal/ByteRenderer.h"
#include "SPIDecoder.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

SPIDecoder::SPIDecoder(
	std::string hwname, std::string color, NameServer& namesrvr)
	: ProtocolDecoder(hwname, OscilloscopeChannel::CHANNEL_TYPE_COMPLEX, color, namesrvr)
{
	//Set up channels
	m_signalNames.push_back("clk");
	m_channels.push_back(NULL);
	m_signalNames.push_back("cs_n");
	m_channels.push_back(NULL);
	m_signalNames.push_back("data");
	m_channels.push_back(NULL);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Factory methods

ChannelRenderer* SPIDecoder::CreateRenderer()
{
	return new ByteRenderer(this);
}

bool SPIDecoder::ValidateChannel(size_t i, OscilloscopeChannel* channel)
{
	if( (i == 0) && (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL) && (channel->GetWidth() == 1) )
		return true;
	if( (i == 1) && (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL) && (channel->GetWidth() == 1) )
		return true;
	if( (i == 2) && (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL) && (channel->GetWidth() == 1) )
		return true;
	return false;
}

std::string SPIDecoder::GetProtocolName()
{
	return "SPI";
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Actual decoder logic

void SPIDecoder::Refresh()
{
	//Get the input data
	if( (m_channels[0] == NULL) || (m_channels[1] == NULL) || (m_channels[2] == NULL) )
	{
		SetData(NULL);
		return;
	}
	
	DigitalCapture* clk  = dynamic_cast<DigitalCapture*>(m_channels[0]->GetData());
	DigitalCapture* cs   = dynamic_cast<DigitalCapture*>(m_channels[1]->GetData());
	DigitalCapture* data = dynamic_cast<DigitalCapture*>(m_channels[2]->GetData());

	if( (clk == NULL) || (cs == NULL) || (data == NULL) )
	{
		SetData(NULL);
		return;
	}
	
	//SPI processing
	ByteCapture* cap = new ByteCapture;
	cap->m_timescale = clk->m_timescale;
	
	//WORKAROUND for rendering bug
	//Add an empty sample to the start
	cap->m_samples.push_back(ByteSample(0,0,0));
	
	//Process everything (except CS_N cycles) on rising edges of clk
	int nbit = 0;
	int64_t tstart = 0;
	uint8_t current_byte = 0;
	bool clk_was_high = 0;
	bool initial_wait = 1;
	for(size_t isample = 0; isample < clk->m_samples.size(); isample ++)
	{
		//If CS_N is high, do nothing (reset any partially acquired sample)
		if(cs->m_samples[isample].m_sample)
		{
			initial_wait = 0;
			nbit = 0;
		}
		
		//If clock is high, but was not high last cycle, add this bit
		//Don't start capturing until the initial wait time is over
		if(!cs->m_samples[isample].m_sample && clk->m_samples[isample].m_sample && !clk_was_high && !initial_wait)
		{
			//Starting a new sample? Record the time
			if(nbit == 0)
			{
				tstart = clk->m_samples[isample].m_offset;
				current_byte = 0;
			}
			
			//Shift in the new bit
			current_byte = (current_byte << 1) | data->m_samples[isample].m_sample;
			
			//If we just read the last bit, save it
			if(nbit == 7)
			{
				uint64_t tend = clk->m_samples[isample].m_offset + clk->m_samples[isample].m_duration;
				
				cap->m_samples.push_back(ByteSample(
					tstart,
					tend - tstart,
					current_byte));
				nbit = 0;
			}
			
			//nope, continue
			else
				nbit ++;
		}
		
		//Save current value
		clk_was_high = clk->m_samples[isample].m_sample;
	}
	
	SetData(cap);
}
