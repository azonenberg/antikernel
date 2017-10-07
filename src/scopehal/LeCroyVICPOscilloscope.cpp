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
#include "ProtocolDecoder.h"
#include "base64.h"

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

	//Turn off headers (complicate parsing and add fluff to the packets)
	SendCommand("CHDR OFF", true);

	//Ask for the ID
	SendCommand("*IDN?", true);
	string reply = ReadSingleBlockString();
	char vendor[128] = "";
	char model[128] = "";
	char serial[128] = "";
	char version[128] = "";
	if(4 != sscanf(reply.c_str(), "%127[^,],%127[^,],%127[^,],%127s", vendor, model, serial, version))
	{
		LogError("Bad IDN response %s\n", reply.c_str());
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
			1));
	}
	m_analogChannelCount = nchans;
	m_digitalChannelCount = 0;

	//Look at options and see if we have digital channels too
	SendCommand("*OPT?", true);
	reply = ReadSingleBlockString();
	if(reply.length() > 3)
	{
		//Read options until we hit a null
		vector<string> options;
		string opt;
		for(unsigned int i=0; i<reply.length(); i++)
		{
			if(reply[i] == 0)
			{
				options.push_back(opt);
				break;
			}

			else if(reply[i] == ',')
			{
				options.push_back(opt);
				opt = "";
			}

			else
				opt += reply[i];
		}
		if(opt != "")
			options.push_back(opt);

		//Print out the option list and do processing for each
		LogDebug("Installed options:\n");
		if(options.empty())
			LogDebug("* None\n");
		for(auto o : options)
		{
			//If we have the LA module installed, add the digital channels
			if(o == "MSXX")
			{
				LogDebug("* MSXX (logic analyzer)\n");
				m_digitalChannelCount = 16;

				char chn[8];
				for(int i=0; i<16; i++)
				{
					snprintf(chn, sizeof(chn), "D%d", i);
					m_channels.push_back(new OscilloscopeChannel(
						chn,
						OscilloscopeChannel::CHANNEL_TYPE_DIGITAL,
						GetDefaultChannelColor(m_channels.size()),
						1));
				}
			}
			else
				LogDebug("* %s (not yet implemented)\n", o.c_str());
		}
	}

	//Desired format for waveform data
	SendCommand("WAVEFORM_SETUP SP,0,NP,0,FP,0,SN,0");
	SendCommand("COMM_FORMAT DEF,WORD,BIN");

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
		//LogError("Bad VICP sequence number %d (expected %d)\n", header[2], m_lastSequence);
		//return "";
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
	//LogDebug("Polling trigger\n");

	//Read the Internal State Change Register
	SendCommand("INR?");
	string sinr = ReadSingleBlockString();
	int inr = atoi(sinr.c_str());

	//See if we got a waveform
	if(inr & 0x0001)
		return TRIGGER_MODE_TRIGGERED;

	//No waveform, but ready for one?
	if(inr & 0x2000)
		return TRIGGER_MODE_RUN;

	//Stopped, no data available
	//TODO: how to handle auto / normal trigger mode?
	return TRIGGER_MODE_RUN;
}

bool LeCroyVICPOscilloscope::ReadWaveformBlock(string& data)
{
	//First packet is just a header "DAT1,\n". Throw it away.
	ReadData();

	//Second blocks is a header including the message length. Parse that.
	string lhdr = ReadSingleBlockString();
	unsigned int num_bytes = atoi(lhdr.c_str() + 2);
	if(num_bytes == 0)
	{
		ReadData();
		return true;
	}
	//LogDebug("Expecting %d bytes (%d samples)\n", num_bytes, num_samples);

	//Done with headers, data comes next

	//TODO: update expected times after some long captures are done
	//TODO: do progress feedback eventually
	/*
	float base_progress = i*1.0f / m_analogChannelCount;
	float expected_header_time = 0.25;
	float expected_data_time = 0.09f * num_samples / 1000;
	float expected_total_time = expected_header_time + expected_data_time;
	float header_fraction = expected_header_time / expected_total_time;
	base_progress += header_fraction / m_analogChannelCount;
	progress_callback(base_progress);
	*/

	//Read the data
	data.clear();
	while(true)
	{
		string payload = ReadData();
		data += payload;
		if(data.size() >= num_bytes)
			break;
		//float local_progress = data.size() * 1.0f / num_bytes;
		//progress_callback(base_progress + local_progress / m_analogChannelCount);
	}

	//Throw away the newline at the end
	ReadData();

	if(data.size() != num_bytes)
	{
		LogError("bad rx block size (got %zu, expected %u)\n", data.size(), num_bytes);
		return false;
	}

	return true;
}

