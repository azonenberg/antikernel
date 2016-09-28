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
	@file Socket.cpp
	@brief Implementation of Socket class
 */

#include "jtaghal.h"
#include <memory.h>

using namespace std;

/**
	@brief Creates a socket
	
	@param af Address family of the socket (layer 3 protocol selection)
	@param type Type of the socket (stream or datagram)
	@param protocol Protocol of the socket (layer 4 protocol selection)
 */
Socket::Socket(int af, int type, int protocol)
: m_af(af)
, m_type(type)
, m_protocol(protocol)
{
#ifdef _WINDOWS
	WSADATA wdat;
	if(0 != WSAStartup(MAKEWORD(2,2),&wdat))
	{
		throw JtagExceptionWrapper(
			"WSAStartup failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
#endif
	
	Open();
}

void Socket::Open()
{
	//For once - a nice, portable call, no #ifdefs required.
	m_socket = socket(m_af, m_type, m_protocol);

	//Too bad error checking isn't portable!
#ifdef _WINDOWS
	if(INVALID_SOCKET == m_socket)
	{
		throw JtagExceptionWrapper(
			"Socket creation failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
#else
	if(-1 == m_socket)
	{
		throw JtagExceptionWrapper(
			"Socket creation failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
#endif
}

/**
	@brief Wraps an existing socket
	
	@param sock Socket to encapsulate
	@param af Address family of the provided socket
 */
Socket::Socket(ZSOCKET sock, int af)
: m_af(af)
, m_socket(sock)
{
	//TODO: get actual values?
	m_type = SOCK_STREAM;
	m_protocol = IPPROTO_TCP;
	
#ifdef _WINDOWS
	WSADATA wdat;
	if(0 != WSAStartup(MAKEWORD(2,2),&wdat))
	{
		throw JtagExceptionWrapper(
			"WSAStartup failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
#endif
}

/**
	@brief Closes a socket
 */
Socket::~Socket(void)
{
	Close();
	
#ifdef _WINDOWS
	WSACleanup();
#endif
}

void Socket::Close()
{
	//There are a couple of different ways to close a socket...
	#ifdef _WINDOWS
	if(m_socket != INVALID_SOCKET)
	{
		closesocket(m_socket);
		m_socket = INVALID_SOCKET;
	}
	#else
	if(m_socket >= 0)
	{
		close(m_socket);
		m_socket = -1;
	}
	#endif
}

/**
	@brief Establishes a TCP connection to a remote host
	
	@param host DNS name or string IP address of remote host
	@param port Port to connect to (host byte order)
 */
void Socket::Connect(const std::string& host, uint16_t port)
{
	addrinfo hints;
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;		//allow both v4 and v6
	hints.ai_socktype = m_type;
	
#ifndef _WINDOWS
	hints.ai_flags = AI_NUMERICSERV;	//numeric port number, implied on windows
#endif
	
	//Make ASCII port number
	char sport[6];
	snprintf(sport, sizeof(sport), "%5d", port);
	
#ifdef _WINDOWS
	//Do a DNS lookup
	ADDRINFO* address=NULL;
#else
	addrinfo* address = NULL;
#endif

	if(0 != (getaddrinfo(host.c_str(), sport, &hints, &address)))
	{
		throw JtagExceptionWrapper(
			"DNS lookup failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	if(address==NULL)
	{
		throw JtagExceptionWrapper(
			"DNS lookup failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	
	//Try actually connecting
	bool connected = false;
	for(addrinfo* p = address; p != NULL; p=p->ai_next)
	{
		m_af = p->ai_family;
		m_protocol = p->ai_protocol;
		Close();
		Open();
	
		//Connect to the socket
		if(0 == connect(m_socket, p->ai_addr, p->ai_addrlen))
		{
			connected = true;
			break;
		}
	}

	//Connect to the socket
	if(!connected)
	{
		//Close the socket so destructor code won't try to send stuff to us
		Close();
		
		throw JtagExceptionWrapper(
			"Failed to connect to server",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	
	freeaddrinfo(address);
}

/**
	@brief Sends data over the socket
	
	@param buf Buffer to send
	@param count Length of data buffer
 */
void Socket::SendLooped(const unsigned char* buf, int count)
{
	const unsigned char* p = buf;
	int bytes_left = count;
	int x = 0;
	while( (x = send(m_socket, (const char*)p, bytes_left, 0)) > 0)
	{
		bytes_left -= x;
		p += x;
		if(bytes_left == 0)
			break;
	}
	
	if(x < 0)
	{
		throw JtagExceptionWrapper(
			"Write failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	else if(x == 0)
	{
		throw JtagExceptionWrapper(
			"Socket closed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
}

/**
	@brief Recives data from a UDP socket
	
	@param buf Output buffer
	@param len Length of the buffer
	@param addr IP address of the sender
	@param flags Socket flags
	
	@return Number of bytes read
 */
/*
size_t Socket::RecvFrom(void* buf, size_t len, sockaddr_in& addr,  int flags)
{
	socklen_t slen = sizeof(addr);
	return recvfrom(m_socket, buf, len, flags, reinterpret_cast<sockaddr*>(&addr), &slen);
}
*/

/**
	@brief Sends data to a UDP socket
	
	@param buf Input buffer
	@param len Length of the buffer
	@param addr IP address of the recipient
	@param flags Socket flags
	
	@return Number of bytes sent
 */
/*
size_t Socket::SendTo(void* buf, size_t len, sockaddr_in& addr,  int flags)
{
	size_t ret = sendto(m_socket, buf, len, flags, reinterpret_cast<sockaddr*>(&addr), sizeof(addr));
	if(ret != len)
	{
		throw JtagExceptionWrapper(
			"Socket sendto failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	return ret;
}
*/

/**
	@brief Recieves data from the socket
	
	@param buf The buffer to read into
	@param len Length of read buffer
 */
void Socket::RecvLooped(unsigned char* buf, int len)
{
	unsigned char* p = buf;
	int bytes_left = len;
	int x = 0;
	while( (x = recv(m_socket, (char*)p, bytes_left, 0)) > 0)
	{
		bytes_left -= x;
		p += x;
		if(bytes_left == 0)
			break;
	}
	
	if(x < 0)
	{
		throw JtagExceptionWrapper(
			"Read failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	else if(x == 0)
	{
		throw JtagExceptionWrapper(
			"Socket closed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
}

/**
	@brief Binds the socket to an address
	
	@param port Port to listen on
 */
void Socket::Bind(unsigned short port)
{
	sockaddr* addr;
	socklen_t len;
	
	if(m_af == AF_INET)
	{
		sockaddr_in name;
		memset(&name,0,sizeof(name));
		
		//Set port number
		name.sin_family=m_af;
		name.sin_port=htons(port);
		addr = reinterpret_cast<sockaddr*>(&name);
		len = sizeof(name);
	}
	else
	{
		sockaddr_in6 name;
		memset(&name,0,sizeof(name));
		
		//Set port number
		name.sin6_family=m_af;
		name.sin6_port=htons(port);
		addr = reinterpret_cast<sockaddr*>(&name);
		len = sizeof(name);
	}

	//Try binding the socket
	if(0 != bind (m_socket, addr, len) )
	{
		throw JtagExceptionWrapper(
			"Socket bind failed",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
}

/**
	@brief Puts the socket in listening mode
 */
void Socket::Listen()
{
	listen(m_socket,SOMAXCONN);
}

/**
	@brief Accepts an IPv4 connection on the socket
	
	@brief addr Output address of accepted connection
	@brief len Size of the output buffer
	
	@return Socket for the client connection
 */
Socket Socket::Accept(sockaddr_in* addr,ZSOCKLEN len)
{
	ZSOCKET sock = accept(m_socket,reinterpret_cast<sockaddr*>(addr),&len);

	//Error check
#ifdef _WINDOWS
	if(sock==INVALID_SOCKET)
#else
	if(sock<0)
#endif
	{
		throw JtagExceptionWrapper(
			"Failed to accept socket connection (make sure socket is in listening mode)",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}

	return Socket(sock,m_af);
}

/**
	@brief Accepts a connection on the socket
	
	@brief addr Output address of accepted connection
	@brief len Size of the output buffer
	
	@return Socket for the client connection
 */
Socket Socket::Accept()
{
	sockaddr_storage addr;
	socklen_t len = sizeof(addr);
	ZSOCKET sock = accept(m_socket, reinterpret_cast<sockaddr*>(&addr), &len);

	//Error check
#ifdef _WINDOWS
	if(sock==INVALID_SOCKET)
#else
	if(sock < 0)
#endif
	{
		throw JtagExceptionWrapper(
			"Failed to accept socket connection (make sure socket is in listening mode)",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}

	return Socket(sock,m_af);
}

/**
	@brief Accepts a IPv6 connection on the socket
	
	@brief addr Output address of accepted connection
	@brief len Size of the output buffer
	
	@return Socket for the client connection
 */
Socket Socket::Accept(sockaddr_in6* addr,ZSOCKLEN len)
{
	ZSOCKET sock = accept(m_socket,reinterpret_cast<sockaddr*>(addr),&len);

	//Error check
#ifdef _WINDOWS
	if(sock==INVALID_SOCKET)
#else
	if(sock < 0)
#endif
	{
		throw JtagExceptionWrapper(
			"Failed to accept socket connection (make sure socket is in listening mode)",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}

	return Socket(sock,m_af);
}

/**
	@brief Detaches the socket from this object
	
	@return Socket handle. The caller is responsible for closing the handle.
 */
ZSOCKET Socket::Detach()
{
	ZSOCKET s = m_socket;
#ifdef _WINDOWS
	m_socket = INVALID_SOCKET;
#else
	m_socket = -1;
#endif
	return s;
}

/**
	@brief Reads a Pascal-style string from a socket
 */
void Socket::RecvPascalString(string& str)
{
	uint16_t len;
	RecvLooped((unsigned char*)&len, 2);
	int32_t tlen = len + 1;		//use larger int to avoid risk of overflow if str len == 65535
	char* rbuf = new char[tlen];
	RecvLooped((unsigned char*)rbuf, len);
	rbuf[len] = 0;				//recv string is not null terminated
	str = rbuf;
	delete[] rbuf;
}
