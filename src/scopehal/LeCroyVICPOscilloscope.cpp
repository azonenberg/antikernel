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

#include "scopehal.h"
#include "LeCroyVICPOscilloscope.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

LeCroyVICPOscilloscope::LeCroyVICPOscilloscope(string hostname, unsigned short port)
	: m_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
	, m_hostname(hostname)
	, m_port(port)
	, m_nextSequence(1)
	, m_lastSequence(1)
{
	LogDebug("Connecting to VICP oscilloscope at %s:%d\n", hostname.c_str(), port);
	
	if(!m_socket.Connect(hostname, port))
	{
		LogError("Couldn't connect to socket");
		return;
	}
	if(!m_socket.DisableNagle())
	{
		LogError("Couldn't disable Nagle\n");
		return;
	}

	//Ask for the ID
	SendCommand("*IDN?", true);
	string reply = ReadSingleBlockString();
	char vendor[128] = "";
	char model[128] = "";
	char serial[128] = "";
	char version[128] = "";
	if(4 != sscanf(reply.c_str(), "*IDN %127[^,],%127[^,],%127[^,],%127s", vendor, model, serial, version))
	{
		LogError("Bad IDN response\n");
		return;
	}
	m_vendor = vendor;
	m_model = model;
	m_serial = serial;
	m_fwVersion = version;

	//Last digit of the model number is the number of channels
	int nchans = m_model[m_model.length() - 1] - '0';
	for(int i=0; i<nchans; i++)
	{
		//Hardware name of the channel
		string chname = string("CH1");
		chname[2] += i;

		//Color the channels based on LeCroy's standard color sequence (yellow-pink-cyan-green)
		string color = "#ffffff";
		switch(i)
		{
			case 0:
				color = "#ffff80";
				break;

			case 1:
				color = "#ff8080";
				break;

			case 2:
				color = "#80ffff";
				break;

			case 3:
				color = "#80ff80";
				break;
		}
		
		m_channels.push_back(new OscilloscopeChannel(
			chname,
			OscilloscopeChannel::CHANNEL_TYPE_ANALOG,
			color,
			false,
			1));
	}
	m_analogChannelCount = nchans;

	//Look at options and see if we have digital channels too
	SendCommand("*OPT?", true);
	reply = ReadSingleBlockString();
	if(reply.length() > 3)
	{
		//eat initial whitespace etc
		char* r = &reply[1];
		while(isspace(*r))
			r++;

		//Read options until we hit a null
		vector<string> options;
		string opt;
		while(true)
		{
			if(*r == 0)
			{
				options.push_back(opt);
				break;
			}

			else if(*r == ',')
			{
				options.push_back(opt);
				opt = "";
			}

			else
				opt += *r;

			r ++;
		}

		//Print out the option list
		LogDebug("Installed options:\n");
		if(options.empty())
			LogDebug("* None\n");
		for(auto o : options)
			LogDebug("* %s\n", o.c_str());
	}

	//Clear the state-change register to we get rid of any history we don't care about
	PollTrigger();
}

