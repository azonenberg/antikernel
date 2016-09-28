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
	@brief IPv6OffloadEngine test
	
	Performs various test operations on the IP offload engine.
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

#include <DMABridge_opcodes_constants.h>
#include <NetworkedDDR2Controller_opcodes_constants.h>

#include <signal.h>

#include <arpa/inet.h>

using namespace std;

unsigned short internet_checksum (int count, unsigned short * addr);

//Sample code from RFC1071
unsigned short internet_checksum (int count, unsigned short * addr)
{
    unsigned long sum = 0;

    while (count > 1)
    {
        sum += *addr++;
        count -= 2;
    }
    if (count > 0)
        sum += * (unsigned char *) addr;
    while (sum >> 16)
        sum = (sum & 0xffff) + (sum >> 16);
    return (unsigned short)sum;
}

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
		
		//Wait ten seconds (we should have received a SLAAC packet by now)
		printf("Waiting for SLAAC...\n");
		usleep(10 * 1000 * 1000);
		
		//Sanity check subnet prefix
		iface.RPCFunctionCall(iaddr, IPV6_OP_GET_SUBNET, 0, 0, 0, rxm);
		printf("Subnet prefix is %x:%x:%x:%x::/%d\n",
			rxm.data[1] >> 16,
			rxm.data[1] & 0xffff,
			rxm.data[2] >> 16,
			rxm.data[2] & 0xffff,
			rxm.data[0] & 0xff);
			
		//Should always be our lab subnet - 2001:470:ea80:6::/64
		//TODO: Figure out how to get this from the OS and not patch this test every time the LAN changes!!!
		if( (rxm.data[1] != 0x20010470) || (rxm.data[2] != 0xea800006) || (rxm.data[0] != 64) )
		{
			throw JtagExceptionWrapper(
				"Bad subnet prefix",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Sanity check router MAC address
		iface.RPCFunctionCall(iaddr, IPV6_OP_GET_GATEWAY, 0, 0, 0, rxm);
		printf("Default gateway MAC is %02x:%02x:%02x:%02x:%02x:%02x\n",
			rxm.data[0] >> 8,
			rxm.data[0] & 0xff,
			rxm.data[1] >> 24,
			(rxm.data[1] >> 16) & 0xff,
			(rxm.data[1] >> 8) & 0xff,
			rxm.data[1] & 0xff
			);
			
		//Should always be our default router - Ariia, e0:cb:4e:60:03:6f
		if( (rxm.data[0] != 0xe0cb) || (rxm.data[1] != 0x4e60036f) )
		{
			throw JtagExceptionWrapper(
				"Bad MAC address",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Compute expected SLAAC IPv6 address
		uint16_t expected_ip[] = 
		{
			0x2001,
			0x0470,
			0xea80,
			0x0006,
			mac[0],
			static_cast<uint16_t>((mac[1] & 0xff00) | 0x00ff),
			static_cast<uint16_t>(0xfe00 | (mac[1] & 0xff)),
			mac[2]
		};
		char expected_ip_str[128];
		snprintf(expected_ip_str, sizeof(expected_ip_str), "%x:%x:%x:%x:%x:%x:%x:%x",
			expected_ip[0], expected_ip[1], expected_ip[2], expected_ip[3],
			expected_ip[4], expected_ip[5], expected_ip[6], expected_ip[7]);
		printf("Expected global IPv6 unicast address: %s\n", expected_ip_str);
			
		//Send a ping to this address. Sweep sizes across the legal range (24 to 1438 bytes)
		printf("Sending ping sweep from 24 - 1438 payload bytes\n");
		char cmd[128];
		bool fail = false;
		for(int nsize=24; nsize<=1438; nsize++)
		{
			snprintf(cmd, sizeof(cmd), "fping6 -c 4 -t 50 -i 20 -p 20 -q -b %d %s > /dev/null 2> /dev/null", nsize, expected_ip_str);
			fflush(stdout);
			if(system(cmd) != 0)
			{
				fail = true;
				printf("Ping of %d bytes failed\n", nsize);
			}
		}
		if(fail)
		{
			throw JtagExceptionWrapper(
				"No ping received",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		
		//Register ourself as the destination for UDP packets coming from the DMA bridge
		printf("Looking up address of bridge\n");
		uint16_t baddr = nameserver.ForwardLookup("bridge");
		printf("Bridge is at %04x\n", baddr);
		iface.RPCFunctionCall(baddr, BRIDGE_REGISTER_TARGET, 0, 0, 0, rxm);
		
		//Send a UDP packet to the target (replicate to reduce risk of packet drops)
		printf("Sending UDP pings...\n");
		snprintf(cmd, sizeof(cmd), "socat -t 0 - udp-sendto:[%s]:9999", expected_ip_str);
		for(int i=0; i<5; i++)
		{
			FILE* fp = popen(cmd, "w");
			if(!fp)
			{
				throw JtagExceptionWrapper(
					"Failed to spawn socat",
					"",
					JtagException::EXCEPTION_TYPE_NETWORK);
			}
			fprintf(fp, "asdf");
			pclose(fp);
		}
		
		//Listen for a result (hope there's at least one)
		if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 5))
		{
			throw JtagExceptionWrapper(
				"No data received (timeout)",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		if( (rxm.from != baddr) || (rxm.type != RPC_TYPE_INTERRUPT) || (rxm.callnum != BRIDGE_PAGE_READY) )
		{
			printf("Got: %s\n", rxm.Format().c_str());
			throw JtagExceptionWrapper(
				"Bad message",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Dump info
		printf("Got a new page\n");
		uint16_t addr = rxm.data[0];
		uint32_t paddr = rxm.data[1];
		printf("    Physical address: %s:%08x\n", nameserver.ReverseLookup(addr).c_str(), paddr);
		unsigned int len = rxm.data[2] & 0x1FF;
		printf("    Length:           %u\n", len);
		uint16_t faddr = rxm.data[2] >> 16;
		printf("    Originally from:  %s\n", nameserver.ReverseLookup(faddr).c_str());
		
		//Pad length up to 4 words
		uint32_t rdlen = len;
		if(rdlen % 4)
			rdlen = (rdlen | 3) + 1;
		
		//Read the RAM
		printf("READING\n");
		uint32_t rdata[512] = {0};
		iface.DMARead(addr, paddr, rdlen, rdata, RAM_OP_FAILED);
		
		//Flip to host byte order
		FlipEndian32Array((unsigned char*)rdata, 512*4);
			
		//Parse it
		uint8_t src_mac[6] =
		{
			static_cast<uint8_t>(rdata[0] >> 8),
			static_cast<uint8_t>(rdata[0] & 0xff),
			static_cast<uint8_t>(rdata[1] >> 24),
			static_cast<uint8_t>((rdata[1] >> 16) & 0xff),
			static_cast<uint8_t>((rdata[1] >> 8) & 0xff),
			static_cast<uint8_t>(rdata[1] & 0xff)
		};
		uint32_t length = rdata[2];
		uint16_t src_ip[8] =
		{
			static_cast<uint16_t>(rdata[3] >> 16),
			static_cast<uint16_t>(rdata[3] & 0xffff),
			static_cast<uint16_t>(rdata[4] >> 16),
			static_cast<uint16_t>(rdata[4] & 0xffff),
			static_cast<uint16_t>(rdata[5] >> 16),
			static_cast<uint16_t>(rdata[5] & 0xffff),
			static_cast<uint16_t>(rdata[6] >> 16),
			static_cast<uint16_t>(rdata[6] & 0xffff)
		};
		uint16_t dst_ip[8] =
		{
			static_cast<uint16_t>(rdata[7] >> 16),
			static_cast<uint16_t>(rdata[7] & 0xffff),
			static_cast<uint16_t>(rdata[8] >> 16),
			static_cast<uint16_t>(rdata[8] & 0xffff),
			static_cast<uint16_t>(rdata[9] >> 16),
			static_cast<uint16_t>(rdata[9] & 0xffff),
			static_cast<uint16_t>(rdata[10] >> 16),
			static_cast<uint16_t>(rdata[10] & 0xffff)
		};
		printf("    Source MAC:  %02x:%02x:%02x:%02x:%02x:%02x\n",
			src_mac[0], src_mac[1], src_mac[2], src_mac[3], src_mac[4], src_mac[5]);
		printf("    Source IP:   %04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x\n",
			src_ip[0], src_ip[1], src_ip[2], src_ip[3], src_ip[4], src_ip[5], src_ip[6], src_ip[7]);
		printf("    Dest IP:     %04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x\n",
			dst_ip[0], dst_ip[1], dst_ip[2], dst_ip[3], dst_ip[4], dst_ip[5], dst_ip[6], dst_ip[7]);
			
		//Validate the dest IP
		for(int i=0; i<8; i++)
		{
			if(dst_ip[i] != expected_ip[i])
			{
				throw JtagExceptionWrapper(
					"Bad IP",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
			
		//Parse the UDP header
		uint16_t src_port = rdata[11] >> 16;
		uint16_t dst_port = rdata[11] & 0xffff;
		uint16_t ulen = rdata[12] >> 16;
		uint16_t csum = rdata[12] & 0xffff;
		printf("    Source port: %d\n", (int)src_port);
		printf("    Dest port:   %d\n", (int)dst_port);
		printf("    IP len:     %d\n", (int)length);
		printf("    UDP len:     %d\n", (int)ulen);
		printf("    Checksum:    %04x\n", (int)csum);
		
		//Validate the length and port
		if(dst_port != 9999)
		{
			throw JtagExceptionWrapper(
				"Bad dest port",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		if(ulen != 12)	//8 byte header, plus 4 bytes data
		{
			throw JtagExceptionWrapper(
				"Bad UDP length",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Validate the checksum
		uint16_t checksum_in[23]=
		{
			//IPv6 pseudo header
			src_ip[0], src_ip[1], src_ip[2], src_ip[3], src_ip[4], src_ip[5], src_ip[6], src_ip[7],
			dst_ip[0], dst_ip[1], dst_ip[2], dst_ip[3], dst_ip[4], dst_ip[5], dst_ip[6], dst_ip[7],
			IP_PROTOCOL_UDP,
			ulen,
			
			//UDP header
			src_port,
			dst_port,
			ulen,
			
			static_cast<uint16_t>(rdata[13] >> 16),
			static_cast<uint16_t>(rdata[13] & 0xffff)
		};
		uint16_t expected_checksum = ~internet_checksum(sizeof(checksum_in), checksum_in);
		if(expected_checksum != csum)
		{
			printf("             (expected %04x)\n", expected_checksum);
			throw JtagExceptionWrapper(
				"Bad UDP checksum",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Validate the data
		printf("    Data = \"%c%c%c%c\"\n",
			rdata[13] >> 24,
			(rdata[13] >> 16) & 0xff,
			(rdata[13] >> 8) & 0xff,
			rdata[13] & 0xff);
		if(rdata[13] != 0x61736466)
		{
			throw JtagExceptionWrapper(
				"Bad UDP data",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Set up a socket to accept the incoming message
		printf("Setting up inbound socket...\n");
		
		int rx_sock = socket(AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
		if(rx_sock < 0)
		{
			throw JtagExceptionWrapper(
				"Failed to create socket",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		sockaddr_in6 skaddr = 
		{
			AF_INET6,
			htons(9999),
			0,
			IN6ADDR_ANY_INIT,
			0
		};
		if(0 != bind(rx_sock, (sockaddr*)&skaddr, sizeof(skaddr)))
		{
			throw JtagExceptionWrapper(
				"Failed to bind socket",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		
		//Address lookup
		printf("Looking up address of RAM\n");
		uint16_t raddr = nameserver.ForwardLookup("ram");
		printf("RAM is at %04x\n", raddr);
		
		//Allocate a page
		printf("Allocating RAM...\n");
		iface.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
		unsigned int page = rxm.data[1];
		printf("    Allocated page %08x\n", page);
		
		//Format the packet, steal header info from the other packet
		printf("Formatting outbound packet...\n");
		uint32_t outbound_packet[16] =
		{
			//Destination MAC address
			static_cast<uint32_t>((src_mac[0] << 8) | src_mac[1]),
			static_cast<uint32_t>((src_mac[2] << 24) | (src_mac[3] << 16) | (src_mac[4] << 8) | src_mac[5]),
			
			//Payload length
			12,						//Length in bytes
			
			//Source IP (crossover from inbound packet)
			static_cast<uint32_t>((dst_ip[0] << 16) | dst_ip[1]),
			static_cast<uint32_t>((dst_ip[2] << 16) | dst_ip[3]),
			static_cast<uint32_t>((dst_ip[4] << 16) | dst_ip[5]),
			static_cast<uint32_t>((dst_ip[6] << 16) | dst_ip[7]),
			
			//Dest IP (crossover from inbound packet)
			static_cast<uint32_t>((src_ip[0] << 16) | src_ip[1]),
			static_cast<uint32_t>((src_ip[2] << 16) | src_ip[3]),
			static_cast<uint32_t>((src_ip[4] << 16) | src_ip[5]),
			static_cast<uint32_t>((src_ip[6] << 16) | src_ip[7]),
			
			//UDP header
			static_cast<uint32_t>((9999 << 16) | 9999),				//Source and dest ports
			static_cast<uint32_t>((12 << 16)),						//Length, leave checksum as zero for now
			
			//Message data
			static_cast<uint32_t>(('a' << 24) | ('s' << 16) | ('d' << 8) | 'f'),
			
			//Pad to a full cache line for RAM
			0,
			0
		};
		
		//Second copy of outbound packet, for transmit pseudo-header
		uint16_t checksum_out[23]=
		{
			//IPv6 pseudo header
			dst_ip[0], dst_ip[1], dst_ip[2], dst_ip[3], dst_ip[4], dst_ip[5], dst_ip[6], dst_ip[7],
			src_ip[0], src_ip[1], src_ip[2], src_ip[3], src_ip[4], src_ip[5], src_ip[6], src_ip[7],
			IP_PROTOCOL_UDP,
			12,
			
			//UDP header
			9999,
			9999,
			12,
			
			static_cast<uint16_t>(('a' << 8) | 's'),
			static_cast<uint16_t>(('d' << 8) | 'f')
		};
		
		//Compute and insert the outbound checksum
		uint16_t outbound_checksum = ~internet_checksum(sizeof(checksum_out), (unsigned short*)checksum_out);
		outbound_packet[12] |= outbound_checksum;
		
		//Flip to network byte order
		FlipEndian32Array((unsigned char*)outbound_packet, sizeof(outbound_packet));
		
		//Write to RAM
		printf("Writing to RAM...\n");
		iface.DMAWrite(raddr, page, 16, outbound_packet, RAM_WRITE_DONE, RAM_OP_FAILED);
		iface.RPCFunctionCall(raddr, RAM_CHOWN, 0, page, baddr, rxm);
		
		//Send it
		printf("Sending...\n");
		iface.RPCFunctionCall(baddr, BRIDGE_SEND_PAGE, raddr, page, (iaddr << 16) | 14, rxm);
		
		//Receive the message
		char rx_buf[128] = {0};
		sockaddr_storage src;
		socklen_t slen = sizeof(src);
		ssize_t rlen = recvfrom(rx_sock, rx_buf, sizeof(rx_buf), 0, (sockaddr*)&src, &slen);
		if(rlen != 4)
		{
			throw JtagExceptionWrapper(
				"Got message, but it was the wrong size",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		rx_buf[4] = '\0';
		printf("Got message: %s\n", rx_buf);
		if(strcmp(rx_buf, "asdf") != 0)
		{
			throw JtagExceptionWrapper(
				"Message body mismatch",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Clean up
		close(rx_sock);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
