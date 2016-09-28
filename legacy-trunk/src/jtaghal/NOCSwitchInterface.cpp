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
	@brief Implementation of NOCSwitchInterfac
 */
#include "jtaghal.h"
#include "NOCSwitchInterface.h"
#include "../nocswitch/nocswitch_messages.h"

#ifndef _WINDOWS
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif

#include <memory.h>

/**
	@brief Initializes this object to an empty state but does not connect to a server
 */
NOCSwitchInterface::NOCSwitchInterface()
	: m_socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP)
{
	
}

/**
	@brief Initializes this object to an empty state and connects to a server
	
	@throw JtagException if the connection fails
	
	@param server	Hostname of the server to connect to
	@param port		Port number to connect to (host byte ordering)
 */
NOCSwitchInterface::NOCSwitchInterface(const std::string& server, uint16_t port)
	: m_socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP)
{
	Connect(server, port);
}

/**
	@brief Connects to a nocswitch server
	
	@throw JtagException if the connection fails
	
	@param server	Hostname of the server to connect to
	@param port		Port number to connect to (host byte ordering)
 */
void NOCSwitchInterface::Connect(const std::string& server, uint16_t port)
{
	m_socket.Connect(server, port);
	
	//Set no-delay flag
	int flag = 1;
	if(0 != setsockopt(m_socket, IPPROTO_TCP, TCP_NODELAY, (char *)&flag, sizeof(flag) ))
	{
		throw JtagExceptionWrapper(
			"Failed to set TCP_NODELAY",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
}

/**
	@brief Disconnects from the server
 */
NOCSwitchInterface::~NOCSwitchInterface()
{
	try
	{
		if(m_socket)
		{
			uint16_t op = NOCSWITCH_OP_QUIT;
			m_socket.SendLooped((unsigned char*)&op, 2);
		}
	}
	catch(const JtagException& ex)
	{
		//ignore, but don't rethrow
	}
}

void NOCSwitchInterface::SendRPCMessage(const RPCMessage& tx_msg)
{
	uint16_t op = NOCSWITCH_OP_SENDRPC;
	m_socket.SendLooped((unsigned char*)&op, 2);
	
	unsigned char buf[16];
	tx_msg.Pack(buf);
	m_socket.SendLooped(buf, 16);
}

bool NOCSwitchInterface::RecvRPCMessage(RPCMessage& rx_msg)
{
	uint16_t op = NOCSWITCH_OP_RECVRPC;
	m_socket.SendLooped((unsigned char*)&op, 2);
	uint8_t found = 0;
	m_socket.RecvLooped((unsigned char*)&found, 1);
	if(found)
	{
		unsigned char buf[16];
		m_socket.RecvLooped(buf, 16);
		rx_msg.Unpack(buf);
		//printf("Got message: %s\n", rx_msg.Format().c_str());
		return true;
	}	
	return false;
}

void NOCSwitchInterface::SendDMAMessage(const DMAMessage& tx_msg)
{
	uint16_t op = NOCSWITCH_OP_SENDDMA;
	m_socket.SendLooped((unsigned char*)&op, 2);

	uint32_t buf[515];
	tx_msg.Pack(buf);
	m_socket.SendLooped((unsigned char*)buf, 515*4);
}

bool NOCSwitchInterface::RecvDMAMessage(DMAMessage& rx_msg)
{
	uint16_t op = NOCSWITCH_OP_RECVDMA;
	
	m_socket.SendLooped((unsigned char*)&op, 2);
	uint8_t found = 0;
	m_socket.RecvLooped((unsigned char*)&found, 1);
	if(found)
	{		
		uint32_t buf[515];
		m_socket.RecvLooped((unsigned char*)buf, 515*4);
		rx_msg.Unpack(buf);
		return true;
	}	
	return false;
}

bool NOCSwitchInterface::SendDMAMessageNonblocking(const DMAMessage& tx_msg)
{
	//TCP buffer ensures this send is nonblocking, no buffering on our part required
	SendDMAMessage(tx_msg);
	return true;
}

/**
	@brief Gets the address nocswitch assigned to us
 */
uint16_t NOCSwitchInterface::GetClientAddress()
{
	uint16_t op = NOCSWITCH_OP_GET_ADDR;
	m_socket.SendLooped((unsigned char*)&op, 2);
	
	uint16_t addr;
	m_socket.RecvLooped((unsigned char*)&addr, 2);
	return addr;
}
