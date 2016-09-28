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
	@brief Declaration of DMAMessage
 */

#ifndef DMAMessage_h
#define DMAMessage_h

#include <stdint.h>

#include "DMARouter_constants.h"

/** 
	@brief A single packet on the DMA network
	
	The DMA network is a packet-switched NoC intended for high-throughput data-plane operations in which high latency
	is acceptable to minimize protocol overhead.
	
	Each packet consists of three header words and up to 512 data words.
	
	Packet format (32-bit words)
		Word							Data
		0								Source network address (16 bits)
										Dest network address	(16 bits)
		1								Opcode (2 bits)
										Padding (20 bits)
										Payload length in words (10 bits)
		2								Physical memory address
		Data							0 to 512 words.
	
	Reliable, in-order delivery is guaranteed by the network.
	
	\ingroup libjtaghal
 */
class DMAMessage
{
public:

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Header word 0

	///Source address
	uint16_t from;
	
	///Destination address
	uint16_t to;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Header word 1
	
	///Opcode
	uint8_t opcode;
	
	//padding here
	
	///Payload length, in 32-bit words
	uint16_t len;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Header word 2
	
	///Address
	uint32_t address;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Data
	
	///Data words
	uint32_t data[512];
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Functions
	
	void Pack(uint32_t* buf) const; 
	void Unpack(uint32_t* buf);
	void UnpackHeaders(uint32_t* buf, bool zeroizedata=true);
	
	bool operator==(const DMAMessage& rhs) const;
};

#endif