bool LeCroyVICPOscilloscope::AcquireData(sigc::slot1<int, float> progress_callback)
{
	LogDebug("Acquire data\n");

	for(unsigned int i=0; i<m_analogChannelCount; i++)
	{
		progress_callback(i*1.0f / m_analogChannelCount);

		//double start = GetTime();

		//Ask for the wavedesc (in raw binary)
		string cmd = "C1:WF? 'DESC'";
		cmd[1] += i;
		SendCommand(cmd);
		string wavedesc;
		if(!ReadWaveformBlock(wavedesc))
			break;

		//Parse the wavedesc headers
		//Ref: http://qtwork.tudelft.nl/gitdata/users/guen/qtlabanalysis/analysis_modules/general/lecroy.py
		unsigned char* pdesc = (unsigned char*)(&wavedesc[0]);
		float v_gain = *reinterpret_cast<float*>(pdesc + 156);
		float v_off = *reinterpret_cast<float*>(pdesc + 160);
		float interval = *reinterpret_cast<float*>(pdesc + 176) * 1e12f;
		//double h_off = *reinterpret_cast<double*>(pdesc + 180);
		//LogDebug("V: gain=%f off=%f\n", v_gain, v_off);
		//LogDebug("H: off=%lf\n", h_off);
		//LogDebug("Sample interval: %.2f ps\n", interval);

		//double dt = GetTime() - start;
		//start = GetTime();
		//LogDebug("Headers took %.3f ms\n", dt * 1000);

		//Set up the capture we're going to store our data into
		AnalogCapture* cap = new AnalogCapture;
		cap->m_timescale = interval;

		//Ask for the actual data (in raw binary)
		cmd = "C1:WF? 'DAT1'";
		cmd[1] += i;
		SendCommand(cmd);
		string data;
		if(!ReadWaveformBlock(data))
			break;
		//dt = GetTime() - start;
		//LogDebug("RX took %.3f ms\n", dt * 1000);

		//Decode the samples
		unsigned int num_samples = data.size()/2;
		//LogDebug("Got %u samples\n", num_samples);
		int16_t* wdata = (int16_t*)&data[0];
		for(unsigned int i=0; i<num_samples; i++)
			cap->m_samples.push_back(AnalogSample(i, 1, wdata[i] * v_gain + v_off));

		//Done, update the data
		m_channels[i]->SetData(cap);
	}

	if(m_digitalChannelCount > 0)
	{
		//Ask for the waveform. This is a weird XML-y format but I can't find any other way to get it :(
		string cmd = "Digital1:WF?";
		SendCommand(cmd);
		string data;
		if(!ReadWaveformBlock(data))
			return false;

		//For now, we assume Digital1 is using default config with all channels enabled.

		//Quick and dirty string searching. We only care about a small fraction of the XML
		//so no sense bringing in a full parser.
		string tmp = data.substr(data.find("<HorPerStep>") + 12);
		tmp = tmp.substr(0, tmp.find("</HorPerStep>"));
		float interval = atof(tmp.c_str()) * 1e12f;
		//LogDebug("Sample interval: %.2f ps\n", interval);

		tmp = data.substr(data.find("<NumSamples>") + 12);
		tmp = tmp.substr(0, tmp.find("</NumSamples>"));
		int num_samples = atoi(tmp.c_str());
		//LogDebug("Expecting %d samples\n", num_samples);

		//Pull out the actual binary data (Base64 coded)
		tmp = data.substr(data.find("<BinaryData>") + 12);
		tmp = tmp.substr(0, tmp.find("</BinaryData>"));

		//Decode the base64
		base64_decodestate state;
		base64_init_decodestate(&state);
		unsigned char* block = new unsigned char[tmp.length()];	//base64 is smaller than plaintext, leave room
		int binlen = base64_decode_block(tmp.c_str(), tmp.length(), (char*)block, &state);

		//We have each channel's data from start to finish before the next (no interleaving).
		for(unsigned int i=0; i<m_digitalChannelCount; i++)
		{
			DigitalCapture* cap = new DigitalCapture;
			cap->m_timescale = interval;

			for(int j=0; j<num_samples; j++)
				cap->m_samples.push_back(DigitalSample(j, 1, block[i*num_samples + j]));

			//Done, update the data
			m_channels[m_analogChannelCount + i]->SetData(cap);
		}

		delete[] block;
	}

	//Refresh protocol decoders
	for(size_t i=0; i<m_channels.size(); i++)
	{
		ProtocolDecoder* decoder = dynamic_cast<ProtocolDecoder*>(m_channels[i]);
		if(decoder != NULL)
			decoder->Refresh();
	}

	return true;
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

void LeCroyVICPOscilloscope::SetTriggerForChannel(
	OscilloscopeChannel* /*channel*/,
	vector<TriggerType> /*triggerbits*/)
{
}