LeCroyVICPOscilloscope::~LeCroyVICPOscilloscope()
{
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VICP protocol logic

bool LeCroyVICPOscilloscope::SendCommand(string cmd, bool eoi)
{
	//Operation and flags header
	string payload;
	uint8_t op 	= OP_DATA;
	if(eoi)
		op |= OP_EOI;
	//TODO: remote, clear, poll flags
	payload += op;
	payload += 0x01;							//protocol version number
	payload += GetNextSequenceNumber(eoi);
	payload += '\0';							//reserved

	//Next 4 header bytes are the message length (network byte order)
	uint32_t len = cmd.length();
	payload += (len >> 24) & 0xff;
	payload += (len >> 16) & 0xff;
	payload += (len >> 8)  & 0xff;
	payload += (len >> 0)  & 0xff;

	//Add message data
	payload += cmd;

	//Actually send it
	if(!m_socket.SendLooped((const unsigned char*)payload.c_str(), payload.size()))
		return false;
	
	return true;
}

uint8_t LeCroyVICPOscilloscope::GetNextSequenceNumber(bool eoi)
{
	m_lastSequence = m_nextSequence;

	//EOI increments the sequence number.
	//Wrap mod 256, but skip zero!
	if(eoi)
	{
		m_nextSequence ++;
		if(m_nextSequence == 0)
			m_nextSequence = 1;
	}

	return m_lastSequence;
}

/**
	@brief Read exactly one packet from the socket
 */
string LeCroyVICPOscilloscope::ReadData()
{
	//Read the header
	unsigned char header[8];
	if(!m_socket.RecvLooped(header, 8))
		return "";

	//Sanity check
	if(header[1] != 1)
	{
		LogError("Bad VICP protocol version\n");
		return "";
	}
	if(header[2] != m_lastSequence)
	{
		LogError("Bad VICP sequence number\n");
		return "";
	}
	if(header[3] != 0)
	{
		LogError("Bad VICP reserved field\n");
		return "";
	}

	//TODO: pay attention to header?

	//Read the message data
	uint32_t len = (header[4] << 24) | (header[5] << 16) | (header[6] << 8) | header[7];
	string ret;
	ret.resize(len);
	if(!m_socket.RecvLooped((unsigned char*)&ret[0], len))
		return "";

	return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Device information

string LeCroyVICPOscilloscope::GetName()
{
	return m_model;
}

string LeCroyVICPOscilloscope::GetVendor()
{
	return m_vendor;
}

string LeCroyVICPOscilloscope::GetSerial()
{
	return m_serial;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Triggering

void LeCroyVICPOscilloscope::ResetTriggerConditions()
{
	//FIXME
}

Oscilloscope::TriggerMode LeCroyVICPOscilloscope::PollTrigger()
{
	LogDebug("Polling trigger\n");

	//Read the Internal State Change Register
	SendCommand("INR?");
	string sinr = ReadSingleBlockString();
	int inr;
	if(1 != sscanf(sinr.c_str(), "INR %d", &inr))
		return TRIGGER_MODE_STOP;

	//See if we got a waveform
	if(inr & 0x0001)
		return TRIGGER_MODE_TRIGGERED;

	//No waveform, but ready for one?
	if(inr & 0x2000)
		return TRIGGER_MODE_RUN;

	//Stopped, no data available
	//TODO: how to handle auto / normal trigger mode?
	return TRIGGER_MODE_TRIGGERED;
}

bool LeCroyVICPOscilloscope::AcquireData(sigc::slot1<int, float> progress_callback)
{
	LogDebug("Acquire data\n");
	
	//Read data for everything waveform
	SendCommand("WAVEFORM_SETUP SP,0,NP,0,FP,0,SN,0");

	for(unsigned int i=0; i<m_analogChannelCount; i++)
	{	
		//Update the UI as we acquire
		progress_callback(i * 1.0f / m_analogChannelCount);

		//TODO: read the full WaveDesc block and parse other fields?

		//Read the acquisition settings
		string cmd = "C1:INSPECT? 'HORIZ_INTERVAL'";
		cmd[1] += i;
		SendCommand(cmd);
		string wavedesc = ReadSingleBlockString();
		string format = "C1:INSP \"HORIZ_INTERVAL : %f \"";
		format[1] += i;
		float interval;
		sscanf(wavedesc.c_str(), format.c_str(), &interval);
		LogDebug("Sample interval: %.2f ps\n", interval * 1e12f);

		//Create and format the capture
		AnalogCapture* cap = new AnalogCapture;
		cap->m_timescale = interval * 1e12f;

		//Read the actual data (in ASCII floating-point volts, five values per line)
		cmd = "C1:INSPECT? DATA_ARRAY_1,FLOAT";
		cmd[1] += i;
		SendCommand(cmd);

		//Read data, split it up into whitespace-delimited floats
		string data = ReadMultiBlockString();
		string tmp;
		for(size_t j=data.find("\"") + 1; j<data.length() && data[j] != '\"'; j++)
		{
			if(isspace(data[j]))
			{
				if(tmp != "")
					cap->m_samples.push_back(AnalogSample(j, 1, atof(tmp.c_str())));
				tmp = "";
			}
			else
				tmp += data[j];
		}

		m_channels[i]->SetData(cap);
	}
	
	return false;
}

string LeCroyVICPOscilloscope::ReadSingleBlockString()
{
	string payload = ReadData();
	payload += "\0";
	return payload;
}

string LeCroyVICPOscilloscope::ReadMultiBlockString()
{
	//Read until we get the closing quote
	string data;
	bool first  = true;
	while(true)
	{
		string payload = ReadSingleBlockString();
		data += payload;
		if(!first && payload.find("\"") != string::npos)
			break;
		first = false;
	}
	return data;
}

void LeCroyVICPOscilloscope::Start()
{
	LogDebug("Start multi trigger\n");
}

void LeCroyVICPOscilloscope::StartSingleTrigger()
{
	LogDebug("Start single trigger\n");
	
	SendCommand("TRIG_MODE SINGLE");
}

void LeCroyVICPOscilloscope::Stop()
{
	LogDebug("Stop\n");
}

void LeCroyVICPOscilloscope::SetTriggerForChannel(OscilloscopeChannel* channel, std::vector<TriggerType> triggerbits)
{
}
