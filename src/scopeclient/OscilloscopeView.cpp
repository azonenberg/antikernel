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
	@brief Implementation of OscilloscopeView
 */

#include "scopeclient.h"
#include "../scopehal/Oscilloscope.h"
#include "../scopehal/TimescaleRenderer.h"
#include "OscilloscopeView.h"
#include "MainWindow.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction
OscilloscopeView::OscilloscopeView(Oscilloscope* scope, MainWindow* parent)
	: m_scope(scope)
	, m_parent(parent)
{
	m_height = 64;
	m_width = 64;

	m_sizeDirty = true;

	add_events(
		Gdk::EXPOSURE_MASK |
		Gdk::BUTTON_PRESS_MASK |
		Gdk::BUTTON_RELEASE_MASK);

	m_cursorpos = 0;
}

OscilloscopeView::~OscilloscopeView()
{
	for(ChannelMap::iterator it=m_renderers.begin(); it != m_renderers.end(); ++it)
		delete it->second;
	m_renderers.clear();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rendering

void OscilloscopeView::SetSizeDirty()
{
	m_sizeDirty = true;
	queue_draw();
}

bool OscilloscopeView::on_draw(const Cairo::RefPtr<Cairo::Context>& cr)
{
	try
	{
		Glib::RefPtr<Gdk::Window> window = get_bin_window();
		if(window)
		{
			//printf("========== NEW FRAME ==========\n");

			//Get dimensions of the virtual canvas (max of requested size and window size)
			Gtk::Allocation allocation = get_allocation();
			int width = allocation.get_width();
			int height = allocation.get_height();
			if(m_width > width)
				width = m_width;
			if(m_height > height)
				m_height = height;

			//Get the visible area of the window
			int pwidth = get_width();
			//int pheight = get_height();
			int xoff = get_hadjustment()->get_value();
			int yoff = get_vadjustment()->get_value();

			//Set up drawing context
			cr->save();
			cr->translate(-xoff, -yoff);

			//Fill background
			cr->set_source_rgb(0, 0, 0);
			cr->rectangle(0, 0, width, height);
			cr->fill();

			//We do crazy stuff in which stuff moves around every time we render. As a result, partial redraws will fail
			//horribly. If the clip region isn't the full window, redraw with the full region selected.
			double clip_x1, clip_y1, clip_x2, clip_y2;
			cr->get_clip_extents(clip_x1, clip_y1, clip_x2, clip_y2);
			int clipwidth = clip_x2 - clip_x1;
			if(clipwidth != pwidth)
				queue_draw();

			//Re-calculate mappings
			std::vector<time_range> ranges;
			MakeTimeRanges(ranges);

			//Draw zigzag lines
			//Don't draw break at end of last range, though
			for(size_t i=0; i<ranges.size(); i++)
			{
				if((i+1) == ranges.size())
					break;

				time_range& range = ranges[i];
				float xshift = 5;
				float yshift = 5;
				float ymid = height/2;

				cr->save();

					//Set up path
					cr->move_to(range.xend,        0);
					cr->line_to(range.xend,        ymid - 2*yshift);
					cr->line_to(range.xend+xshift, ymid -   yshift);
					cr->line_to(range.xend-xshift, ymid +   yshift);
					cr->line_to(range.xend,        ymid + 2*yshift);
					cr->line_to(range.xend,        height);

					//Fill background
					cr->set_source_rgb(1,1,1);
					cr->set_line_width(10);
					cr->stroke_preserve();

					//Fill foreground
					cr->set_source_rgb(0,0,0);
					cr->set_line_width(6);
					cr->stroke();

				cr->restore();
			}

			//All good, draw individual channels
			for(ChannelMap::iterator it=m_renderers.begin(); it != m_renderers.end(); ++it)
				it->second->Render(cr, width, 0 + xoff, width + xoff, ranges);

			//Figure out time scale for cursor
			float tscale = 0;
			if(m_scope->GetChannelCount() != 0)
			{
				OscilloscopeChannel* chan = m_scope->GetChannel(0);
				CaptureChannelBase* capture = chan->GetData();
				if(capture != NULL)
					 tscale = chan->m_timescale * capture->m_timescale;
			}

			//Draw cursor
			for(size_t i=0; i<ranges.size(); i++)
			{
				time_range& range = ranges[i];

				//Draw cursor (if it's in this range)
				if( (m_cursorpos >= range.tstart) && (m_cursorpos <= range.tend) )
				{
					float dt = m_cursorpos - range.tstart;
					float dx = dt * tscale;
					float xpos = range.xstart + dx;

					cr->set_source_rgb(1,1,0);
					cr->move_to(xpos, 0);
					cr->line_to(xpos, height);
					cr->stroke();
				}
			}

			//Done
			cr->restore();
		}

		if(m_sizeDirty)
		{
			m_sizeDirty = false;
			Resize();
			queue_draw();
		}
	}

	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		exit(1);
	}

	return true;
}

