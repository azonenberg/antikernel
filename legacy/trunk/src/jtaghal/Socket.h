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
	@file Socket.h
	@brief Declaration of Socket class
 */
#ifndef Socket_h
#define Socket_h

#include "config.h"

#include <string>

//Pull in some OS specific stuff
#ifdef _WINDOWS

#include <ws2tcpip.h>
#define ZSOCKLEN int
#define ZSOCKET SOCKET

#else

#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#define ZSOCKLEN socklen_t
#define ZSOCKET int

#endif

/**
	@brief Class representing a network socket.
	
	Address resolution IPv4 only for now but can easily be updated for v6
 */
class Socket
{
public:
	Socket(int af,int type,int protocol);

	//Create a Socket object from an existing socket
	Socket(ZSOCKET sock, int af=PF_INET);

	//Destructor
	~Socket(void);

	//Connect to a host (automatic DNS resolution)
	void Connect(const std::string& host, uint16_t port);

	//Bind to a port (any available interface)
	void Bind(unsigned short port);

	//Put us in listening mode
	void Listen();

	//Accept a new connection
	Socket Accept(sockaddr_in* addr,ZSOCKLEN len);
	Socket Accept(sockaddr_in6* addr,ZSOCKLEN len);
	Socket Accept();

	//Disconnect us from the socket object
	ZSOCKET Detach();

	//Send / receive rawdata
	void SendLooped(const unsigned char* buf, int count);
	void RecvLooped(unsigned char* buf, int len);
	//size_t RecvFrom(void* buf, size_t len, sockaddr_in& addr, int flags = 0);
	//size_t SendTo(void* buf, size_t len, sockaddr_in& addr, int flags = 0);
	
	//Send/receive a string
	void RecvPascalString(std::string& str);

	/**
		@brief Convert us to the native OS socket type
		@return A reference to our socket handle
	 */
	operator ZSOCKET&()
	{ return m_socket; }
	
	bool IsValid() const
	{
		#ifdef _WINDOWS
			return (m_socket != INVALID_SOCKET);
		#else
			return (m_socket >= 0);
		#endif
	}

protected:
	void Close();
	void Open();

	/**
		@brief Address family of this socket (typically AF_INET or AF_INET6)
	 */
	int m_af;
	
	///Type of the socket
	int m_type;
	
	///Protocol of the socket
	int m_protocol;
	
	/**
		@brief The socket handle
	 */
	ZSOCKET m_socket;
};

#endif
