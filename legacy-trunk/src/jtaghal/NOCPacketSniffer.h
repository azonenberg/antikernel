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
	@brief Declaration of NOCPacketSniffer
 */
#ifndef NOCPacketSniffer_h
#define NOCPacketSniffer_h

#include <string>
#include <list>

class RPCMessage;
class DMAMessage;

#include "RPCAndDMANetworkInterface.h"

//TODO: Consider merging this with LA protocol decode?
class RPCSniffSample
{
public:
	int64_t m_start;
	uint32_t m_daddr;
	RPCMessage m_msg;
	
	RPCSniffSample(int64_t t, uint32_t daddr, RPCMessage m)
	 : m_start(t)
	 , m_daddr(daddr)
	 , m_msg(m)
	{}
};

class DMASniffSample
{
public:
	int64_t m_start;
	uint32_t m_daddr;
	bool m_full;
	DMAMessage m_msg;
	
	DMASniffSample(int64_t t, uint32_t daddr, bool full, DMAMessage m)
	 : m_start(t)
	 , m_daddr(daddr)
	 , m_full(full)
	 , m_msg(m)
	{}
};

/**
	@brief A connection to a NoC packet sniffer
	
	\ingroup libjtaghal
 */
class NOCPacketSniffer
{
public:
	NOCPacketSniffer(RPCAndDMANetworkInterface& iface, std::string hostname);
	~NOCPacketSniffer();

	NameServer& GetNameServer()
	{ return m_namesrvr; }
	
	void PollStatus(std::list<RPCSniffSample>& samples, std::list<DMASniffSample>& dsamples);
	
	unsigned int GetSysclkPeriod()
	{ return m_sysclkPeriod; }

protected:

	///The interface we use for talking to the sniffer
	RPCAndDMANetworkInterface& m_iface;
	
	///Name server
	NameServer m_namesrvr;
	
	///Address of the sniffer
	uint16_t m_address;
	
	unsigned int m_sysclkPeriod;
};

#endif
