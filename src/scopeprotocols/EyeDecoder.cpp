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
	: ProtocolDecoder(hwname, OscilloscopeChannel::CHANNEL_TYPE_COMPLEX, color)
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

bool EyeDecoder::DetectModulationLevels(AnalogCapture* din, EyeCapture* cap)
{
	//Find the min/max voltage of the signal (used to set default bounds for the render).
	//Additionally, generate a histogram of voltages. We need this to configure the trigger(s) correctly
	//and do measurements on the eye opening(s) - since MLT-3, PAM-4, etc have multiple openings.
	cap->m_minVoltage = 999;
	cap->m_maxVoltage = -999;
	map<int, int64_t> vhist;							//1 mV bins
	for(size_t i=0; i<din->m_samples.size(); i++)
	{
		AnalogSample sin = din->m_samples[i];
		float f = sin;

		vhist[f * 1000] ++;

		if(f > cap->m_maxVoltage)
			cap->m_maxVoltage = f;
		if(f < cap->m_minVoltage)
			cap->m_minVoltage = f;
	}

	//Crunch the histogram to find the number of signal levels in use.
	//We're looking for peaks of significant height (10% of maximum or more) and not too close to another peak.
	int neighborhood = 60;
	int64_t maxpeak = 0;
	for(auto it : vhist)
	{
		if(it.second > maxpeak)
			maxpeak = it.second;
	}
	int64_t peakthresh = maxpeak/10;
	for(auto it : vhist)
	{
		//Skip peaks that aren't tall enough
		int64_t count = it.second;
		if(count < peakthresh)
			continue;

		//If we're pretty close to a taller peak (within neighborhood mV) then don't do anything
		int mv = it.first;
		bool bigger = false;
		for(int v=mv-neighborhood; v<=mv+neighborhood; v++)
		{
			auto jt = vhist.find(v);
			if(jt == vhist.end())
				continue;
			if(jt->second > count)
			{
				bigger = true;
				continue;
			}
		}
		if(bigger)
			continue;

		//Search the neighborhood around us and do a weighted average to find the center of the bin
		int64_t weighted = 0;
		int64_t wcount = 0;
		for(int v=mv-neighborhood; v<=mv+neighborhood; v++)
		{
			auto jt = vhist.find(v);
			if(jt == vhist.end())
				continue;

			int64_t c = jt->second;
			wcount += c;
			weighted += c*v;
		}
		cap->m_signalLevels.push_back(weighted * 1e-3f / wcount);
	}
	sort(cap->m_signalLevels.begin(), cap->m_signalLevels.end());
	/*LogDebug("    Signal appears to be using %d-level modulation\n", (int)cap->m_signalLevels.size());
	for(auto v : cap->m_signalLevels)
		LogDebug("        %6.3f V\n", v);*/

	//Figure out decision points (eye centers)
	for(size_t i=0; i<cap->m_signalLevels.size()-1; i++)
	{
		float vlo = cap->m_signalLevels[i];
		float vhi = cap->m_signalLevels[i+1];
		cap->m_decisionPoints.push_back(vlo + (vhi-vlo)/2);
	}
	/*LogDebug("    Decision points:\n");
	for(auto v : cap->m_decisionPoints)
		LogDebug("        %6.3f V\n", v);*/

	//Sanity check
	if(cap->m_signalLevels.size() < 2)
	{
		LogDebug("Couldn't find at least two distinct symbol voltages\n");
		delete cap;
		return false;
	}

	return true;
}

