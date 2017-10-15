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
	@brief Implementation of AnalogRenderer
 */

#include "scopehal.h"
#include "ChannelRenderer.h"
#include "AnalogRenderer.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction
AnalogRenderer::AnalogRenderer(OscilloscopeChannel* channel)
: ChannelRenderer(channel)
{
	m_height = 125;
	m_yscale = 1;
	m_yoffset = 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

void AnalogRenderer::RenderStartCallback(
	const Cairo::RefPtr<Cairo::Context>& cr,
	int width,
	int visleft,
	int visright,
	vector<time_range>& ranges)
{
	ChannelRenderer::RenderStartCallback(cr, width, visleft, visright, ranges);

	float ytop = m_ypos + m_padding;
	float ybot = m_ypos + m_height - m_padding;
	float plotheight = ybot-ytop;
	float halfheight = m_height/2 - m_padding;
	float ymid = halfheight + ytop;

	//Draw grid
	cr->set_source_rgba(0.7, 0.7, 0.7, 1.0);

	//Center line
	cr->move_to(visleft, ymid);
	cr->line_to(visright, ymid);
	cr->stroke();

	//Volts from the center line of our graph to the top. May not be the max value in the signal.
	float volts_per_half_span = m_yscale / 2;

	//Decide what voltage step to use. Pick from a list (in volts)
	const float step_sizes[12]=
	{
		//mV per div
		0.001,
		0.0025,
		0.005,

		0.01,
		0.025,
		0.05,

		0.1,
		0.25,
		0.5,

		1,
		2.5,
		5
	};

	const int min_steps = 2;
	const int max_steps = 4;

	float selected_step = 1;
	for(int i=0; i<12; i++)
	{
		float step = step_sizes[i];
		float steps_per_half_span = volts_per_half_span / step;
		if(steps_per_half_span > max_steps)
			continue;
		if(steps_per_half_span < min_steps)
			continue;
		selected_step = step;
	}

	//Draw the grid lines
	vector<double> dashes;
	dashes.push_back(2);
	dashes.push_back(2);
	cr->set_dash(dashes, 0);

	for(float dy=0; dy<halfheight; dy += selected_step*plotheight)
	{
		cr->move_to(visleft, ymid + dy);
		cr->line_to(visright, ymid + dy);

		cr->move_to(visleft, ymid - dy);
		cr->line_to(visright, ymid - dy);
	}
	cr->stroke();

	cr->unset_dash();
}

void AnalogRenderer::RenderSampleCallback(
	const Cairo::RefPtr<Cairo::Context>& cr,
	size_t i,
	float xstart,
	float xend,
	int /*visleft*/,
	int /*visright*/
	)
{
	float ytop = m_ypos + m_padding;
	float ybot = m_ypos + m_height - m_padding;
	float yd = ybot-ytop;
	float ymid = m_height/2 - m_padding + ytop;

	AnalogCapture* capture = dynamic_cast<AnalogCapture*>(m_channel->GetData());
	if(capture == NULL)
		return;

	const AnalogSample& sample = capture->m_samples[i];

	//Calculate position. If the sample would go off the edge of our render, crop it
	//0 volts is by default the center of our display area
	float y = ymid - ( (sample.m_sample + m_yoffset) * yd * m_yscale);
	if(y < ytop)
		y = ytop;
	if(y > ybot)
		y = ybot;

	//Move to initial position if first sample
	if(i == 0)
		cr->move_to(xstart, y);

	//Draw at the middle
	float xmid = (xend-xstart)/2 + xstart;

	//Render
	cr->line_to(xmid, y);
}

void AnalogRenderer::RenderEndCallback(
	const Cairo::RefPtr<Cairo::Context>& cr,
	int /*width*/,
	int /*visleft*/,
	int /*visright*/,
	vector<time_range>& /*ranges*/)
{
	Gdk::Color color(m_channel->m_displaycolor);
	cr->set_source_rgb(color.get_red_p(), color.get_green_p(), color.get_blue_p());
	cr->stroke();

	cr->restore();
}
