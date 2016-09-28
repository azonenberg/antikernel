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
	@brief Implementation of NOCPacketSniffer
 */

#include "jtaghal.h"
#include "NOCPacketSniffer.h"

#include <NocPacketSniffer_opcodes_constants.h>
#include <NOCSysinfo_constants.h>

using namespace std;

bool sample_compare(const RPCSniffSample& a, const RPCSniffSample& b);
bool sample_compare_dma(const DMASniffSample& a, const DMASniffSample& b);

/**
	@brief Connect to a sniffer
 */
NOCPacketSniffer::NOCPacketSniffer(RPCAndDMANetworkInterface& iface, std::string hostname)
	: m_iface(iface)
	, m_namesrvr(&iface)
{
	int addr = m_namesrvr.ForwardLookup(hostname);
	m_address = addr;
	printf("[NOCPacketSniffer] Host %s is at %04x\n", hostname.c_str(), addr);
	
	int sysinfo_addr = m_namesrvr.ForwardLookup("sysinfo");	
	RPCMessage rxm;
	m_iface.RPCFunctionCall(sysinfo_addr, SYSINFO_QUERY_FREQ, 0, 0, 0, rxm);
	m_sysclkPeriod = rxm.data[1];
	
	//Start the capture
	m_iface.RPCFunctionCallWithTimeout(m_address, SNIFF_START, 0, 0, 0, rxm, 0.5);
}

/**
	@brief Disconnects from the server
 */
NOCPacketSniffer::~NOCPacketSniffer()
{
	
}

void NOCPacketSniffer::PollStatus(list<RPCSniffSample>& samples, std::list<DMASniffSample>& dsamples)
{
	//Read until there's nothing left t oread
	DMAMessage rxm;
	while(m_iface.RecvDMAMessage(rxm))
	{
		//Sanity check that it's from the LA
		if(rxm.from != m_address)
			continue;
			
		//Warn if it's large
		if(rxm.len > 480)
			printf("WARNING: Buffer was nearly full, may have overflowed\n");
		
		//If it's an RPC message, crunch it
		if( (rxm.address == 0x00000000) || (rxm.address == 0x00000800) )
		{
			for(size_t i=0; i<rxm.len; i += 6)
			{
				uint64_t timestamp = (static_cast<uint64_t>(rxm.data[i]) << 32) | rxm.data[i+1];
				FlipEndian32Array(reinterpret_cast<unsigned char*>(&timestamp), sizeof(timestamp));
				
				RPCMessage rmsg;
				rmsg.Unpack(reinterpret_cast<unsigned char*>(rxm.data+i+2));
				
				samples.push_back(RPCSniffSample(timestamp, rxm.address, rmsg));
			}
			
			//Sort the list of samples by timestamp
			samples.sort(sample_compare);
			
			//Remove duplicates.
			//This can happen if a message was looped back
			//ex. by a multithreaded CPU sending from one thread to another
			auto old_it = samples.begin();
			for(auto it = samples.begin(); it != samples.end(); it++)
			{
				//First message can never be a duplicate
				if(it != samples.begin())
				{
					//If the messages are equal (ignoring timestamp) and came in on opposite interfaces,
					//we're a duplicate. Delete it.
					if( (it->m_msg == old_it->m_msg) && (it->m_daddr != old_it->m_daddr) )
						samples.erase(old_it);
				}
				
				//Save the current stuff as old
				old_it = it;
			}
		}
		
		//Nope, it's a DMA message
		else
		{
			//printf("Got a DMA capture (length %d, address %d)\n", rxm.len, rxm.address);
			
			//DMA headers are one word shorter than full RPC messages
			//Flip endianness so the decode makes sense
			FlipEndian32Array(reinterpret_cast<unsigned char*>(&rxm.data), 512*4);
			for(size_t i=0; i<rxm.len; i += 5)
			{
				uint64_t timestamp = (static_cast<uint64_t>(rxm.data[i]) << 32) | rxm.data[i+1];
				
				DMAMessage dmsg;
				dmsg.UnpackHeaders(rxm.data+i+2);
				
				/*
				printf("message data\n");
				for(int j=0; j<5; j++)
					printf("    %08x\n", rxm.data[i+j]);
				*/
				
				//flag message as not having full payload
				dsamples.push_back(DMASniffSample(timestamp, rxm.address, false, dmsg));
			}
			
			//Sort the list of samples by timestamp
			dsamples.sort(sample_compare_dma);
			
			//Remove duplicates.
			//This can happen if a message was looped back
			//ex. by a multithreaded CPU sending from one thread to another
			auto old_it = dsamples.begin();
			for(auto it = dsamples.begin(); it != dsamples.end(); it++)
			{
				//First message can never be a duplicate
				if(it != dsamples.begin())
				{
					//If the messages are equal (ignoring timestamp) and came in on opposite interfaces,
					//we're a duplicate. Delete it.
					if( (it->m_msg == old_it->m_msg) && (it->m_daddr != old_it->m_daddr) )
						dsamples.erase(old_it);
				}
				
				//Save the current stuff as old
				old_it = it;
			}
		}
	}
}

bool sample_compare(const RPCSniffSample& a, const RPCSniffSample& b)
{
	return a.m_start < b.m_start;
}

bool sample_compare_dma(const DMASniffSample& a, const DMASniffSample& b)
{
	return a.m_start < b.m_start;
}
