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
	@brief Implementation of SchmittTriggerDecoder
 */

#include "../scopehal/scopehal.h"
#include "SchmittTriggerDecoder.h"
#include "../scopehal/DigitalRenderer.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

SchmittTriggerDecoder::SchmittTriggerDecoder(
	std::string hwname, std::string color, NameServer& namesrvr)
	: ProtocolDecoder(hwname, OscilloscopeChannel::CHANNEL_TYPE_DIGITAL, color, namesrvr)
{
	//Set up channels
	m_signalNames.push_back("din");
	m_channels.push_back(NULL);	
	
	m_loname = "V<sub>ilo</sub>";
	m_parameters[m_loname] = ProtocolDecoderParameter(ProtocolDecoderParameter::TYPE_FLOAT);
	m_parameters[m_loname].SetIntVal(0.5);
	
	m_hiname = "V<sub>ihi</sub>";
	m_parameters[m_hiname] = ProtocolDecoderParameter(ProtocolDecoderParameter::TYPE_FLOAT);
	m_parameters[m_hiname].SetIntVal(2.5);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Factory methods

ChannelRenderer* SchmittTriggerDecoder::CreateRenderer()
{
	return new DigitalRenderer(this);
}

std::string SchmittTriggerDecoder::GetProtocolName()
{
	return "Schmitt trigger";
}

bool SchmittTriggerDecoder::ValidateChannel(size_t i, OscilloscopeChannel* channel)
{
	if( (i == 0) && (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_ANALOG) && (channel->GetWidth() == 1) )
		return true;
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Actual decoder logic

void SchmittTriggerDecoder::Refresh()
{	
	//Get the input data
	if(m_channels[0] == NULL)
	{
		SetData(NULL);
		return;
	}
	AnalogCapture* din = dynamic_cast<AnalogCapture*>(m_channels[0]->GetData());
	if(din == NULL)
	{
		SetData(NULL);
		return;
	}
	
	float lothresh = m_parameters[m_loname].GetFloatVal();
	float hithresh = m_parameters[m_hiname].GetFloatVal();
	
	//Schmitt trigger processing
	bool current = false;
	DigitalCapture* cap = new DigitalCapture;
	cap->m_timescale = din->m_timescale;
	for(size_t i=0; i<din->m_samples.size(); i++)
	{
		AnalogSample& sin = din->m_samples[i];
		if(sin.m_sample > hithresh)
			current = true;
		else if(sin.m_sample < lothresh)
			current = false;
		
		cap->m_samples.push_back(DigitalSample(sin.m_offset, sin.m_duration, current));
	}
	SetData(cap);
}
