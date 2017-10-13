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
#include <gdkmm.h>
#include <gdkmm/pixbuf.h>

using namespace std;

struct RGBTRIPLE
{
	uint8_t rgbtRed;
	uint8_t rgbtGreen;
	uint8_t rgbtBlue;
};

static const RGBTRIPLE g_eyeColorScale[256] =
{
	{   0,   0,   0 },     {   4,   2,  20 },     {   7,   4,  35 },     {   9,   5,  45 },
    {  10,   6,  53 },     {  11,   7,  60 },     {  13,   7,  66 },     {  14,   8,  71 },
    {  14,   8,  75 },     {  16,  10,  80 },     {  16,  10,  85 },     {  17,  10,  88 },
    {  18,  11,  92 },     {  19,  11,  95 },     {  19,  12,  98 },     {  20,  12, 102 },
    {  20,  13, 104 },     {  20,  13, 107 },     {  21,  13, 110 },     {  21,  13, 112 },
    {  23,  14, 114 },     {  23,  14, 117 },     {  23,  14, 118 },     {  23,  14, 121 },
    {  23,  15, 122 },     {  24,  15, 124 },     {  24,  15, 126 },     {  24,  14, 127 },
    {  25,  15, 129 },     {  25,  15, 130 },     {  25,  16, 131 },     {  26,  16, 132 },
    {  26,  15, 134 },     {  27,  16, 136 },     {  26,  16, 136 },     {  26,  16, 137 },
    {  27,  16, 138 },     {  26,  16, 138 },     {  26,  16, 140 },     {  27,  16, 141 },
    {  27,  16, 141 },     {  28,  17, 142 },     {  27,  17, 142 },     {  27,  16, 143 },
    {  28,  17, 144 },     {  28,  17, 144 },     {  28,  17, 144 },     {  28,  17, 144 },
    {  28,  17, 144 },     {  28,  17, 145 },     {  28,  17, 145 },     {  28,  17, 145 },
    {  28,  17, 145 },     {  30,  17, 144 },     {  32,  17, 143 },     {  34,  17, 142 },
    {  35,  16, 140 },     {  37,  17, 139 },     {  38,  16, 138 },     {  40,  17, 136 },
    {  42,  16, 136 },     {  44,  16, 134 },     {  46,  17, 133 },     {  47,  16, 133 },
    {  49,  16, 131 },     {  51,  16, 130 },     {  53,  17, 129 },     {  54,  16, 128 },
    {  56,  16, 127 },     {  58,  16, 126 },     {  60,  16, 125 },     {  62,  16, 123 },
    {  63,  16, 122 },     {  65,  16, 121 },     {  67,  16, 120 },     {  69,  16, 119 },
    {  70,  16, 117 },     {  72,  16, 116 },     {  74,  16, 115 },     {  75,  15, 114 },
    {  78,  16, 113 },     {  79,  16, 112 },     {  81,  16, 110 },     {  83,  15, 110 },
    {  84,  15, 108 },     {  86,  16, 108 },     {  88,  15, 106 },     {  90,  15, 105 },
    {  91,  16, 103 },     {  93,  15, 103 },     {  95,  15, 102 },     {  96,  15, 100 },
    {  98,  15, 100 },     { 100,  15,  98 },     { 101,  15,  97 },     { 104,  15,  96 },
    { 106,  15,  95 },     { 107,  15,  94 },     { 109,  14,  92 },     { 111,  14,  92 },
    { 112,  15,  90 },     { 114,  14,  89 },     { 116,  15,  87 },     { 118,  14,  87 },
    { 119,  14,  86 },     { 121,  14,  85 },     { 123,  14,  83 },     { 124,  14,  83 },
    { 126,  15,  81 },     { 128,  14,  80 },     { 130,  14,  78 },     { 132,  14,  77 },
    { 134,  14,  76 },     { 137,  14,  74 },     { 139,  14,  73 },     { 141,  14,  71 },
    { 143,  13,  70 },     { 146,  13,  68 },     { 148,  14,  67 },     { 150,  13,  65 },
    { 153,  14,  64 },     { 155,  14,  62 },     { 157,  13,  61 },     { 159,  13,  60 },
    { 162,  13,  58 },     { 165,  13,  56 },     { 166,  13,  55 },     { 169,  13,  54 },
    { 171,  13,  52 },     { 173,  13,  50 },     { 176,  13,  48 },     { 179,  12,  47 },
    { 181,  12,  45 },     { 183,  12,  45 },     { 185,  12,  43 },     { 188,  13,  41 },
    { 190,  12,  40 },     { 192,  12,  38 },     { 194,  13,  37 },     { 197,  12,  35 },
    { 199,  12,  33 },     { 201,  12,  32 },     { 204,  12,  30 },     { 206,  12,  29 },
    { 209,  12,  28 },     { 211,  12,  26 },     { 213,  12,  25 },     { 216,  12,  23 },
    { 218,  11,  22 },     { 221,  12,  20 },     { 223,  11,  18 },     { 224,  11,  17 },
    { 227,  11,  16 },     { 230,  11,  14 },     { 231,  11,  12 },     { 234,  12,  11 },
    { 235,  13,  10 },     { 235,  15,  11 },     { 235,  17,  11 },     { 235,  19,  11 },
    { 236,  21,  10 },     { 236,  23,  10 },     { 237,  24,  10 },     { 237,  26,  10 },
    { 236,  28,   9 },     { 237,  30,  10 },     { 237,  32,   9 },     { 238,  34,   9 },
    { 238,  35,   9 },     { 238,  38,   8 },     { 239,  39,   9 },     { 239,  42,   8 },
    { 240,  44,   9 },     { 240,  45,   8 },     { 240,  47,   8 },     { 240,  49,   8 },
    { 241,  51,   7 },     { 241,  53,   8 },     { 241,  55,   7 },     { 241,  57,   7 },
    { 242,  58,   7 },     { 242,  60,   7 },     { 242,  62,   6 },     { 243,  64,   6 },
    { 244,  66,   6 },     { 243,  68,   5 },     { 244,  69,   6 },     { 244,  71,   6 },
    { 245,  74,   6 },     { 245,  76,   5 },     { 245,  79,   5 },     { 246,  82,   5 },
    { 246,  85,   5 },     { 247,  87,   4 },     { 247,  90,   4 },     { 248,  93,   3 },
    { 249,  96,   4 },     { 248,  99,   3 },     { 249, 102,   3 },     { 250, 105,   3 },
    { 250, 107,   2 },     { 250, 110,   2 },     { 251, 113,   2 },     { 252, 115,   1 },
    { 252, 118,   2 },     { 253, 121,   1 },     { 253, 124,   1 },     { 253, 126,   1 },
    { 254, 129,   0 },     { 255, 132,   0 },     { 255, 135,   0 },     { 255, 138,   1 },
    { 254, 142,   3 },     { 253, 145,   4 },     { 253, 148,   6 },     { 252, 151,   9 },
    { 252, 155,  11 },     { 251, 158,  12 },     { 251, 161,  14 },     { 250, 163,  15 },
    { 251, 165,  16 },     { 250, 167,  17 },     { 250, 169,  18 },     { 250, 170,  19 },
    { 250, 172,  20 },     { 249, 174,  21 },     { 249, 177,  22 },     { 248, 178,  23 },
    { 248, 180,  24 },     { 247, 182,  25 },     { 247, 184,  26 },     { 247, 185,  27 },
    { 247, 188,  27 },     { 247, 191,  26 },     { 248, 194,  25 },     { 249, 197,  24 },
    { 248, 200,  22 },     { 249, 203,  21 },     { 249, 205,  20 },     { 250, 209,  18 },
    { 250, 212,  18 },     { 250, 214,  16 },     { 251, 217,  15 },     { 251, 221,  14 },
    { 251, 223,  13 },     { 251, 226,  12 },     { 252, 229,  11 },     { 253, 231,   9 },
    { 253, 234,   9 },     { 253, 237,   7 },     { 253, 240,   6 },     { 253, 243,   5 },
    { 254, 246,   4 },     { 254, 248,   3 },     { 255, 251,   1 },     { 255, 254,   1 }
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
	RenderStartCallback(cr, width, visleft, visright, ranges);
	cr->save();


	EyeCapture* capture = dynamic_cast<EyeCapture*>(m_channel->GetData());
	if(capture != NULL)
	{
		//Save time scales
		float tscale = m_channel->m_timescale * capture->m_timescale;

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

			float yscale = 0.4 * m_height;
			float yoffset = m_height / 2;
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
		RGBTRIPLE* pixels = new RGBTRIPLE[pixel_count * 3];
		for(int y=0; y<m_height; y++)
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
		for(int y=1; y<m_height; y++)
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
				memcpy(pixels + y*row_width, pixels + (y-1)*row_width, row_width*sizeof(RGBTRIPLE));
		}

		//Create the actual pixmap
		Glib::RefPtr< Gdk::Pixbuf > pixbuf = Gdk::Pixbuf::create_from_data(
			reinterpret_cast<unsigned char*>(pixels),
			Gdk::COLORSPACE_RGB,
			false,
			8,
			row_width,
			m_height,
			row_width * 3);
		Cairo::RefPtr< Cairo::ImageSurface > surface =
			Cairo::ImageSurface::create(Cairo::FORMAT_RGB24, row_width, m_height);
		Cairo::RefPtr< Cairo::Context > context = Cairo::Context::create(surface);
		Gdk::Cairo::set_source_pixbuf(context, pixbuf, 0.0, 0.0);
		context->paint();

		//and render
		cr->save();
			cr->begin_new_path();
			cr->translate(250 + visleft, m_ypos);
			cr->scale(tscale, 1);
			cr->set_source(surface, 0.0, 0.0);
			cr->rectangle(0, 0, row_width, m_height);
			cr->clip();
			cr->paint();
		cr->restore();

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
