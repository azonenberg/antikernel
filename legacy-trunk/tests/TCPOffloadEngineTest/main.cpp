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
	@brief TCPOffloadEngine test
	
	Performs various test operations on the TCP offload engine.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"

#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>

#include <IPv6OffloadEngine_opcodes_constants.h>
#include <NOCSysinfo_constants.h>
#include <Ethertypes_constants.h>
#include <IPProtocols_constants.h>
#include <ICMPv6_types_constants.h>
#include <ICMPv6_NDP_options_constants.h>
#include <TCPOffloadEngine_opcodes_constants.h>

#include <signal.h>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>

using namespace std;

int MainTestRoutine(NOCSwitchInterface& iface, uint16_t taddr, string dns, unsigned short nport);
int NewSocketTestRoutine(NOCSwitchInterface& iface, uint16_t taddr, string dns, unsigned short nport);
void WaitForConnectedInterrupt(NOCSwitchInterface& iface, uint16_t taddr, unsigned short nport);
void DisableNagle(Socket& csock);
void WaitForClosedInterrupt(NOCSwitchInterface& iface, uint16_t taddr, unsigned short nport);

void RecvPacketTest(
	NOCSwitchInterface& iface,
	Socket& csock,
	uint16_t taddr,
	uint16_t nport,
	const char* data);
void SendPacketTest(
	NOCSwitchInterface& iface,
	Socket& csock,
	uint16_t taddr,
	uint16_t nport,
	uint32_t* data,
	int wordlen,
	int bytelen);

