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
#include "../scopehal/AnalogRenderer.h"
#include "../scopehal/ProtocolDecoder.h"
#include "EyeRenderer.h"
#include "EyeDecoder.h"
#include <gdkmm.h>
#include <gdkmm/pixbuf.h>

using namespace std;

struct RGBQUAD
{
	uint8_t rgbRed;
	uint8_t rgbGreen;
	uint8_t rgbBlue;
	uint8_t rgbAlpha;
};

static const RGBQUAD g_eyeColorScale[256] =
{
	{   0,   0,   0, 0   },     {   4,   2,  20, 255 },     {   7,   4,  35, 255 },     {   9,   5,  45, 255 },
    {  10,   6,  53, 255 },     {  11,   7,  60, 255 },     {  13,   7,  66, 255 },     {  14,   8,  71, 255 },
    {  14,   8,  75, 255 },     {  16,  10,  80, 255 },     {  16,  10,  85, 255 },     {  17,  10,  88, 255 },
    {  18,  11,  92, 255 },     {  19,  11,  95, 255 },     {  19,  12,  98, 255 },     {  20,  12, 102, 255 },
    {  20,  13, 104, 255 },     {  20,  13, 107, 255 },     {  21,  13, 110, 255 },     {  21,  13, 112, 255 },
    {  23,  14, 114, 255 },     {  23,  14, 117, 255 },     {  23,  14, 118, 255 },     {  23,  14, 121, 255 },
    {  23,  15, 122, 255 },     {  24,  15, 124, 255 },     {  24,  15, 126, 255 },     {  24,  14, 127, 255 },
    {  25,  15, 129, 255 },     {  25,  15, 130, 255 },     {  25,  16, 131, 255 },     {  26,  16, 132, 255 },
    {  26,  15, 134, 255 },     {  27,  16, 136, 255 },     {  26,  16, 136, 255 },     {  26,  16, 137, 255 },
    {  27,  16, 138, 255 },     {  26,  16, 138, 255 },     {  26,  16, 140, 255 },     {  27,  16, 141, 255 },
    {  27,  16, 141, 255 },     {  28,  17, 142, 255 },     {  27,  17, 142, 255 },     {  27,  16, 143, 255 },
    {  28,  17, 144, 255 },     {  28,  17, 144, 255 },     {  28,  17, 144, 255 },     {  28,  17, 144, 255 },
    {  28,  17, 144, 255 },     {  28,  17, 145, 255 },     {  28,  17, 145, 255 },     {  28,  17, 145, 255 },
    {  28,  17, 145, 255 },     {  30,  17, 144, 255 },     {  32,  17, 143, 255 },     {  34,  17, 142, 255 },
    {  35,  16, 140, 255 },     {  37,  17, 139, 255 },     {  38,  16, 138, 255 },     {  40,  17, 136, 255 },
    {  42,  16, 136, 255 },     {  44,  16, 134, 255 },     {  46,  17, 133, 255 },     {  47,  16, 133, 255 },
    {  49,  16, 131, 255 },     {  51,  16, 130, 255 },     {  53,  17, 129, 255 },     {  54,  16, 128, 255 },
    {  56,  16, 127, 255 },     {  58,  16, 126, 255 },     {  60,  16, 125, 255 },     {  62,  16, 123, 255 },
    {  63,  16, 122, 255 },     {  65,  16, 121, 255 },     {  67,  16, 120, 255 },     {  69,  16, 119, 255 },
    {  70,  16, 117, 255 },     {  72,  16, 116, 255 },     {  74,  16, 115, 255 },     {  75,  15, 114, 255 },
    {  78,  16, 113, 255 },     {  79,  16, 112, 255 },     {  81,  16, 110, 255 },     {  83,  15, 110, 255 },
    {  84,  15, 108, 255 },     {  86,  16, 108, 255 },     {  88,  15, 106, 255 },     {  90,  15, 105, 255 },
    {  91,  16, 103, 255 },     {  93,  15, 103, 255 },     {  95,  15, 102, 255 },     {  96,  15, 100, 255 },
    {  98,  15, 100, 255 },     { 100,  15,  98, 255 },     { 101,  15,  97, 255 },     { 104,  15,  96, 255 },
    { 106,  15,  95, 255 },     { 107,  15,  94, 255 },     { 109,  14,  92, 255 },     { 111,  14,  92, 255 },
    { 112,  15,  90, 255 },     { 114,  14,  89, 255 },     { 116,  15,  87, 255 },     { 118,  14,  87, 255 },
    { 119,  14,  86, 255 },     { 121,  14,  85, 255 },     { 123,  14,  83, 255 },     { 124,  14,  83, 255 },
    { 126,  15,  81, 255 },     { 128,  14,  80, 255 },     { 130,  14,  78, 255 },     { 132,  14,  77, 255 },
    { 134,  14,  76, 255 },     { 137,  14,  74, 255 },     { 139,  14,  73, 255 },     { 141,  14,  71, 255 },
    { 143,  13,  70, 255 },     { 146,  13,  68, 255 },     { 148,  14,  67, 255 },     { 150,  13,  65, 255 },
    { 153,  14,  64, 255 },     { 155,  14,  62, 255 },     { 157,  13,  61, 255 },     { 159,  13,  60, 255 },
    { 162,  13,  58, 255 },     { 165,  13,  56, 255 },     { 166,  13,  55, 255 },     { 169,  13,  54, 255 },
    { 171,  13,  52, 255 },     { 173,  13,  50, 255 },     { 176,  13,  48, 255 },     { 179,  12,  47, 255 },
    { 181,  12,  45, 255 },     { 183,  12,  45, 255 },     { 185,  12,  43, 255 },     { 188,  13,  41, 255 },
    { 190,  12,  40, 255 },     { 192,  12,  38, 255 },     { 194,  13,  37, 255 },     { 197,  12,  35, 255 },
    { 199,  12,  33, 255 },     { 201,  12,  32, 255 },     { 204,  12,  30, 255 },     { 206,  12,  29, 255 },
    { 209,  12,  28, 255 },     { 211,  12,  26, 255 },     { 213,  12,  25, 255 },     { 216,  12,  23, 255 },
    { 218,  11,  22, 255 },     { 221,  12,  20, 255 },     { 223,  11,  18, 255 },     { 224,  11,  17, 255 },
    { 227,  11,  16, 255 },     { 230,  11,  14, 255 },     { 231,  11,  12, 255 },     { 234,  12,  11, 255 },
    { 235,  13,  10, 255 },     { 235,  15,  11, 255 },     { 235,  17,  11, 255 },     { 235,  19,  11, 255 },
    { 236,  21,  10, 255 },     { 236,  23,  10, 255 },     { 237,  24,  10, 255 },     { 237,  26,  10, 255 },
    { 236,  28,   9, 255 },     { 237,  30,  10, 255 },     { 237,  32,   9, 255 },     { 238,  34,   9, 255 },
    { 238,  35,   9, 255 },     { 238,  38,   8, 255 },     { 239,  39,   9, 255 },     { 239,  42,   8, 255 },
    { 240,  44,   9, 255 },     { 240,  45,   8, 255 },     { 240,  47,   8, 255 },     { 240,  49,   8, 255 },
    { 241,  51,   7, 255 },     { 241,  53,   8, 255 },     { 241,  55,   7, 255 },     { 241,  57,   7, 255 },
    { 242,  58,   7, 255 },     { 242,  60,   7, 255 },     { 242,  62,   6, 255 },     { 243,  64,   6, 255 },
    { 244,  66,   6, 255 },     { 243,  68,   5, 255 },     { 244,  69,   6, 255 },     { 244,  71,   6, 255 },
    { 245,  74,   6, 255 },     { 245,  76,   5, 255 },     { 245,  79,   5, 255 },     { 246,  82,   5, 255 },
    { 246,  85,   5, 255 },     { 247,  87,   4, 255 },     { 247,  90,   4, 255 },     { 248,  93,   3, 255 },
    { 249,  96,   4, 255 },     { 248,  99,   3, 255 },     { 249, 102,   3, 255 },     { 250, 105,   3, 255 },
    { 250, 107,   2, 255 },     { 250, 110,   2, 255 },     { 251, 113,   2, 255 },     { 252, 115,   1, 255 },
    { 252, 118,   2, 255 },     { 253, 121,   1, 255 },     { 253, 124,   1, 255 },     { 253, 126,   1, 255 },
    { 254, 129,   0, 255 },     { 255, 132,   0, 255 },     { 255, 135,   0, 255 },     { 255, 138,   1, 255 },
    { 254, 142,   3, 255 },     { 253, 145,   4, 255 },     { 253, 148,   6, 255 },     { 252, 151,   9, 255 },
    { 252, 155,  11, 255 },     { 251, 158,  12, 255 },     { 251, 161,  14, 255 },     { 250, 163,  15, 255 },
    { 251, 165,  16, 255 },     { 250, 167,  17, 255 },     { 250, 169,  18, 255 },     { 250, 170,  19, 255 },
    { 250, 172,  20, 255 },     { 249, 174,  21, 255 },     { 249, 177,  22, 255 },     { 248, 178,  23, 255 },
    { 248, 180,  24, 255 },     { 247, 182,  25, 255 },     { 247, 184,  26, 255 },     { 247, 185,  27, 255 },
    { 247, 188,  27, 255 },     { 247, 191,  26, 255 },     { 248, 194,  25, 255 },     { 249, 197,  24, 255 },
    { 248, 200,  22, 255 },     { 249, 203,  21, 255 },     { 249, 205,  20, 255 },     { 250, 209,  18, 255 },
    { 250, 212,  18, 255 },     { 250, 214,  16, 255 },     { 251, 217,  15, 255 },     { 251, 221,  14, 255 },
    { 251, 223,  13, 255 },     { 251, 226,  12, 255 },     { 252, 229,  11, 255 },     { 253, 231,   9, 255 },
    { 253, 234,   9, 255 },     { 253, 237,   7, 255 },     { 253, 240,   6, 255 },     { 253, 243,   5, 255 },
    { 254, 246,   4, 255 },     { 254, 248,   3, 255 },     { 255, 251,   1, 255 },     { 255, 254,   1, 255 }
};

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
	float ytop = m_ypos + m_padding;
	float ybot = m_ypos + m_height - m_padding;
	float plotheight = m_height - 2*m_padding;
	float halfheight = plotheight/2;
	float ymid = halfheight + ytop;

	RenderStartCallback(cr, width, visleft, visright, ranges);
	cr->save();

	EyeCapture* capture = dynamic_cast<EyeCapture*>(m_channel->GetData());
	if(capture != NULL)
	{
		//Save time scales
		float tscale = m_channel->m_timescale * capture->m_timescale;

		float yscale = 0.4 * plotheight;
		float yoffset = halfheight;

		//TODO: Decide what size divisions to use
		float y_grid = 0.25;

		//Center line is solid
		cr->set_source_rgba(0.7, 0.7, 0.7, 1.0);
		cr->move_to(visleft, ymid);
		cr->line_to(visright, ymid);
		cr->stroke();

		//Dotted lines above and below
		vector<double> dashes;
		dashes.push_back(2);
		dashes.push_back(2);
		cr->set_dash(dashes, 0);
		map<float, float> gridmap;
		gridmap[0] = ymid;
		for(float dv=y_grid; ; dv += y_grid)
		{
			float dy = dv * yscale;
			if(dy >= halfheight)
				break;

			gridmap[dv] = ymid - dy;
			gridmap[-dv] = ymid + dy;

			cr->move_to(visleft, ymid + dy);
			cr->line_to(visright, ymid + dy);

			cr->move_to(visleft, ymid - dy);
			cr->line_to(visright, ymid - dy);
		}
		cr->stroke();
		cr->unset_dash();

		//Create pixel value histogram
		int64_t ui_width = dynamic_cast<EyeDecoder*>(m_channel)->GetUIWidth();
		int pixel_count = ui_width * m_height;
		int64_t* histogram = new int64_t[pixel_count];
		for(int i=0; i<pixel_count; i++)
			histogram[i] = 0;

		//Compute the histogram
		int64_t maxcount = 0;
		for(size_t i=0; i<capture->GetDepth(); i++)
		{
			int64_t tstart = capture->GetSampleStart(i);
			if(tstart >= ui_width)
				tstart = ui_width-1;
			auto sample = (*capture)[i];

			int ystart = yscale * sample.m_voltage * -1 + yoffset;
			if(ystart >= m_height)
				ystart = m_height-1;
			if(ystart < 0)
				ystart = 0;

			int64_t& pix = histogram[tstart + ystart*ui_width];
			pix += sample.m_count;
			if(pix > maxcount)
				maxcount = pix;
		}

		//Scale things to that we get a better coverage of the color range
		float saturation = 0.5;
		float cmax = maxcount * saturation;

		//Convert to RGB values
		int row_width = ui_width*3;
		RGBQUAD* pixels = new RGBQUAD[pixel_count * 4];
		for(int y=0; y<plotheight; y++)
		{
			for(int x=0; x<ui_width; x++)
			{
				int npix = (int)ceil((255.0f * histogram[y*ui_width + x]) / cmax);
				if(npix > 255)
					npix = 255;
				pixels[y*row_width + x]					= g_eyeColorScale[npix];
				pixels[y*row_width + x + ui_width]		= g_eyeColorScale[npix];
				pixels[y*row_width + x + ui_width*2]	= g_eyeColorScale[npix];
			}
		}

		//Fill empty rows with the row above
		for(int y=1; y<plotheight; y++)
		{
			bool empty = true;
			for(int x=0; x<ui_width; x++)
			{
				if(histogram[y*ui_width + x] != 0)
				{
					empty = false;
					break;
				}
			}

			if(empty)
				memcpy(pixels + y*row_width, pixels + (y-1)*row_width, row_width*sizeof(RGBQUAD));
		}

		//Create the actual pixmap
		Glib::RefPtr< Gdk::Pixbuf > pixbuf = Gdk::Pixbuf::create_from_data(
			reinterpret_cast<unsigned char*>(pixels),
			Gdk::COLORSPACE_RGB,
			true,
			8,
			row_width,
			plotheight,
			row_width * 4);
		Cairo::RefPtr< Cairo::ImageSurface > surface =
			Cairo::ImageSurface::create(Cairo::FORMAT_ARGB32, row_width, plotheight);
		Cairo::RefPtr< Cairo::Context > context = Cairo::Context::create(surface);
		Gdk::Cairo::set_source_pixbuf(context, pixbuf, 0.0, 0.0);
		context->paint();

		//Render the bitmap over our background and grid
		cr->save();
			cr->begin_new_path();
			cr->translate(250 + visleft, ytop);
			cr->scale(tscale, 1);
			cr->set_source(surface, 0.0, 0.0);
			cr->rectangle(0, 0, row_width, plotheight);
			cr->clip();
			cr->paint();
		cr->restore();

		//Draw background for the Y axis labels
		AnalogRenderer::DrawVerticalAxisLabels(cr, width, visleft, visright, ranges, ytop, plotheight, gridmap);

		delete[] pixels;
		delete[] histogram;
	}

	cr->restore();
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
