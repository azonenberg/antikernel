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
	@brief Implementation of RigolDS1000SeriesOscilloscope
 */

#include "scopehal.h"
#include "RigolDS1000SeriesOscilloscope.h"

#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

#include <string.h>

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

RigolDS1000SeriesOscilloscope::RigolDS1000SeriesOscilloscope(const char* fname, const char* serial)
	: m_serial(serial)
{
	//TODO: support UARTs (have to set baud rate etc)
	//Current code is USBTMC only
	
	//Open the device
	m_hfile = open(fname, O_RDWR);
	if(m_hfile < 0)
	{
		throw JtagExceptionWrapper(
			"Failed to open file",
			"",
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	//Ask the device for its ID
	write(m_hfile, "*IDN?", 5);
	char idcode[1024];
	int len = read(m_hfile, idcode, 1023);
	if(len <= 0)
	{
		throw JtagExceptionWrapper(
			"Failed to read ID code",
			"",
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	idcode[len] = 0;
	
	//Parse ID code
	char vendor[1024];
	char model[1024];
	char serl[1024];
	char firmware[1024];
	sscanf(idcode, "%1023[^,],%1023[^,],%1023[^,],%1023s", vendor, model, serl, firmware);
	
	//We already have serial number and vendor
	//Save exact model number, ignore firmware revision for now
	m_model = model;
	
	//Set up channels
	if(m_model == "DS1102D")
	{
		m_channels.push_back(new OscilloscopeChannel("CH1", OscilloscopeChannel::CHANNEL_TYPE_ANALOG, "#ffff80"));
		m_channels.push_back(new OscilloscopeChannel("CH2", OscilloscopeChannel::CHANNEL_TYPE_ANALOG, "#80c0ff"));
		/*char dname[16];
		for(int i=0; i<16; i++)
		{
			snprintf(dname, sizeof(dname), "D%d", i);
			m_channels.push_back(new OscilloscopeChannel(dname, OscilloscopeChannel::CHANNEL_TYPE_DIGITAL, "#80ff80"));
		}*/
	}
	else
	{
		throw JtagExceptionWrapper(
			"Unrecognized model (not supported)",
			"",
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	//Reset stuff
	Stop();
	usleep(50 * 1000);
	
	//Go to long-memory mode
	//const char* cmd = ":ACQ:MEMD LONG";
	const char* cmd = ":ACQ:MEMD NORM";
	write(m_hfile, cmd, strlen(cmd));
	
	//Set capture mode to MAX so we get the whole sample
	cmd = ":WAV:POIN:MODE MAX";
	write(m_hfile, cmd, strlen(cmd));
}

RigolDS1000SeriesOscilloscope::~RigolDS1000SeriesOscilloscope()
{
	//Disengate remote control
	//From reading the docs apparently the "force trigger" command does this... who would have thought?
	const char* cmd = ":KEY:FORC";
	write(m_hfile, cmd, strlen(cmd));
	
	//Done	
	close(m_hfile);
	m_hfile = 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Device information

string RigolDS1000SeriesOscilloscope::GetName()
{
	return m_model;
}

string RigolDS1000SeriesOscilloscope::GetVendor()
{
	return "Rigol Technologies";
}

string RigolDS1000SeriesOscilloscope::GetSerial()
{
	return m_serial;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Triggering

Oscilloscope::TriggerMode RigolDS1000SeriesOscilloscope::PollTrigger()
{
	//Ask the scope for its status
	const char* cmd = ":TRIG:STAT?";
	write(m_hfile, cmd, strlen(cmd));
	
	//See what comes back
	char trigger_mode[128];
	int count = read(m_hfile, trigger_mode, 127);
	trigger_mode[count] = 0;
	
	//RUN, STOP, T'D, WAIT or AUTO
	string strig(trigger_mode);
	if(strig == "RUN")
		return Oscilloscope::TRIGGER_MODE_RUN;
	else if(strig == "STOP")
		return Oscilloscope::TRIGGER_MODE_STOP;
	else if(strig == "T'D")
		return Oscilloscope::TRIGGER_MODE_TRIGGERED;
	else if(strig == "WAIT")
		return Oscilloscope::TRIGGER_MODE_WAIT;
	else if(strig == "AUTO")
		return Oscilloscope::TRIGGER_MODE_AUTO;
	else
		printf("What does \"%s\" mean?\n", trigger_mode);
	
	throw JtagExceptionWrapper(
		"Unrecognized trigger mode (not supported)",
		"",
		JtagException::EXCEPTION_TYPE_ADAPTER);
}

/**
	@brief Checks if long memory is enabled
 */
bool RigolDS1000SeriesOscilloscope::IsLongMemoryEnabled()
{
	const char* cmd = ":ACQ:MEMD?";
	write(m_hfile, cmd, strlen(cmd));
	char depth[128];
	int count = read(m_hfile, depth, 127);
	depth[count] = 0;
	if(!strcmp(depth, "LONG"))
		return true;
	return false;
}

/**
	@brief Checks if a given analog channel is enabled
 */
bool RigolDS1000SeriesOscilloscope::IsAnalogChannelEnabled(int ch)
{
	//TODO: support more than 2 channels
	
	const char* cmd = NULL;
	if(ch == 1)
		cmd = ":CHAN1:DISP?";
	else if(ch == 2)
		cmd = ":CHAN2:DISP?";
	else
	{
		throw JtagExceptionWrapper(
			"Bad channel number",
			"",
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	write(m_hfile, cmd, strlen(cmd));
	
	char status[128];
	int count = read(m_hfile, status, 127);
	status[count] = 0;
	if(!strcmp(status, "1"))	//Observed result is 1 and 0, not ON and OFF like the PDF docs say
		return true;
	return false;
}

void RigolDS1000SeriesOscilloscope::AcquireData(sigc::slot1<int, float> /*progress_callback*/)
{
	//Look up the memory depth
	//printf("Beginning acquisition\n");
	bool lmem = IsLongMemoryEnabled();
	//printf("    Long memory: %d\n", lmem);
	
	//Purge old capture data
	for(size_t i=0; i<m_channels.size(); i++)
		m_channels[i]->SetData(NULL);
	
	//TODO: LA
	
	//See which channels are enabled
	for(int i=1; i<=2; i++)
	{
		if(IsAnalogChannelEnabled(i))
			AcquireAnalogData(i, lmem);
	}
	
	//TODO: LA
}

void RigolDS1000SeriesOscilloscope::AcquireAnalogData(int /*ch*/, bool /*lmem*/)
{
	throw JtagExceptionWrapper(
		"Acquisition logic is broken due to buggy USBTMC, not usable atm",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	
	/*
	//printf("    Acquiring analog data\n");
	
	//Get voltage scale and offset
	float scale = GetChannelScale(ch);
	float offset = GetChannelOffset(ch);
	
	//Get time scale
	float tscale = GetTimeScale();
	float toff = GetTimeOffset();
	//printf("    Time scale %.5f offset %.5f\n", tscale, toff);
	
	//Time scale is defined as seconds per grid division; there's 12 divisions on the whole screen (600 samples)
	float display_width = 12 * tscale;				//in seconds
	float time_per_sample = display_width / 600;	//seconds per sample
	//printf("Time scale is %f seconds per sample\n", time_per_sample);
	
	//Convert to picoseconds (base time unit)
	time_per_sample *= 1E12;
	int64_t toff_scaled = toff * 1E12;	
		
	AnalogCapture* capture = new AnalogCapture;
	capture->m_timescale = time_per_sample;
		
	//TODO: How do we read the entire memory buffer?
	//(should be 8k/16k samples in normal memory or 512k/1024k in long, depending on if one or both channels are active)
	int read_ksamples = 8;
	if(lmem)
		read_ksamples = 512;
	//TODO: Double if the other channel is turned off
	
	//Stop capturing (so we can use long memory)
	//Wait 10ms for the scope to stop capturing
	//TODO: adjust this based on the time scale
	Stop();
	usleep(10 * 1000);
	
	//Format the read command
	char cmd[32];
	snprintf(cmd, sizeof(cmd), ":WAV:DATA? CHAN%d", ch);
	
	//Read and discard the first dataset (610 points)
	write(m_hfile, cmd, strlen(cmd));
	unsigned char garbage[4096];
	int count = read(m_hfile, garbage, 4096);
	printf("    Fetched garbage data (%d points)\n", count);
		
	//Read the real dataset (TODO: size)
	const int bufsize = 10240;
	unsigned char capture_buf[bufsize];
	int64_t base = 0;
	int nread = 0;
	int samples_read = 0;
	for(int i=0; ; i++)
	{
		if(i == 0)
		{
			//Stop capturing
			Stop();
			usleep(10 * 1000);
			
			//Send the command
			write(m_hfile, cmd, strlen(cmd));
			usleep(20 * 1000);
		}

		//Read, aborting if something goes wrong
		int count = 0;
		if( (count = read(m_hfile, capture_buf, bufsize)) < 0)
			break;
			
		int rawcount = count;
		nread ++;
		
		printf("Read %d bytes of actual data\n", count);
			
		//Skip first 10 points of first capture
		unsigned char* capture_data = capture_buf;
		if(i == 0)
		{
			count -= 10;
			capture_data += 10;
		}
		
		//Skip first capture entirely
		//if(i <= 1)
		//if(i == 0)
		//	continue;
		
		samples_read += count;
			
		printf("    Fetched real data (%d points, i=%d, samples_read = %d)\n", count, i, samples_read);
		
		//Process the data into floats
		//Based on algorithm at http://www.cibomahto.com/2010/04/controlling-a-rigol-oscilloscope-using-linux-and-python/
		for(int j=0; j<count; j++)
		{
			capture->m_samples.push_back(AnalogSample(
				base + j + toff_scaled,
				time_per_sample,
				 ((240 - capture_data[j])*(scale / 25)) - (offset + scale*4.6)
			));
		}
			
		base += count;
		
		//if(samples_read >= (1024 * read_ksamples))
		//	break;
		
		//TODO: don't hard-code magic buffer-size number from driver
		if(rawcount != 4066)
			break;
	}

	//Done
	m_channels[ch - 1]->SetData(capture);
	*/
}

float RigolDS1000SeriesOscilloscope::GetChannelScale(int ch)
{
	const char* cmd;
	if(ch == 1)
		cmd = ":CHAN1:SCAL?";
	else if(ch == 2)
		cmd = ":CHAN2:SCAL?";
	write(m_hfile, cmd, strlen(cmd));

	char rbuf[128];
	int n = read(m_hfile, rbuf, 127);
	rbuf[n] = 0;
	
	float scale;
	sscanf(rbuf, "%10f", &scale);
	return scale;
}

float RigolDS1000SeriesOscilloscope::GetChannelOffset(int ch)
{
	const char* cmd;
	if(ch == 1)
		cmd = ":CHAN1:OFFS?";
	else if(ch == 2)
		cmd = ":CHAN2:OFFS?";
	write(m_hfile, cmd, strlen(cmd));
	
	char rbuf[128];
	int n = read(m_hfile, rbuf, 127);
	rbuf[n] = 0;
	
	float offset;
	sscanf(rbuf, "%10f", &offset);
	return offset;
}

void RigolDS1000SeriesOscilloscope::Start()
{
	const char* cmd = ":RUN";
	write(m_hfile, cmd, strlen(cmd));
}

void RigolDS1000SeriesOscilloscope::StartSingleTrigger()
{
	const char* cmd = ":TRIG:SING:MODE";
	write(m_hfile, cmd, strlen(cmd));	
	cmd = ":RUN";
	write(m_hfile, cmd, strlen(cmd));
}

void RigolDS1000SeriesOscilloscope::Stop()
{
	const char* cmd = ":STOP";
	write(m_hfile, cmd, strlen(cmd));
}

float RigolDS1000SeriesOscilloscope::GetTimeScale()
{
	const char* cmd = ":TIM:SCAL?";
	write(m_hfile, cmd, strlen(cmd));

	char rbuf[128];
	int n = read(m_hfile, rbuf, 127);
	rbuf[n] = 0;
	
	float scale;
	sscanf(rbuf, "%10f", &scale);
	return scale;
}

float RigolDS1000SeriesOscilloscope::GetTimeOffset()
{
	const char* cmd = ":TIM:OFFS?";
	write(m_hfile, cmd, strlen(cmd));

	char rbuf[128];
	int n = read(m_hfile, rbuf, 127);
	rbuf[n] = 0;
	
	float offset;
	sscanf(rbuf, "%10f", &offset);
	return offset;
}