int main(int argc, char* argv[])
{
	int err_code = 0;
	try
	{
		//Connect to the server
		string server;
		int port = 0;
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);
			
			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
			else if(s == "--tty")
				++i;
			else
			{
				printf("Unrecognized command-line argument \"%s\", expected --server or --port\n", s.c_str());
				return 1;
			}
		}
		if( (server == "") || (port == 0) )
		{
			throw JtagExceptionWrapper(
				"No server or port name specified",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}		
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		//Needs to be deterministic for testing
		srand(0);
			
		//Figure out the MAC address
		RPCMessage rxm;
		NameServer nameserver(&iface);
		printf("Looking up address of sysinfo...\n");
		uint16_t saddr = nameserver.ForwardLookup("sysinfo");
		printf("sysinfo is at %04x\n", saddr);
		iface.RPCFunctionCall(saddr, SYSINFO_CHIP_SERIAL, 0, 0, 0, rxm);
		unsigned short mac[3]=
		{
			static_cast<unsigned short>((0x02 << 8) | (rxm.data[2] & 0xff)),
			static_cast<unsigned short>(rxm.data[1] >> 16),
			static_cast<unsigned short>(rxm.data[1] & 0xffff),
		};
		printf("MAC address is %02x:%02x:%02x:%02x:%02x:%02x...\n",
			mac[0] >> 8, mac[0] & 0xff,
			mac[1] >> 8, mac[1] & 0xff,
			mac[2] >> 8, mac[2] & 0xff);
		printf("Looking up address of ipv6...\n");
		uint16_t iaddr = nameserver.ForwardLookup("ipv6");
		printf("ipv6 is at %04x\n", iaddr);
		iface.RPCFunctionCall(
			iaddr,
			IPV6_OP_SET_MAC,
			mac[0],
			(mac[1] << 16) | mac[2],
			0,
			rxm);
			
		//Register us with the name server
		NameServer nsvr(&iface, "ThisIsALongAndComplicatedPassword");
		nsvr.Register("testcase");
		
		//Wait ten seconds (we should have received a SLAAC packet by now)
		printf("Waiting for SLAAC...\n");
		usleep(10 * 1000 * 1000);
		
		//Sanity check subnet prefix
		iface.RPCFunctionCall(iaddr, IPV6_OP_GET_SUBNET, 0, 0, 0, rxm);
		printf("    Subnet prefix is %x:%x:%x:%x::/%d\n",
			rxm.data[1] >> 16,
			rxm.data[1] & 0xffff,
			rxm.data[2] >> 16,
			rxm.data[2] & 0xffff,
			rxm.data[0] & 0xff);
			
		//Look up our hostname
		char* nodename = getenv("SLURM_NODELIST");
		string dns = string(nodename) + ".sandbox.bainbridge.antikernel.net";
		
		//Get socket info
		printf("Looking up address of tcp...\n");
		uint16_t taddr = nameserver.ForwardLookup("tcp");
		printf("tcp is at %04x\n", taddr);
		iface.RPCFunctionCall(taddr, TCP_OP_GET_PORTRANGE, 0, 0, 0, rxm);
		printf("TCP offload engine supports %d ports starting at %d\n", rxm.data[0] & 0xffff, rxm.data[1] & 0xffff);
		
		unsigned short nport = 50100;
		
		//Try to close the socket again (should fail)
		try
		{
			printf("Trying to close not-yet-opened socket (should fail)\n");
			iface.RPCFunctionCall(taddr, TCP_OP_CLOSE_SOCKET, nport, 0, 0, rxm);
			
			printf("    Expected call to fail, but it didn't");
			return -1;
		}
		catch(const JtagException& ex)
		{
			printf("    Got expected exception, continuing\n");
		}
		
		//Try to open the socket
		printf("Binding socket...\n");
		iface.RPCFunctionCall(taddr, TCP_OP_OPEN_SOCKET, nport, 0, 0, rxm);
		/*
		//Need a separate scope here so that socket can be closed before the test ends
		//Make this another function to keep the code clean
		if(0 != MainTestRoutine(iface, taddr, dns, nport))
			return -1;
			
		//Expect a "closed" interrupt
		WaitForClosedInterrupt(iface, taddr, nport);
		*/
			
		//Try to open the socket again (should fail)
		try
		{
			printf("Trying to bind already-bound socket (should fail)\n");
			iface.RPCFunctionCall(taddr, TCP_OP_OPEN_SOCKET, nport, 0, 0, rxm);
			
			printf("    Expected call to fail, but it didn't");
			return -1;
		}
		catch(const JtagException& ex)
		{
			printf("    Got expected exception, continuing\n");
		}
		
		//Make a second connection to the socket and verify all is well
		printf("Trying to connect again...\n");
		if(0 != NewSocketTestRoutine(iface, taddr, dns, nport))
			return -1;
		WaitForClosedInterrupt(iface, taddr, nport);
		
		//Done, clean up
		printf("Closing socket...\n");
		iface.RPCFunctionCall(taddr, TCP_OP_CLOSE_SOCKET, nport, 0, 0, rxm);
		
		//Try to connect to it after closing the socket (should fail)
		try
		{
			printf("Connecting to %s:%d (should fail, socket is closed)\n", dns.c_str(), (int)nport);
			Socket fsock(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
			fsock.Connect(dns, nport);
			
			printf("    Expected call to fail, but it didn't");
			return -1;
		}
		catch(const JtagException& ex)
		{
			printf("    Got expected exception, continuing\n");
		}
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}

void WaitForClosedInterrupt(NOCSwitchInterface& iface, uint16_t taddr, unsigned short nport)
{
	RPCMessage rxm;
	do
	{
		iface.RecvRPCMessageBlockingWithTimeout(rxm, 1);
	} while(rxm.from != taddr);
	if( (rxm.callnum != TCP_INT_CONN_CLOSED) || (rxm.data[0] != nport) )
	{
		throw JtagExceptionWrapper(
			"Expected TCP_INT_CONN_CLOSED and got something else",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
}

int NewSocketTestRoutine(NOCSwitchInterface& iface, uint16_t taddr, string dns, unsigned short nport)
{
	printf("--- reconnect to make sure socket is still alive ---\n");
	
	//Attempt to connect to it
	printf("Connecting to %s:%d\n", dns.c_str(), (int)nport);
	Socket csock(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
	csock.Connect(dns, nport);
	printf("    Connected\n");
	WaitForConnectedInterrupt(iface, taddr, nport);
	DisableNagle(csock);
	
	//Send some stuff
	printf("Sending test data...\n");
	unsigned char dummy[] = {"toenail fungus"};
	RecvPacketTest(iface, csock, taddr, nport, (const char*)dummy);	
	
	//TODO
	return 0;
}

void DisableNagle(Socket& csock)
{
	int flag = 1;
	if(0 != setsockopt(csock, IPPROTO_TCP, TCP_NODELAY, (char *)&flag, sizeof(flag) ))
	{
		throw JtagExceptionWrapper(
			"Failed to set TCP_NODELAY",
			"",
			JtagException::EXCEPTION_TYPE_NETWORK);
	}
}

void WaitForConnectedInterrupt(NOCSwitchInterface& iface, uint16_t taddr, unsigned short nport)
{
	RPCMessage rxm;
	do
	{
		iface.RecvRPCMessageBlockingWithTimeout(rxm, 1);
	} while(rxm.from != taddr);
	if( (rxm.callnum != TCP_INT_CONN_OPENED) || (rxm.data[0] != nport) )
	{
		throw JtagExceptionWrapper(
			"Expected TCP_INT_CONN_OPENED and got something else",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
}

int MainTestRoutine(NOCSwitchInterface& iface, uint16_t taddr, string dns, unsigned short nport)
{
	//Attempt to connect to it
	printf("Connecting to %s:%d\n", dns.c_str(), (int)nport);
	Socket csock(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
	csock.Connect(dns, nport);
	printf("    Connected\n");
	WaitForConnectedInterrupt(iface, taddr, nport);
	DisableNagle(csock);
	
	//Send some stuff
	printf("Sending test data...\n");
	unsigned char dummy[12] = {"hello world"};
	RecvPacketTest(iface, csock, taddr, nport, (const char*)dummy);	
	
	//Try sending some data
	uint32_t txbuf[512]=
	{
		htonl(9),				//message length in bytes
		htonl(0x68692074),		//"hi t"
		htonl(0x68657265),		//"here"
		htonl(0x21000000)		//"!"
	};
	SendPacketTest(iface, csock, taddr, nport, txbuf, 4, 9);
	
	//Send a DIFFERENT message
	unsigned char dummy2[5] = {"hai!"};
	RecvPacketTest(iface, csock, taddr, nport, (const char*)dummy2);
	
	//Send more data
	uint32_t txbuf2[512]=
	{
		htonl(9),				//message length in bytes
		htonl(0x666f6f62),		//"foob"
		htonl(0x61726261),		//"arba"
		htonl(0x7a000000)		//"z"
	};
	SendPacketTest(iface, csock, taddr, nport, txbuf2, 4, 9);
	
	//Try to connect again, while this socket is still open (should fail)
	try
	{
		printf("Connecting to %s:50100 (should fail, socket is already bound)\n", dns.c_str());
		Socket fsock(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
		fsock.Connect(dns, nport);
		
		printf("Expected call to fail, but it didn't");
		return -1;
	}
	catch(const JtagException& ex)
	{
		printf("    Got expected exception, continuing\n");
	}
	
	//Try to connect to an unbound port (should fail)
	try
	{
		printf("Connecting to %s:%d (should fail, socket isn't yet bound)\n", dns.c_str(), (int)(nport+1));
		Socket fsock(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
		fsock.Connect(dns, nport+1);
		
		printf("Expected call to fail, but it didn't");
		return -1;
	}
	catch(const JtagException& ex)
	{
		printf("    Got expected exception, continuing\n");
	}
	
	//good
	return 0;
}

void SendPacketTest(
	NOCSwitchInterface& iface,
	Socket& csock,
	uint16_t taddr,
	uint16_t nport,
	uint32_t* data,
	int wordlen,
	int bytelen)
{
	printf("Sending data...\n");
	iface.DMAWrite(taddr, nport << 16, wordlen, data, TCP_INT_SEND_DONE, TCP_INT_ACCESS_DENIED);
	
	//Read it from the socket
	char srbuf[2048] = {0};
	csock.RecvLooped(reinterpret_cast<unsigned char*>(srbuf), bytelen);
	
	//Verify the output is good
	printf("    Got: %s\n", srbuf);
	if(0 != strcmp(srbuf, reinterpret_cast<char*>(data+1)))
	{
		throw JtagExceptionWrapper(
			"Sent data bytes via TCP, but got bad data back",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
}

void RecvPacketTest(NOCSwitchInterface& iface, Socket& csock, uint16_t taddr, uint16_t nport, const char* data)
{
	//Send the data
	const unsigned int expected_len = strlen(data);
	csock.SendLooped((const unsigned char*)data, expected_len);
	
	//Expect an interrupt
	RPCMessage rxm;
	do
	{
		iface.RecvRPCMessageBlockingWithTimeout(rxm, 1);
	} while(rxm.from != taddr);
	printf("Got an interrupt\n");
	if(rxm.callnum != TCP_INT_NEW_DATA)
	{
		throw JtagExceptionWrapper(
			"Expected TCP_OP_NEWDATA and got something else",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	unsigned int iport = rxm.data[0];
	unsigned int len = rxm.data[1];
	printf("    New data ready on inbound port %u (%u bytes)\n", iport, len);
	bool fail = false;
	if((iport != nport) || (len != expected_len))
	{
		printf("    Bad DMA length or port number\n");
		fail = true;
	}
	
	//Calculate total length, in words, including byte length header
	int word_len = expected_len >> 2;
	if(expected_len & 3)
		word_len ++;
	word_len ++;

	//Now that we have the data ready to read, try actually reading it
	uint32_t rxbuf[512] = {0};
	printf("Trying to read new packet\n");
	iface.DMARead(taddr, nport << 16, word_len, rxbuf, TCP_INT_ACCESS_DENIED, 0.5);
	printf("    Got a DMA message\n");
	unsigned int nbytes = ntohl(rxbuf[0]);
	printf("        %u bytes actually read (requested %d)\n", nbytes, (word_len-1)*4);
	if(nbytes != expected_len)
	{
		printf("    Bad byte length\n");
		fail = true;
	}
	
	//Verify we have the right data
	char* rxbuf_ch = reinterpret_cast<char*>(rxbuf + 1);
	rxbuf_ch[expected_len] = 0;
	printf("    Got: %s\n", rxbuf_ch);
	if(0 != strcmp(rxbuf_ch, data))
	{
		throw JtagExceptionWrapper(
			"Got back bad data",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	
	if(fail)
	{
		throw JtagExceptionWrapper(
			"Got incorrect data",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
}
