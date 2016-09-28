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
	@brief NetworkedEthernetMAC loopback test
	
	Performs various test operations on the Ethernet MAC.
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

#include <NetworkedEthernetMAC_opcodes_constants.h>
#include <NetworkedDDR2Controller_opcodes_constants.h>
#include <NOCSysinfo_constants.h>
#include <Ethertypes_constants.h>
#include <IPProtocols_constants.h>

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
		
		usleep(500 * 1000);
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Look up some RAM
		printf("Looking up address of ram...\n");
		NameServer nameserver(&iface);
		uint16_t raddr = nameserver.ForwardLookup("ram");
		printf("ram is at %04x\n", raddr);
		
		//Allocate the first page just so we can tell a pointer is valid easily
		RPCMessage rxm;
		iface.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
		uint32_t ptr = rxm.data[1];
		printf("    First page of RAM allocated (0x%08x)\n", ptr);

		//Address lookup
		printf("Looking up address of eth0...\n");
		uint16_t eaddr = nameserver.ForwardLookup("eth0");
		printf("eth0 is at %04x\n", eaddr);
		printf("Looking up address of sysinfo...\n");
		uint16_t saddr = nameserver.ForwardLookup("sysinfo");
		printf("sysinfo is at %04x\n", saddr);

		//Request a reset
		printf("Resetting interface...\n");
		iface.RPCFunctionCall(eaddr, ETH_RESET, 0, 0, 0, rxm);
		
		//Request ownership of IPv4
		printf("Requesting ownership of IPv4...\n");
		iface.RPCFunctionCall(eaddr, ETH_REGISTER_TYPE, ETHERTYPE_IPV4, 0, 0, rxm);
		
		//Generate a locally assigned MAC address based on the die serial number
		iface.RPCFunctionCall(saddr, SYSINFO_CHIP_SERIAL, 0, 0, 0, rxm);
		unsigned short mac[3]=
		{
			static_cast<unsigned short>((0x02 << 8) | (rxm.data[2] & 0xff)),
			static_cast<unsigned short>(rxm.data[1] >> 16),
			static_cast<unsigned short>(rxm.data[1] & 0xffff),
		};
		
		//Set MAC address
		printf("Setting interface MAC address to %02x:%02x:%02x:%02x:%02x:%02x...\n",
			mac[0] >> 8, mac[0] & 0xff,
			mac[1] >> 8, mac[1] & 0xff,
			mac[2] >> 8, mac[2] & 0xff);
		iface.RPCFunctionCall(
			eaddr,
			ETH_SET_MAC,
			mac[0],
			(mac[1] << 16) | mac[2],
			0,
			rxm);
			
		//Allocate a buffer for the transmit buffer
		printf("Allocating memory...\n");
		iface.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
		uint32_t txptr = rxm.data[1];
		printf("    Transmit buffer is at 0x%08x\n", txptr);
		
		//Wait for link to come up
		double start = GetTime();
		printf("Waiting for link to come up...\n");
		while(true)
		{
			if( (GetTime() - start) > 30)
			{
				throw JtagExceptionWrapper(
					"Link not up after 30 seconds, giving up",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			iface.WaitForInterruptFrom(eaddr, rxm, 30);
			if(rxm.callnum != ETH_LINK_STATE)
			{
				printf("Expected link state interrupt, got something else (ignoring)\n");
				continue;
			}
			
			//Link is up
			if(rxm.data[0] & 1)
			{
				//TODO: Use enum here
				int speed = 0;
				int espeed = (rxm.data[0] >> 2) & 3;
				switch(espeed)
				{
				case 1:
					speed = 10;
					break;
				case 2:
					speed = 100;
					break;
				case 3:
					speed = 1000;
				}
				printf("    Link is up (%s duplex, %d Mbps, took %.2f sec)\n",
					(rxm.data[0] & 2) ? "full" : "half", speed, GetTime() - start);
				break;
			}
		}
		usleep(1000 * 1000);
	
		//Generate the packet
		printf("Copying packet to board...\n");
		uint32_t dhcp_packet[] = 
		{
			//IPv4 header
			0x45000000,	//IPv4, minimal length header, length not known yet
			0x00004000,	//ID 0, no frag offset, don't fragment
			0xff110000,	//Hop count 255, protocol 0x11 (UDPv4), header checksum not known yet
			0x00000000,	//From 0.0.0.0
			0xffffffff,	//To 255.255.255.255
			
			//UDPv4 header
			0x00440043,	//From port 68 to port 67
			0x00000000,	//Length not known yet, checksum not known yet
			
			//DHCP stuff
			0x01010600,	//Op 1, htype 1, hlen 6, hops 0
			0xdeadbeef,	//XID
			0x00000000,	//secs 0, flags 0
			0x00000000,	//CIADDR
			0x00000000, //YIADDR
			0x00000000,	//SIADDR
			0x00000000, //GIADDR
			static_cast<uint32_t>( (mac[0] << 16) | (mac[1]) ),
			static_cast<uint32_t>(mac[2] << 16 ),
			0x00000000,
			0x00000000,
			
			//48 words of padding
			0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,
			0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,
			0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,
			0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,
			0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,
			0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,	0x00000000,
			
			//DHCP / BOOTP magic cookie
			0x63825363,
						
			//DHCP options
			0x350101ff		//0x35 = DHCP message type, len 0x01, type 0x01 = DHCPDISCOVER
							//End of options
		};
		
		//Set total length
		dhcp_packet[0] = (dhcp_packet[0] & 0xFFFF0000) | sizeof(dhcp_packet);
		
		//Set UDP length
		dhcp_packet[6] = (sizeof(dhcp_packet) - 20) << 16;
		
		//Compute IPv4 header checksum
		uint16_t header_checksum = ~internet_checksum(20, (unsigned short*)(dhcp_packet));
		dhcp_packet[2] = (dhcp_packet[2] & 0xFFFF0000) | header_checksum;
		
		//Leave UDP checksum as zero for now
			
		//Endianness swap
		for(size_t i=0; i<sizeof(dhcp_packet)/4; i++)
			dhcp_packet[i] = htonl(dhcp_packet[i]);
		
		//Send the packet to RAM, then chown it to the NIC
		iface.DMAWrite(raddr, txptr, sizeof(dhcp_packet)/4, dhcp_packet, RAM_WRITE_DONE, RAM_OP_FAILED);
		iface.RPCFunctionCall(raddr, RAM_CHOWN, 0, txptr, eaddr, rxm);		
		
		//Send the packet to the NIC
		printf("Sending packet to NIC\n");
		iface.RPCFunctionCall(eaddr, ETH_SET_DSTMAC, 0xffff, 0xffffffff, 0, rxm);
		iface.RPCFunctionCall(
			eaddr,
			ETH_SEND_FRAME,
			raddr,
			txptr,
			(sizeof(dhcp_packet)/4) | (ETHERTYPE_IPV4 << 16),
			rxm);
		
		//Wait for a response
		printf("Waiting for DHCP response...\n");
		start = GetTime();
		while(true)
		{
			if( (GetTime() - start) > 30)
			{
				throw JtagExceptionWrapper(
					"No DHCP packets arrived after 30 seconds, giving up",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			iface.WaitForInterruptFrom(eaddr, rxm, 10);
			
			if(rxm.callnum == ETH_LINK_STATE)
			{
				printf("WARNING: link state changed (%s)\n", (rxm.data[0] & 1) ? "up" : "down");
				continue;
			}
			else if(rxm.callnum != ETH_FRAME_READY)
			{	
				throw JtagExceptionWrapper(
					"Got unknown interrupt",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			int len = rxm.data[0];
			uint32_t fptr = rxm.data[1];
			printf("Got a packet (physical address 0x%08x, length %d words)\n", fptr, len);
			if(len > 512)
				len = 512;
			printf("    Ethertype: %04x\n", rxm.data[2] >> 16);
			
			//DMA the frame and print the headers
			printf("Reading frame from RAM...\n");
			uint32_t data[512] = {0};
			iface.DMARead(raddr, fptr, 512, data, RAM_OP_FAILED, 1);
			
			//We're done, free it
			printf("    Freeing memory (%08x)\n", fptr);
			iface.RPCFunctionCall(raddr, RAM_FREE, 0, fptr, 0, rxm);
			
			//Endian swap
			uint8_t frame[2048] = {0};
			for(int i=0, dp=0; dp<len; i+=4, dp++)
			{
				frame[i] = (data[dp] >> 0) & 0xff;
				frame[i+1] = (data[dp] >> 8) & 0xff;
				frame[i+2] = (data[dp] >> 16) & 0xff;
				frame[i+3] = (data[dp] >> 24) & 0xff;
			}
			
			//IPv4 decode
			//The MAC only should be giving us IPv4 packets so if we get anything else it's a problem
			if( (frame[0] & 0xF0) != 0x40)
			{
				throw JtagExceptionWrapper(
					"Expected IPv4 packet, got something else",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			int hdrlen = frame[0] & 0xF;
			printf("    IPv4 header length: %d words\n", hdrlen);
			int total_len = (frame[2] << 8) | frame[3];
			printf("    Total length: %d bytes\n", total_len);
			if( ( (frame[6] & 0x1F) != 0 ) || (frame[7] != 0) )
			{
				throw JtagExceptionWrapper(
					"Fragment offset should be zero",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			printf("    TTL: %d\n", frame[8]);
		
			//Should be UDP
			if(frame[9] != IP_PROTOCOL_UDP)
			{
				printf("    Packet is not UDP, skipping it\n");
				continue;
			}
			
			//Ignore header checksum for now
			printf("    Source address: %d.%d.%d.%d\n",
				frame[12], frame[13], frame[14], frame[15]);
			printf("    Dest address: %d.%d.%d.%d\n",
				frame[16], frame[17], frame[18], frame[19]);
			
			//UDP decode
			uint8_t* udpframe = frame + 4*hdrlen;
			int srcport = (udpframe[0] << 8) | udpframe[1];
			int dstport = (udpframe[2] << 8) | udpframe[3];
			printf("    Source port: %d\n", srcport);
			printf("    Dest port: %d\n", dstport);
			int udplen = (udpframe[4] << 8) | udpframe[5];
			printf("    UDP length: %d\n", udplen);
			
			//If not a DHCP reply, ignore it
			if( (srcport != 67) || (dstport != 68) )
			{
				printf("    Packet is not DHCP reply, skipping it\n");
				continue;
			}
		
			//DHCP decode
			uint8_t* dhcp = udpframe + 8;
			int opcode = dhcp[0];
			printf("    DHCP opcode: %d\n", opcode);
			if(opcode != 2)
			{
				throw JtagExceptionWrapper(
					"Expected DHCP packet type 2 (Boot Reply)",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			if(dhcp[1] != 1)
			{
				throw JtagExceptionWrapper(
					"Expected DHCP address type 1 (ethernet)",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			//Free the dummy page
			printf("    Freeing dummy page (%08x)\n", ptr);
			iface.RPCFunctionCall(raddr, RAM_FREE, 0, ptr, 0, rxm);
			
			//Don't bother parsing the rest of the packet
			return 0;
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
