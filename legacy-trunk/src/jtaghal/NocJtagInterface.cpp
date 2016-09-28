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
	@brief Implementation of NocJtagInterface
 */
#include "jtaghal.h"

#ifndef _WINDOWS
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif

#include <memory.h>
#include <stdlib.h>

#include <NetworkedJtagMaster_opcodes_constants.h>

using namespace std;

/**
	@brief Creates the interface object and connects to a server
 */
NocJtagInterface::NocJtagInterface(RPCAndDMANetworkInterface& iface, std::string host)
	: m_iface(iface)
	, m_name(host)
{
	NameServer svr(&iface);
	m_addr = svr.ForwardLookup(host);
	printf("Address of JTAG is %04x\n", m_addr);
}

/**
	@brief Disconnects from the adapter
 */
NocJtagInterface::~NocJtagInterface()
{
	
}

/**
	@brief Returns the protocol version
 */
std::string NocJtagInterface::GetAPIVersion()
{
	return "1.0";
}

/**
	@brief Returns the constant 1.
 */
int NocJtagInterface::GetInterfaceCount()
{
	return 1;
}

std::string NocJtagInterface::GetName()
{
	return m_name;
}

std::string NocJtagInterface::GetSerial()
{
	return "NoSerialNumber";
}

std::string NocJtagInterface::GetUserID()
{
	return m_name;
}

int NocJtagInterface::GetFrequency()
{
	//10 MHz hard coded for now
	return 10000000;
}

void NocJtagInterface::ShiftData(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count)
{
	double start = GetTime();
	
	//Format the DMA message headers
	DMAMessage dxm;
	dxm.from = 0;
	dxm.to = m_addr;
	dxm.address = 0;
	dxm.len = 1;
	
	int nbits = 0;
	
	//Make the main message
	for(int off=0; off<count; off += 32)
	{
		int base = off/8;
		int bits_left = count - off;
		
		if(bits_left >= 32)
			nbits += 32;
		else
			nbits += bits_left;
		
		//Load another word into the message
		//Need to flip bytes around to get proper ordering
		if(bits_left <= 8)
		{
			dxm.data[dxm.len ++] = htonl(
				send_data[base]);
		}
		else if(bits_left <= 16)
		{
			dxm.data[dxm.len ++] = htonl(
				(send_data[base+1] << 8) |
				 send_data[base]);
		}
		else if(bits_left <= 24)
		{
			dxm.data[dxm.len ++] = htonl(
				(send_data[base+2]   << 16) |
				(send_data[base+1] << 8) |
				 send_data[base]);
		}
		else
		{
			dxm.data[dxm.len ++] = htonl(
				(send_data[base+3] << 24) |
				(send_data[base+2] << 16) |
				(send_data[base+1] << 8) |
				send_data[base]);
		}
		
		//If the message is full, send it right now
		if(dxm.len == 512)
		{
			//Poke the first data word to the actual target data length in *bits*
			dxm.data[0] = htonl(nbits);
			
			//Set address to 0x800 if this is the last message block and we're toggling TMS
			if( (bits_left <= 32) && last_tms)
				dxm.address = 0x800;
			else
				dxm.address = 0;
				
			//Send it
			m_iface.SendDMAMessage(dxm);
			
			//Reset the message
			dxm.len = 1;
			nbits = 0;
		}
	}
	
	//Send whatever is left
	if(dxm.len > 1)
	{
		//Poke the first data word to the actual target data length in *bits*
		dxm.data[0] = htonl(nbits);
		
		//Set address to 0x800 if we're toggling TMS
		if(last_tms)
			dxm.address = 0x800;
		else
			dxm.address = 0;
			
		//Send it
		m_iface.SendDMAMessage(dxm);
	}
	
	//Receive the inbound messages
	for(int blockbase=0; blockbase<count; blockbase += 2048)
	{	
		//Receive the DMA message
		m_iface.RecvDMAMessageBlockingWithTimeout(dxm, 2);
		
		//If no data discard the message
		if(rcv_data == NULL)
			continue;
		
		//Process it
		for(int n=0; n<512; n++)
		{
			int off = blockbase + n*32;
			if(off > count)
				break;
				
			uint32_t raw = ntohl(dxm.data[n]);

			int bits_left = count - off;
			int base = off/8;

			if(bits_left <= 8)
				rcv_data[base]		= (raw		) & 0xff;
			else if(bits_left <= 16)
			{
				rcv_data[base+1]	= (raw >> 8 ) & 0xff;
				rcv_data[base]		= (raw		) & 0xff;
			}
			else if(bits_left <= 24)
			{
				rcv_data[base+2]	= (raw >> 16) & 0xff;
				rcv_data[base+1]	= (raw >> 8 ) & 0xff;
				rcv_data[base]		= (raw		) & 0xff;
			}
			else
			{
				rcv_data[base+3]	= (raw >> 24) & 0xff;
				rcv_data[base+2]	= (raw >> 16) & 0xff;
				rcv_data[base+1]	= (raw >> 8 ) & 0xff;
				rcv_data[base]		= (raw		) & 0xff;
			}

		}
	}

	m_perfShiftTime += GetTime() - start;
}

