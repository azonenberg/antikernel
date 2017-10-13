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

#include "../scopehal/scopehal.h"
#include "EyeDecoder.h"
#include "EyeRenderer.h"
#include <algorithm>

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

EyeDecoder::EyeDecoder(
	std::string hwname, std::string color)
	: ProtocolDecoder(hwname, OscilloscopeChannel::CHANNEL_TYPE_DIGITAL, color)
{
	//Set up channels
	m_signalNames.push_back("din");
	m_channels.push_back(NULL);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Factory methods

ChannelRenderer* EyeDecoder::CreateRenderer()
{
	return new EyeRenderer(this);
}

bool EyeDecoder::ValidateChannel(size_t i, OscilloscopeChannel* channel)
{
	if( (i == 0) && (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_ANALOG) )
		return true;
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Accessors

string EyeDecoder::GetProtocolName()
{
	return "Eye pattern";
}

bool EyeDecoder::IsOverlay()
{
	return false;
}

bool EyeDecoder::NeedsConfig()
{
	//TODO: make this true, trigger needs config
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Actual decoder logic

void EyeDecoder::Refresh()
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

	//Can't do much if we have no samples to work with
	if(din->GetDepth() == 0)
	{
		SetData(NULL);
		return;
	}

	//Initialize the capture
	EyeCapture* cap = new EyeCapture;
	m_timescale = m_channels[0]->m_timescale;
	cap->m_timescale = din->m_timescale;

	//Keep count of how many times we've seen each pixel at a given offset
	//TODO: make trigger level configurable
	map<int64_t, map<float, int64_t> > pixmap;
	float trigger_level = 0.5;
	float last_sample_value = 0;
	int64_t tstart = 0;
	vector<int64_t> ui_widths;
	for(size_t i=0; i<din->m_samples.size(); i++)
	{
		AnalogSample sin = din->m_samples[i];
		float f = sin;

		int64_t old_tstart = tstart;

		//Dual-edge trigger, no holdoff
		if( (f > trigger_level) && (last_sample_value < trigger_level) )
			tstart = sin.m_offset;
		if( (f < trigger_level) && (last_sample_value > trigger_level) )
			tstart = sin.m_offset;
		last_sample_value = f;

		//If we triggered this cycle, add the delta
		if(tstart != old_tstart)
			ui_widths.push_back(tstart - old_tstart);

		//We know where this sample is within the UI.
		pixmap[sin.m_offset - tstart][f] ++;
	}

	//Figure out the best guess width of the unit interval
	//We should never trigger more than once in a UI, but we might have several UIs between triggers
	//Compute a histogram of the UI widths and pick the highest bin. This is probably one UI.
	//TODO: it might be a harmonic!
	map<int, int64_t> hist;
	for(auto w : ui_widths)
		hist[w] ++;
	int max_bin = 0;
	int64_t max_count = 0;
	for(auto it : hist)
	{
		if(it.second > max_count)
		{
			max_count = it.second;
			max_bin = it.first;
		}
	}

	int64_t eye_width = max_bin + 1;	//This heuristic seems to err on the low side so round up
	LogDebug("Calculated UI width: %ld samples / %.3f ns\n",
		eye_width, eye_width * cap->m_timescale / 1e3);
	m_uiWidth = eye_width;

	//Merge data from adjacent UIs
	map<int64_t, map<float, int64_t> > pixmap_merged;
	for(auto it : pixmap)
	{
		for(auto jt : it.second)
			pixmap_merged[it.first % eye_width][jt.first] += jt.second;
	}

	//Generate the samples
	for(auto it : pixmap_merged)
	{
		for(auto jt : it.second)
		{
			//For now just add a sample for it
			EyePatternPixel pix;
			pix.m_voltage = jt.first;
			pix.m_count = jt.second;
			cap->m_samples.push_back(EyeSample(it.first, 1, pix));
		}
	}

	SetData(cap);
}