bool EyeDecoder::CalculateUIWidth(AnalogCapture* din, EyeCapture* cap)
{
	//Calculate an initial guess of the UI by triggering at the start of every bit
	float last_sample_value = 0;
	int64_t tstart = 0;
	vector<int64_t> ui_widths;
	for(auto sin : din->m_samples)
	{
		float f = sin;
		int64_t old_tstart = tstart;

		//Dual-edge trigger, no holdoff
		for(auto v : cap->m_decisionPoints)
		{
			if( (f > v) && (last_sample_value < v) )
				tstart = sin.m_offset;
			if( (f < v) && (last_sample_value > v) )
				tstart = sin.m_offset;
		}
		last_sample_value = f;

		//If we triggered this cycle, add the delta
		//Don't count the first partial UI
		if( (tstart != old_tstart) && (old_tstart != 0) )
			ui_widths.push_back(tstart - old_tstart);
	}

	//Figure out the best guess width of the unit interval
	//We should never trigger more than once in a UI, but we might have several UIs between triggers
	//Compute a histogram of the UI widths and pick the highest bin. This is probably one UI.
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

	int64_t eye_width = max_bin;
	/*double baud = 1e6 / (eye_width * cap->m_timescale);
	LogDebug("Computing symbol rate\n");
	LogDebug("    UI width (first pass): %ld samples / %.3f ns (%.3lf Mbd)\n",
		eye_width, eye_width * cap->m_timescale / 1e3, baud);*/

	//Second pass: compute the sum of UIs across the entire signal and average.
	//If the delta is significantly off from our first-guess UI, call it two!
	last_sample_value = 0;
	tstart = 0;
	int64_t ui_width_sum = 0;
	int64_t ui_width_count = 0;
	for(auto sin : din->m_samples)
	{
		float f = sin;
		int64_t old_tstart = tstart;

		//Dual-edge trigger, no holdoff
		for(auto v : cap->m_decisionPoints)
		{
			if( (f > v) && (last_sample_value < v) )
				tstart = sin.m_offset;
			if( (f < v) && (last_sample_value > v) )
				tstart = sin.m_offset;
		}
		last_sample_value = f;

		//If we triggered this cycle, add the delta
		//Don't count the first partial UI
		if( (tstart != old_tstart) && (old_tstart != 0) )
		{
			int64_t w = tstart - old_tstart;

			//Skip runt pulses (glitch?)
			if(w < eye_width/2)
				continue;

			//If it's more than 1.5x the first-guess UI, estimate the width and add it
			if(w > eye_width * 1.5f)
			{
				//Don't try guessing runs more than 6 UIs long, too inaccurate.
				//Within each guess allow +/- 25% variance for the actual edge location.
				for(int guess=2; guess<=6; guess++)
				{
					float center = guess * eye_width;
					float low = center - eye_width*0.25;
					float high = center + eye_width*0.25;
					if( (w > low) && (w < high) )
					{
						ui_width_sum += w;
						ui_width_count += guess;
						break;
					}
				}
				continue;
			}

			//It looks like a single UI! Count it
			ui_width_sum += w;
			ui_width_count ++;
		}
	}
	double average_width = ui_width_sum * 1.0 / ui_width_count;
	//LogDebug("    Average UI width (second pass): %.3lf samples\n", average_width);
	m_uiWidth = round(average_width);
	m_uiWidthFractional = average_width;

	/*baud = 1e6f / (eye_width * cap->m_timescale);
	LogDebug("    UI width (second pass): %ld samples / %.3f ns (%.3lf Mbd)\n",
		eye_width, eye_width * cap->m_timescale / 1e3, baud);*/

	//Sanity check
	if(eye_width == 0)
	{
		LogDebug("No trigger found\n");
		delete cap;
		return false;
	}

	return true;
}

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
	cap->m_sampleCount = din->m_samples.size();

	//Figure out what modulation is in use and what the levels are
	if(!DetectModulationLevels(din, cap))
		return;

	//Once we have decision thresholds, we can find bit boundaries and calculate the symbol rate
	if(!CalculateUIWidth(din, cap))
		return;

	//Generate the final pixel map
	map<int64_t, map<float, int64_t> > pixmap;
	bool first = true;
	float last_sample_value = 0;
	int64_t tstart = 0;
	int64_t uis_per_trigger = 16;
	for(auto sin : din->m_samples)
	{
		float f = sin;

		//If we haven't triggered, wait for the signal to cross a decision threshold
		//so we can phase align to the data clock.
		if(tstart == 0)
		{
			if(!first)
			{
				for(auto v : cap->m_decisionPoints)
				{
					if( (f > v) && (last_sample_value < v) )
						tstart = sin.m_offset;
					if( (f < v) && (last_sample_value > v) )
						tstart = sin.m_offset;
				}
			}
			else
				first = false;

			last_sample_value = f;
			continue;
		}

		//If we get here, we've triggered. Chop the signal at UI boundaries
		double doff = sin.m_offset - tstart;
		int64_t offset = round(fmod(doff, m_uiWidthFractional));
		if(offset >= m_uiWidth)
			offset = 0;

		//and add to the histogram
		pixmap[offset][f] ++;

		//Re-trigger every uis_per_trigger UIs to compensate for clock skew between our guesstimated clock
		//and the actual line rate
		double num_uis = doff / m_uiWidthFractional;
		if(num_uis > uis_per_trigger)
		{
			tstart = 0;
			first = true;
		}
	}

	//Generate the samples
	for(auto it : pixmap)
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

	//Measure the width of the eye at each decision point
	//LogDebug("Measuring eye width\n");
	float row_height = 0.01;				//sample +/- 10 mV around the decision point
	for(auto v : cap->m_decisionPoints)
	{
		//Initialize the row
		vector<int64_t> row;
		for(int i=0; i<m_uiWidth; i++)
			row.push_back(0);

		//Search this band and see where we have signal
		for(auto it : pixmap)
		{
			int64_t time = it.first;
			for(auto jt : it.second)
			{
				if(fabs(jt.first - v) > row_height)
					continue;
				row[time] += jt.second;
			}
		}

		//Start from the middle and look left and right
		int middle = m_uiWidth/2;
		int left = middle;
		int right = middle;
		for(; left > 0; left--)
		{
			if(row[left-1] != 0)
				break;
		}
		for(; right < m_uiWidth-1; right++)
		{
			if(row[right+1] != 0)
				break;
		}

		int width = right-left;
		/*
		LogDebug("    At %.3f V: left=%d, right=%d, width=%d (%.3f ns, %.2f UI)\n",
			v,
			left,
			right,
			width,
			width * cap->m_timescale / 1e3,
			width * 1.0f / eye_width
			);*/
		cap->m_eyeWidths.push_back(width);
	}

	//Find where we have signal right around the middle of the eye
	int64_t col_width = 1;					//sample +/- 1 sample around the center of the opening
	//LogDebug("Measuring eye height\n");
	map<int, int64_t> colmap;
	vector<int> voltages;
	int64_t target = m_uiWidth/2;
	for(auto it : pixmap)
	{
		int64_t time = it.first;
		if( ( (time - target) > col_width ) || ( (time - target) < -col_width ) )
			continue;

		for(auto jt : it.second)
		{
			float mv = jt.first * 1000;
			voltages.push_back(mv);
			colmap[mv] = jt.second;
		}
	}
	sort(voltages.begin(), voltages.end());
	//for(auto y : voltages)
	//	LogDebug("    %.3f: %lu\n", y*0.001f, colmap[y]);

	//Search around each eye opening and find the available space
	for(auto middle : cap->m_decisionPoints)
	{
		float vmin = -999;
		float vmax = 999;

		for(auto v : voltages)
		{
			float fv = v * 0.001f;

			if(fv < middle)
			{
				if(fv > vmin)
					vmin = fv;
			}
			else if(fv < vmax)
				vmax = fv;
		}
		float height = vmax - vmin;
		cap->m_eyeHeights.push_back(height);

		/*LogDebug("    At %.3f V: [%.3f, %.3f], height = %.3f\n",
			middle, vmin, vmax, height);*/
	}

	//Done, update the waveform
	SetData(cap);
}
