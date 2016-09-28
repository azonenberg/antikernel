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
	@brief Implementation of NetworkedJtagInterface
 */
#include "jtaghal.h"
#include <jtagd_opcodes_constants.h>

#ifndef _WINDOWS
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif

#include <memory.h>
#include <stdlib.h>

using namespace std;

/**
	@brief Creates the interface object but does not connect to a server.
 */
NetworkedJtagInterface::NetworkedJtagInterface()
	: m_socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP)
{
}

/**
	@brief Connects to a jtagd server.
	
	@throw JtagException if the connection could not be established
	
	@param server	Hostname of the server to connect to
	@param port		Port number (in host byte ordering) the server is running on
 */
void NetworkedJtagInterface::Connect(const std::string& server, uint16_t port)
{
	//Connect to the port
	m_socket.Connect(server, port);
		
	//Set no-delay flag
	int flag = 1;
	if(0 != setsockopt((int)m_socket, IPPROTO_TCP, TCP_NODELAY, (char *)&flag, sizeof(flag) ))
	{
		throw JtagExceptionWrapper(
			"Failed to set TCP_NODELAY",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
	
	//All good, query the GPIO stats
	if(IsGPIOCapable())
	{
		uint8_t op = JTAGD_OP_GET_GPIO_PIN_COUNT;
		m_socket.SendLooped((unsigned char*)&op, 1);
		uint8_t pincount;
		m_socket.RecvLooped(&pincount, 1);
		
		for(int i=0; i<pincount; i++)
		{
			m_gpioValue.push_back(false);
			m_gpioDirection.push_back(false);
		}
		
		//Load the GPIO pin state from the server
		ReadGpioState();
	}
}

/**
	@brief Disconnects from the server
 */
NetworkedJtagInterface::~NetworkedJtagInterface()
{
	try
	{
		if(m_socket.IsValid())
		{
			uint8_t op = JTAGD_OP_QUIT;
			m_socket.SendLooped((unsigned char*)&op, 1);
		}
	}
	catch(const JtagInterface& ex)
	{
		//Ignore errors in the write_looped call since we're disconnecting anyway
	}
}

/**
	@brief Returns the protocol version
 */
std::string NetworkedJtagInterface::GetAPIVersion()
{
	return "1.0";
}

/**
	@brief Returns the constant 1.
 */
int NetworkedJtagInterface::GetInterfaceCount()
{
	return 1;
}

std::string NetworkedJtagInterface::GetName()
{
	uint8_t op = JTAGD_OP_GET_NAME;
	m_socket.SendLooped((unsigned char*)&op, 1);
	string str;
	m_socket.RecvPascalString(str);
	return str;
}

std::string NetworkedJtagInterface::GetSerial()
{
	uint8_t op = JTAGD_OP_GET_SERIAL;
	m_socket.SendLooped((unsigned char*)&op, 1);
	string str;
	m_socket.RecvPascalString(str);
	return str;
}

std::string NetworkedJtagInterface::GetUserID()
{
	uint8_t op = JTAGD_OP_GET_USERID;
	m_socket.SendLooped((unsigned char*)&op, 1);
	string str;
	m_socket.RecvPascalString(str);
	return str;
}

int NetworkedJtagInterface::GetFrequency()
{
	uint8_t op = JTAGD_OP_GET_FREQ;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint32_t freq;
	m_socket.RecvLooped((unsigned char*)&freq, 4);
	return freq;
}

void NetworkedJtagInterface::ShiftData(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count)
{
	double start = GetTime();
	
	int bytesize =  ceil(count / 8.0f);
	
	//Send the opcode and data
	uint8_t op = JTAGD_OP_SHIFT_DATA;
	if(rcv_data == NULL)
		op = JTAGD_OP_SHIFT_DATA_WO;
	BufferedSend((unsigned char*)&op, 1);
	uint8_t t = last_tms;
	BufferedSend((unsigned char*)&t, 1);
	uint32_t c = count;
	BufferedSend((unsigned char*)&c, 4);
	BufferedSend(send_data, bytesize);
	SendFlush();
	
	//Read response data
	if(rcv_data != NULL)
		m_socket.RecvLooped(rcv_data, bytesize);
		
	m_perfShiftTime += GetTime() - start;
}

bool NetworkedJtagInterface::IsSplitScanSupported()
{
	uint8_t op = JTAGD_OP_SPLIT_SUPPORTED;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint8_t dout;
	m_socket.RecvLooped((unsigned char*)&dout, 1);
	return (dout != 0);
}

bool NetworkedJtagInterface::ShiftDataWriteOnly(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count)
{
	double start = GetTime();
	
	int bytesize =  ceil(count / 8.0f);
	
	//Send the opcode and data
	uint8_t op = JTAGD_OP_SHIFT_DATA_WRITE_ONLY;
	BufferedSend((unsigned char*)&op, 1);
	uint8_t t = last_tms;
	BufferedSend((unsigned char*)&t, 1);
	uint32_t c = count;
	BufferedSend((unsigned char*)&c, 4);
	uint8_t want_response = 0;
	if(rcv_data != NULL)
		want_response = 1;
	BufferedSend((unsigned char*)&want_response, 1);
	BufferedSend(send_data, bytesize);
	SendFlush();
	
	//Read status byte
	uint8_t status;
	m_socket.RecvLooped(&status, 1);
	
	//0 = OK, 1 = deferred, negative = failure
	switch(status)
	{
	case 0:
		//Read response data
		if(rcv_data != NULL)
			m_socket.RecvLooped(rcv_data, bytesize);
		m_perfShiftTime += GetTime() - start;
		return false;
		
	case 1:
		//Read was deferred
		m_perfShiftTime += GetTime() - start;
		return true;
		
	default:
		throw JtagExceptionWrapper(
			"ShiftDataWriteOnly() failed server-side",
			"",
			JtagException::EXCEPTION_TYPE_ADAPTER);
		break;
	}
}

bool NetworkedJtagInterface::ShiftDataReadOnly(unsigned char* rcv_data, int count)
{
	if(rcv_data == NULL)
		return true;
	
	double start = GetTime();
	int bytesize =  ceil(count / 8.0f);
	
	//Send the opcode and length
	uint8_t op = JTAGD_OP_SHIFT_DATA_READ_ONLY;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint32_t c = count;
	m_socket.SendLooped((unsigned char*)&c, 4);
	
	//Read back
	uint8_t status;
	m_socket.RecvLooped(&status, 1);
	
	//0 = already done, 1 = deferred, negative = failure
	switch(status)
	{
	case 0:
		//read is done already
		return true;
		
	case 1:
		//Read was deferred so read it now
		if(rcv_data != NULL)
			m_socket.RecvLooped(rcv_data, bytesize);
		m_perfShiftTime += GetTime() - start;
		return false;
		
	default:
		throw JtagExceptionWrapper(
			"ShiftDataWriteOnly() failed server-side",
			"",
			JtagException::EXCEPTION_TYPE_ADAPTER);
		break;
	}
}

void NetworkedJtagInterface::ShiftTMS(bool /*tdi*/, const unsigned char* /*send_data*/, int /*count*/)
{
	throw JtagExceptionWrapper(
		"NetworkedJtagInterface::ShiftTMS() is not allowed (use state-level interface)",
		"",
		JtagException::EXCEPTION_TYPE_ADAPTER);
}

void NetworkedJtagInterface::SendDummyClocks(int n)
{
	double start = GetTime();
	
	uint8_t op = JTAGD_OP_DUMMY_CLOCK;
	BufferedSend((unsigned char*)&op, 1);
	uint32_t c = n;
	BufferedSend((unsigned char*)&c, 4);
	Commit();
	
	m_perfShiftTime += GetTime() - start;
}

void NetworkedJtagInterface::SendDummyClocksDeferred(int n)
{
	double start = GetTime();
	
	uint8_t op = JTAGD_OP_DUMMY_CLOCK_DEFERRED;
	BufferedSend((unsigned char*)&op, 1);
	uint32_t c = n;
	BufferedSend((unsigned char*)&c, 4);
	
	m_perfShiftTime += GetTime() - start;
}

void NetworkedJtagInterface::TestLogicReset()
{
	uint8_t op = JTAGD_OP_TLR;
	BufferedSend((unsigned char*)&op, 1);
}

void NetworkedJtagInterface::EnterShiftIR()
{
	uint8_t op = JTAGD_OP_ENTER_SIR;
	BufferedSend((unsigned char*)&op, 1);
}

void NetworkedJtagInterface::LeaveExit1IR()
{
	uint8_t op = JTAGD_OP_LEAVE_E1IR;
	BufferedSend((unsigned char*)&op, 1);
}

void NetworkedJtagInterface::EnterShiftDR()
{
	uint8_t op = JTAGD_OP_ENTER_SDR;
	BufferedSend((unsigned char*)&op, 1);
}

void NetworkedJtagInterface::LeaveExit1DR()
{
	uint8_t op = JTAGD_OP_LEAVE_E1DR;
	BufferedSend((unsigned char*)&op, 1);
}

void NetworkedJtagInterface::ResetToIdle()
{
	uint8_t op = JTAGD_OP_RESET_IDLE;
	BufferedSend((unsigned char*)&op, 1);
}

void NetworkedJtagInterface::Commit()
{
	uint8_t op = JTAGD_OP_COMMIT;
	BufferedSend((unsigned char*)&op, 1);
	SendFlush();
	
	//Wait for an ACK packet (single 0x00) to come back
	uint8_t dummy;
	m_socket.RecvLooped(&dummy, 1);
}

void NetworkedJtagInterface::SendFlush()
{
	//Send and clear the buffer
	m_socket.SendLooped(&m_sendbuf[0], m_sendbuf.size());
	m_sendbuf.clear();
}

/**
	@brief Sends a string to a socket
	
	@throw JtagException if the string is >65535 bytes or the socket operation fails
	
	@param fd		Socket handle
	@param str		String to send
 */
void NetworkedJtagInterface::SendString(int fd, std::string str)
{
	if(str.length() > 65535)
	{
		throw JtagExceptionWrapper(
			"SendString() requires input <64KB",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
		
	uint16_t len = str.length();
	write_looped(fd, (unsigned char*)&len, 2);
	write_looped(fd, (unsigned char*)str.c_str(), len);
}

/**
	@brief Reads a string from a socket
	
	@throw JtagException if the socket operation fails
	
	@param fd		Socket handle
	@param str		String to store the result into
 */
void NetworkedJtagInterface::RecvString(int fd, std::string& str)
{
	uint16_t len;
	read_looped(fd, (unsigned char*)&len, 2);
	int32_t tlen = len + 1;		//use larger int to avoid risk of overflow if str len == 65535
	char* rbuf = new char[tlen];
	read_looped(fd, (unsigned char*)rbuf, len);
	rbuf[len] = 0;				//recv string is not null terminated
	str = rbuf;
	delete[] rbuf;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Handy wrappers

/**
	@brief Reads exactly the requested number of bytes from a socket, issuing multiple reads if necessary
	
	@throw JtagException if the socket operation fails
	
	@param fd		Socket handle
	@param buf		Buffer to store the data into
	@param count	Number of bytes to read
 */
int NetworkedJtagInterface::read_looped(int fd, unsigned char* buf, int count)
{
	unsigned char* p = buf;
	int bytes_left = count;
	int x = 0;
	while( (x = read(fd, p, bytes_left)) > 0)
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
	else
		return count;
}

/**
	@brief Writes exactly the requested number of bytes to a socket, issuing multiple writes if necessary
	
	@throw JtagException if the socket operation fails
	
	@param fd		Socket handle
	@param buf		Buffer to send
	@param count	Number of bytes to send
 */
int NetworkedJtagInterface::write_looped(int fd, const unsigned char* buf, int count)
{
	const unsigned char* p = buf;
	int bytes_left = count;
	int x = 0;
	while( (x = write(fd, p, bytes_left)) > 0)
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
	else
		return count;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Performance profiling

size_t NetworkedJtagInterface::GetShiftOpCount()
{
	uint8_t op = JTAGD_OP_PERF_SHIFT;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint64_t dout;
	m_socket.RecvLooped((unsigned char*)&dout, 8);
	return dout;
}

size_t NetworkedJtagInterface::GetRecoverableErrorCount()
{
	uint8_t op = JTAGD_OP_PERF_RECOV;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint64_t dout;
	m_socket.RecvLooped((unsigned char*)&dout, 8);
	return dout;
}

size_t NetworkedJtagInterface::GetDataBitCount()
{
	uint8_t op = JTAGD_OP_PERF_DATA;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint64_t dout;
	m_socket.RecvLooped((unsigned char*)&dout, 8);
	return dout;
}

size_t NetworkedJtagInterface::GetModeBitCount()
{
	uint8_t op = JTAGD_OP_PERF_MODE;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint64_t dout;
	m_socket.RecvLooped((unsigned char*)&dout, 8);
	return dout;
}

size_t NetworkedJtagInterface::GetDummyClockCount()
{
	uint8_t op = JTAGD_OP_PERF_DUMMY;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint64_t dout;
	m_socket.RecvLooped((unsigned char*)&dout, 8);
	return dout;
}

//GetShiftTime is measured clientside so no need to override

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// GPIO stuff

bool NetworkedJtagInterface::IsGPIOCapable()
{
	uint8_t op = JTAGD_OP_HAS_GPIO;
	m_socket.SendLooped((unsigned char*)&op, 1);
	uint8_t dout;
	m_socket.RecvLooped((unsigned char*)&dout, 1);
	return (dout != 0);
}

void NetworkedJtagInterface::ReadGpioState()
{
	uint8_t op = JTAGD_OP_READ_GPIO_STATE;
	m_socket.SendLooped((unsigned char*)&op, 1);
	
	int count = m_gpioDirection.size();
	uint8_t* buf = new uint8_t[count];
	m_socket.RecvLooped(buf, count);
	for(int i=0; i<count; i++)
	{
		uint8_t val = buf[i];
		m_gpioValue[i] = (val & 1) ? true : false;
		m_gpioDirection[i] = (val & 2) ? true : false;
	}
	delete[] buf;
}

void NetworkedJtagInterface::WriteGpioState()
{
	uint8_t op = JTAGD_OP_WRITE_GPIO_STATE;
	m_socket.SendLooped((unsigned char*)&op, 1);
	
	int count = m_gpioDirection.size();
	vector<uint8_t> pinstates;
	for(int i=0; i<count; i++)
	{
		pinstates.push_back(
			m_gpioValue[i] |
			(m_gpioDirection[i] << 1)
			);
	}
	m_socket.SendLooped((unsigned char*)&pinstates[0], count);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// I/O buffering

void NetworkedJtagInterface::BufferedSend(const unsigned char* buf, int count)
{
	for(int i=0; i<count; i++)
		m_sendbuf.push_back(buf[i]);
}
