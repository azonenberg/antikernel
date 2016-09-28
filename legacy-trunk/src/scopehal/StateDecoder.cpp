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
	@brief Declaration of StateDecoder
 */

#include "../scopehal/scopehal.h"
#include "../scopehal/StringRenderer.h"
#include "StateDecoder.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

StateDecoder::StateDecoder(
	string hwname, string color, NameServer& namesrvr, string fname)
	: ProtocolDecoder(hwname, OscilloscopeChannel::CHANNEL_TYPE_COMPLEX, color, namesrvr)
{
	//Set up channels
	m_signalNames.push_back("din");
	m_channels.push_back(NULL);	

	m_filename_name = "Constant filename";
	m_parameters[m_filename_name] = ProtocolDecoderParameter(ProtocolDecoderParameter::TYPE_FILENAME);
	m_parameters[m_filename_name].SetFileName(fname);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Factory methods

ChannelRenderer* StateDecoder::CreateRenderer()
{
	return new StringRenderer(this);
}

bool StateDecoder::ValidateChannel(size_t i, OscilloscopeChannel* channel)
{
	if( (i == 0) && (channel->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL) && (channel->GetWidth() != 1)  )
		return true;
	return false;
}

string StateDecoder::GetProtocolName()
{
	return "Enumerated constant";
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Actual decoder logic

void StateDecoder::Refresh()
{
	//Get the input data
	if(m_channels[0] == NULL)
	{
		SetData(NULL);
		return;
	}
	DigitalBusCapture* din = dynamic_cast<DigitalBusCapture*>(m_channels[0]->GetData());
	if(din == NULL)
	{
		SetData(NULL);
		return;
	}
	
	//Load the file
	string fname = m_parameters[m_filename_name].GetFileName();
	FILE* fp = fopen(fname.c_str(), "r");
	if(!fp)
	{
		SetData(NULL);
		return;
	}
	char line[1024];
	map<int, string> cmap;
	while(NULL != fgets(line, sizeof(line), fp))
	{
		//Remove comments
		char* comment_start = strstr(line, "//");
		if(comment_start != NULL)
			comment_start[0] = '\0';
			
		//Skip blank lines
		if(strlen(line) == 0)
			continue;
			
		//Replace tabs with spaces
		char* p = line;
		while(*p)
		{
			if(*p == '\t')
				*p = ' ';
			p++;
		}
			
		//Initial string parsing
		char name[1024];
		char value[1024];
		if(2 != sscanf(line, "%1023[^ ] %1023s", name, value))
			continue;
		
		//Decode C-format values
		int ival = 0;
		if(strstr(value, "'") == NULL)
			ival = strtol(value, NULL, 0);
		
		//Decode Verilog-format values
		else
		{
			int length;
			char tmpval[1024];
			char base;
			if(value[0] == '\'')
			{
				length = 32;
				sscanf(value, "'%c%1023s", &base, tmpval);
			}
			else
				sscanf(value, "%2d'%c%1023s", &length, &base, tmpval);
			
			//Ignore length for now
			
			//Switch on base
			switch(base)
			{
			case 'b':
				ival = strtol(tmpval, NULL, 2);
				break;
			case 'h':
				ival = strtol(tmpval, NULL, 16);
				break;
			case 'd':
			default:
				ival = strtol(tmpval, NULL, 10);
				break;
			}
		}
		
		//Done
		cmap[ival] = name;
	}
	fclose(fp);
	
	//Initialize output capture
	StringCapture* cap = new StringCapture;
	cap->m_timescale = din->m_timescale;
	
	//Decoding
	for(size_t i=0; i<din->m_samples.size(); i++)
	{
		DigitalBusSample& sin = din->m_samples[i];
		vector<bool>& s = sin.m_sample;
		int ival = 0;
		for(size_t j=0; j<s.size(); j++)
			ival = (ival << 1) | (s[j] ? 1 : 0);
		
		//Print hex for invalid stuff
		string str;	
		if(cmap.find(ival) != cmap.end())
			str = cmap[ival];
		else
		{
			char buf[16];
			snprintf(buf, sizeof(buf), "0x%x", ival);
			str = buf;
		}
			
		cap->m_samples.push_back(StringSample(sin.m_offset, sin.m_duration, str));
		
	}
	
	SetData(cap);
}
