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
	@brief Implementation of EyeRenderer
 */

#include "../scopehal/scopehal.h"
#include "../scopehal/ChannelRenderer.h"
#include "../scopehal/ProtocolDecoder.h"
#include "EyeRenderer.h"
#include "EyeDecoder.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction
EyeRenderer::EyeRenderer(OscilloscopeChannel* channel)
: ChannelRenderer(channel)
{
	m_height = 256;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

void EyeRenderer::Render(
	const Cairo::RefPtr<Cairo::Context>& cr,
	int width,
	int visleft,
	int visright,
	vector<time_range>& ranges)
{
	RenderStartCallback(cr, width, visleft, visright, ranges);

	EyeCapture* capture = dynamic_cast<EyeCapture*>(m_channel->GetData());
	if(capture != NULL)
	{
		//Save time scales
		float tscale = m_channel->m_timescale * capture->m_timescale;

		//Find the maximum count value of any sample
		int64_t maxcount = 0;
		for(size_t i=0; i<capture->GetDepth(); i++)
		{
			auto sample = (*capture)[i];
			if(sample.m_count > maxcount)
				maxcount = sample.m_count;
		}

		//Loop over the samples and render them
		int64_t ui_width = dynamic_cast<EyeDecoder*>(m_channel)->GetUIWidth();
		for(size_t i=0; i<capture->GetDepth(); i++)
		{
			int64_t tstart = capture->GetSampleStart(i);
			int64_t tend = tstart + capture->GetSampleLen(i);
			float xstart = tscale * tstart;
			float xend = tscale * tend;

			auto sample = (*capture)[i];

			float yscale = 0.4 * m_height;
			float yoffset = m_height / 2;
			float ystart = yscale * sample.m_voltage * -1 + yoffset;
			float yend = ystart + 1;
			ystart += m_ypos;
			yend += m_ypos;

			float width = xend - xstart;
			if(width < 1)
				width = 1;

			float count = (1.0f * sample.m_count) / maxcount;

			cr->set_source_rgb(count, 0, count);
			for(int j=0; j<3; j++)
				cr->rectangle(xstart + 150 + j*ui_width*tscale, ystart, /*width*/4, /*yend-ystart*/4);
			cr->fill();
		}
	}

	RenderEndCallback(cr, width, visleft, visright, ranges);
}

void EyeRenderer::RenderSampleCallback(
	const Cairo::RefPtr<Cairo::Context>& /*cr*/,
	size_t /*i*/,
	float /*xstart*/,
	float /*xend*/,
	int /*visleft*/,
	int /*visright*/)
{
	//Unused, but we have to override it
}