bool OscilloscopeView::on_button_press_event(GdkEventButton* event)
{
	//Left button?
	if(event->button == 1)
	{
		//Re-calculate mappings
		std::vector<time_range> ranges;
		MakeTimeRanges(ranges);

		//Figure out time scale
		float tscale = 0;
		if(m_scope->GetChannelCount() != 0)
		{
			OscilloscopeChannel* chan = m_scope->GetChannel(0);
			CaptureChannelBase* capture = chan->GetData();
			if(capture != NULL)
				 tscale = chan->m_timescale * capture->m_timescale;
		}

		//Figure out which range the cursor position is in
		for(size_t i=0; i<ranges.size(); i++)
		{
			time_range& range = ranges[i];
			if( (event->x >= range.xstart) && (event->x <= range.xend) )
			{
				float dx = event->x - range.xstart;
				float dt = dx / tscale;

				//Round dt to the nearest integer rather than truncating
				int64_t dt_floor = floor(dt);
				if( (dt - dt_floor) > 0.5)
					dt_floor ++;

				m_cursorpos = range.tstart + dt_floor;
				queue_draw();
			}
		}
	}

	return true;
}

/**
	@brief Channel list and/or visibility states have changed, refresh
 */
void OscilloscopeView::Refresh()
{
	//Delete old renderers
	for(ChannelMap::iterator it=m_renderers.begin(); it != m_renderers.end(); ++it)
		delete it->second;
	m_renderers.clear();

	//Setup for renderer creation
	int y = 0;
	int spacing = 5;
	size_t count = m_scope->GetChannelCount();

	//Create timescale renderer
	LogTrace("Refreshing oscilloscope view\n");
	LogIndenter li;
	if(m_scope->GetChannelCount() != 0)
	{
		TimescaleRenderer* pTimescale = new TimescaleRenderer(m_scope->GetChannel(0));
		pTimescale->m_ypos = y;
		y += pTimescale->m_height + spacing;
		m_renderers[NULL] = pTimescale;
		LogTrace("%30s: y = %d - %d\n", "timescale", pTimescale->m_ypos, pTimescale->m_ypos + pTimescale->m_height);
	}

	//Create renderers for each channel
	for(size_t i=0; i<count; i++)
	{
		//Skip invisible channels
		OscilloscopeChannel* chan = m_scope->GetChannel(i);
		if(!chan->m_visible)
			continue;

		ChannelRenderer* pRender = m_scope->GetChannel(i)->CreateRenderer();
		pRender->m_ypos = y;
		y += pRender->m_height + spacing;
		m_renderers[chan] = pRender;

		LogTrace("%30s: y = %d - %d\n", chan->m_displayname.c_str(), pRender->m_ypos, pRender->m_ypos + pRender->m_height);
	}

	SetSizeDirty();
}

void OscilloscopeView::Resize()
{
	m_width = 1;
	m_height = 1;

	for(ChannelMap::iterator it=m_renderers.begin(); it != m_renderers.end(); ++it)
	{
		ChannelRenderer* pRender = it->second;

		//Height
		int bottom = pRender->m_ypos + pRender->m_height;
		if(bottom > m_height)
			m_height = bottom;

		//Width
		if(pRender->m_width > m_width)
			m_width = pRender->m_width;
	}

	set_size(m_width, m_height);
}

void OscilloscopeView::MakeTimeRanges(std::vector<time_range>& ranges)
{
	ranges.clear();
	if(m_scope->GetChannelCount() == 0)
		return;
	OscilloscopeChannel* chan = m_scope->GetChannel(0);
	CaptureChannelBase* capture = chan->GetData();
	if(capture == NULL)
		return;
	if(m_renderers.empty())
		return;

	//First pass through the data
	//Split into ranges and render broken lines
	float startpos = 0;
	time_range current_range;
	current_range.xstart = 0;
	current_range.tstart = 0;
	float tscale = chan->m_timescale * capture->m_timescale;
	for(size_t i=0; i<capture->GetDepth(); i++)
	{
		//If it would show up as more than m_maxsamplewidth pixels wide, clip it
		float sample_width = tscale * capture->GetSampleLen(i);
		float msw = m_renderers.begin()->second->m_maxsamplewidth;
		if(sample_width > msw)
		{
			sample_width = msw;
			float xmid = startpos + sample_width/2;

			int64_t dt = (sample_width/2)/tscale;

			//End the current range
			current_range.xend = xmid;
			current_range.tend = capture->GetSampleStart(i) + dt;
			ranges.push_back(current_range);

			//Start a new range
			current_range.xstart = xmid;
			current_range.tstart = (capture->GetSampleStart(i) + capture->GetSampleLen(i))	//end of sample
									- dt;
		}

		//Go on to the next sample
		startpos += sample_width;

		//End of capture? Push it back
		if(i == capture->GetDepth()-1)
		{
			current_range.tend = capture->GetSampleStart(i) + (sample_width/2)/tscale;
			current_range.xend = startpos+sample_width;
			ranges.push_back(current_range);
		}
	}
}
