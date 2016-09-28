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
	@brief Implementation of NetworkedOscilloscope
 */

#include "scopehal.h"
#include "NetworkedOscilloscope.h"
#include "ProtocolDecoder.h"
#include "../scoped/ScopedProtocol.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>

#include <memory.h>

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

NetworkedOscilloscope::NetworkedOscilloscope(const std::string& host, unsigned short port)
{
	//Make ASCII port number
	char sport[16];
	snprintf(sport, sizeof(sport), "%d", port);
	
	//Look up the hostname info
	addrinfo hints;
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;		//allow both v4 and v6
	hints.ai_socktype = SOCK_STREAM;		//using TCP
	hints.ai_flags = AI_NUMERICSERV;	//numeric port number
	addrinfo* addr;
	//int code = 0;
	if(0 != (/*code = */getaddrinfo(host.c_str(), sport, &hints, &addr)))
	{
		throw JtagExceptionWrapper(
			"DNS lookup of server failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	
	//Try creating the socket and connecting to the host
	m_sock = -1;
	for(addrinfo* p = addr; p != NULL; p=p->ai_next)
	{
		m_sock = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
		if(m_sock < 0)
			continue;		
		if(0 != connect(m_sock, p->ai_addr, p->ai_addrlen))
		{
			close(m_sock);
			m_sock = -1;
			continue;
		}
		break;
	}
	freeaddrinfo(addr);
	if(m_sock < 0)
	{
		throw JtagExceptionWrapper(
			"Failed to create socket",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	
	//Set no-delay flag
	int flag = 1;
	if(0 != setsockopt(m_sock, IPPROTO_TCP, TCP_NODELAY, (char *)&flag, sizeof(flag) ))
	{
		throw JtagExceptionWrapper(
			"Failed to set TCP_NODELAY",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	
	LoadChannels();
}

NetworkedOscilloscope::~NetworkedOscilloscope()
{
	close(m_sock);
	m_sock = 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Information queries

string NetworkedOscilloscope::GetName()
{
	uint16_t op = SCOPED_OP_GET_NAME;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
	string str;
	NetworkedJtagInterface::RecvString(m_sock, str);
	return str;
}

string NetworkedOscilloscope::GetVendor()
{
	uint16_t op = SCOPED_OP_GET_VENDOR;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
	string str;
	NetworkedJtagInterface::RecvString(m_sock, str);
	return str;
}

string NetworkedOscilloscope::GetSerial()
{
	uint16_t op = SCOPED_OP_GET_SERIAL;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
	string str;
	NetworkedJtagInterface::RecvString(m_sock, str);
	return str;
}

void NetworkedOscilloscope::LoadChannels()
{
	//Get channel count
	uint16_t op = SCOPED_OP_GET_CHANNELS;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
	uint16_t count;
	NetworkedJtagInterface::read_looped(m_sock, (unsigned char*)&count, 2);
	
	//Load each channel
	for(unsigned int i=0; i<count; i++)
	{
		//Get hardware name of the channel
		op = SCOPED_OP_GET_HWNAME;
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
		uint16_t ch = i;
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&ch, 2);
		string hwname;
		NetworkedJtagInterface::RecvString(m_sock, hwname);

		//Get the color
		op = SCOPED_OP_GET_DISPLAYCOLOR;
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&ch, 2);
		string color;
		NetworkedJtagInterface::RecvString(m_sock, color);
		
		//Get the type
		op = SCOPED_OP_GET_CHANNEL_TYPE;
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&ch, 2);
		uint16_t type;
		NetworkedJtagInterface::read_looped(m_sock, (unsigned char*)&type, 2);
		
		//Create the channel
		m_channels.push_back(new OscilloscopeChannel(
			hwname,
			static_cast<OscilloscopeChannel::ChannelType>(type),
			color));
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Triggering

Oscilloscope::TriggerMode NetworkedOscilloscope::PollTrigger()
{
	uint16_t op = SCOPED_OP_GET_TRIGGER_MODE;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
	uint16_t mode;
	NetworkedJtagInterface::read_looped(m_sock, (unsigned char*)&mode, 2);
	return static_cast<Oscilloscope::TriggerMode>(mode);
}

void NetworkedOscilloscope::AcquireData(sigc::slot1<int, float> /*progress_callback*/)
{
	//Tell the scope to acquire the data
	uint16_t op = SCOPED_OP_ACQUIRE;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
	
	//Copy it to us
	for(size_t i=0; i<m_channels.size(); i++)
	{
		//If the channel is procedural, refresh it and skip the rest
		if(m_channels[i]->IsProcedural())
		{
			ProtocolDecoder* decoder = dynamic_cast<ProtocolDecoder*>(m_channels[i]);
			if(decoder == NULL)
			{
				throw JtagExceptionWrapper(
					"Something claimed to be a procedural channel but isn't a protocol decoder",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			decoder->Refresh();
			continue;
		}
		
		//Clear out the old data
		m_channels[i]->SetData(NULL);
		
		//TODO: Skip decoded channels
		
		//Get the number of samples in the buffer
		op = SCOPED_OP_CAPTURE_DEPTH;
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
		uint16_t ch = i;
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&ch, 2);
		uint32_t count;
		NetworkedJtagInterface::read_looped(m_sock, (unsigned char*)&count, 4);
			
		//No data? Stop now
		if(count == 0)
			continue;
			
		//printf("Channel %zu: %u samples\n", i, count);
		
		//Get the time scale
		op = SCOPED_OP_CAPTURE_TIMESCALE;
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&ch, 2);
		int64_t scale;
		NetworkedJtagInterface::read_looped(m_sock, (unsigned char*)&scale, sizeof(scale));
				
		//Read the data
		op = SCOPED_OP_CAPTURE_DATA;
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
		NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&ch, 2);
		switch(m_channels[i]->GetType())
		{
			case OscilloscopeChannel::CHANNEL_TYPE_ANALOG:
			{
				AnalogSample s(0,0,0);
				AnalogCapture* capture = new AnalogCapture;
				capture->m_timescale = scale;
				for(uint64_t j=0; j<count; j++)
				{
					NetworkedJtagInterface::read_looped(m_sock, (unsigned char*)&s, sizeof(s));
					capture->m_samples.push_back(s);
				}
				m_channels[i]->SetData(capture);
			}
			break;
			
			case OscilloscopeChannel::CHANNEL_TYPE_DIGITAL:
			{
				DigitalSample s(0,0,0);
				DigitalCapture* capture = new DigitalCapture;
				capture->m_timescale = scale;
				for(uint64_t j=0; j<count; j++)
				{
					NetworkedJtagInterface::read_looped(m_sock, (unsigned char*)&s, sizeof(s));
					capture->m_samples.push_back(s);
				}
				m_channels[i]->SetData(capture);
			}
			break;
			
			case OscilloscopeChannel::CHANNEL_TYPE_COMPLEX:
			{
				throw JtagExceptionWrapper(
					"Client-side handling of complex channels not implemented",
					"",
					JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
			}
			break;
		}
	}
	
	//TODO: Update decoded channels
}

void NetworkedOscilloscope::Start()
{
	uint16_t op = SCOPED_OP_START;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
}

void NetworkedOscilloscope::StartSingleTrigger()
{
	uint16_t op = SCOPED_OP_START_SINGLE;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
}

void NetworkedOscilloscope::Stop()
{
	uint16_t op = SCOPED_OP_STOP;
	NetworkedJtagInterface::write_looped(m_sock, (unsigned char*)&op, 2);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Triggering

void NetworkedOscilloscope::ResetTriggerConditions()
{
	throw JtagExceptionWrapper(
		"",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
}

void NetworkedOscilloscope::SetTriggerForChannel(OscilloscopeChannel* /*channel*/, std::vector<TriggerType> /*triggerbits*/)
{
	throw JtagExceptionWrapper(
		"",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
}