bool NocJtagInterface::IsSplitScanSupported()
{
	//TODO: Support split scans
	return false;
}

bool NocJtagInterface::ShiftDataWriteOnly(
	bool /*last_tms*/,
	const unsigned char* /*send_data*/,
	unsigned char* /*rcv_data*/,
	int /*count*/)
{
	throw JtagExceptionWrapper(
		"NocJtagInterface::ShiftDataWriteOnly() not implemented",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	
	/*
	double start = GetTime();
	
	int bytesize =  ceil(count / 8.0f);
	
	//Send the opcode and data
	uint16_t op = JTAGD_OP_SHIFT_DATA_WRITE_ONLY;
	BufferedSend((unsigned char*)&op, 2);
	uint8_t t = tms;
	BufferedSend((unsigned char*)&t, 1);
	t = last_tms;
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
	}*/
}

bool NocJtagInterface::ShiftDataReadOnly(unsigned char* /*rcv_data*/, int /*count*/)
{
	throw JtagExceptionWrapper(
		"NocJtagInterface::ShiftDataReadOnly() not implemented",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	
	/*
	if(rcv_data == NULL)
		return true;
	
	double start = GetTime();
	int bytesize =  ceil(count / 8.0f);
	
	//Send the opcode and length
	uint16_t op = JTAGD_OP_SHIFT_DATA_READ_ONLY;
	m_socket.SendLooped((unsigned char*)&op, 2);
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
	}*/
}

void NocJtagInterface::ShiftTMS(bool /*tdi*/, const unsigned char* /*send_data*/, int /*count*/)
{
	throw JtagExceptionWrapper(
		"NocJtagInterface::ShiftTMS() is not allowed (use state-level interface)",
		"",
		JtagException::EXCEPTION_TYPE_ADAPTER);
}

void NocJtagInterface::SendDummyClocks(int n)
{
	//Shift dummy data and ignore the response
	for(int i=0; i<n; i+=32)
	{
		int len = n - i;
		if(len > 32)
			len = 32;
		
		RPCMessage rxm;
		m_iface.RPCFunctionCall(
			m_addr,
			JTAG_OP_SHIFT_DATA,
			len,
			0,
			0,
			rxm);
	}
}

void NocJtagInterface::SendDummyClocksDeferred(int n)
{
	//don't wait for now
	SendDummyClocks(n);
}

void NocJtagInterface::TestLogicReset()
{
	//TODO: Don't wait for return value
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_addr, JTAG_OP_TEST_RESET, 0, 0, 0, rxm);
}

void NocJtagInterface::EnterShiftIR()
{
	//TODO: Don't wait for return value
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_addr, JTAG_OP_SELECT_IR, 0, 0, 0, rxm);
}

void NocJtagInterface::LeaveExit1IR()
{
	//TODO: Don't wait for return value
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_addr, JTAG_OP_LEAVE_IR, 0, 0, 0, rxm);
}

void NocJtagInterface::EnterShiftDR()
{
	//TODO: Don't wait for return value
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_addr, JTAG_OP_SELECT_DR, 0, 0, 0, rxm);
}

void NocJtagInterface::LeaveExit1DR()
{
	//TODO: Don't wait for return value
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_addr, JTAG_OP_LEAVE_DR, 0, 0, 0, rxm);
}

void NocJtagInterface::ResetToIdle()
{
	//TODO: Don't wait for return value
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_addr, JTAG_OP_RESET_IDLE, 0, 0, 0, rxm);
}

void NocJtagInterface::Commit()
{
	/*
	uint16_t op = JTAGD_OP_COMMIT;
	BufferedSend((unsigned char*)&op, 2);
	SendFlush();
	*/
	
	//no-op for now
}

void NocJtagInterface::SendFlush()
{
	/*
	//Send and clear the buffer
	m_socket.SendLooped(&m_sendbuf[0], m_sendbuf.size());
	m_sendbuf.clear();
	*/
	
	//no-op for now
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// GPIO stuff

bool NocJtagInterface::IsGPIOCapable()
{
	return false;
}

void NocJtagInterface::ReadGpioState()
{
	
}

void NocJtagInterface::WriteGpioState()
{

}
