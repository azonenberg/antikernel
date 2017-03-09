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
	@brief Code removed from XilinxFPGA class that doesn't fit anywhere else yet
 */

#ifndef nocbridge_h
#define nocbridge_h

#include "RPCMessage.h"

/**
	@brief A single on-chip debug frame (TODO: move to separate file?)
 */
/*
class AntikernelOCDFrame
{
public:

	//Header word
	unsigned int m_type;
	unsigned int m_seq;
	unsigned int m_credits;

	//Data words
	std::vector<uint32_t> m_data;
};

//RPC/DMA stuff
virtual void ProbeVirtualTAPs();
virtual void SetOCDInstruction() =0;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RPC network interface

virtual bool HasRPCInterface();
virtual RPCNetworkInterface* GetRPCNetworkInterface();
virtual void SendRPCMessage(const RPCMessage& tx_msg);
virtual bool SendRPCMessageNonblocking(const RPCMessage& tx_msg);
virtual bool RecvRPCMessage(RPCMessage& rx_msg);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DMA network interface

virtual bool HasDMAInterface();
virtual DMANetworkInterface* GetDMANetworkInterface();
virtual void SendDMAMessage(const DMAMessage& tx_msg);
virtual bool SendDMAMessageNonblocking(const DMAMessage& tx_msg);
virtual bool RecvDMAMessage(DMAMessage& rx_msg);

public:
virtual bool HasIndirectFlashSupport();
virtual void ProgramIndirect(
	ByteArrayFirmwareImage* image,
	int buswidth,
	bool reboot = true,
	unsigned int base_address = 0,
	std::string prog_image = "");
virtual void DumpIndirect(int buswidth, std::string fname);


virtual uint16_t LoadIndirectProgrammingImage(int buswidth, std::string image_fname = "");

///True if we have an RPC interface in the current bitstream
bool m_bHasRPCInterface;

///True if we have a DMA interface in the current bitstream
bool m_bHasDMAInterface;

///Push all pending data to the device and get stuff back
void OCDPush();

///Raw data words to be pushed to the device
std::vector<uint32_t> m_ocdtxbuf;

///Raw data words coming off the device
std::vector<uint32_t> m_ocdrxbuf;

///Decoded frames from the device
std::vector<AntikernelOCDFrame*> m_ocdrxframes;

///Sequence number for next NoC packet to be sent
uint8_t m_sequence;

///Credits free on the board
unsigned int m_credits;

///Actual free credit count
unsigned int GetActualCreditCount();

///List of pending packets that have been sent but may still be in m_ocdtxbuf or the fifo on the board
///pair(sequence, size)
std::vector< std::pair<unsigned int, unsigned int> > m_pendingSendCounts;
};
*/

#endif
