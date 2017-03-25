/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
	@brief Declaration of JTAGNOCBridgeInterface
 */
#ifndef JTAGNOCBridgeInterface_h
#define JTAGNOCBridgeInterface_h

#include <set>

/**
	@brief JTAG frame header
 */
union AntikernelJTAGFrameHeader
{
	struct
	{
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// FIRST WORD

		/// Sequence number of the frame being acked/nak'd
		unsigned int ack_seq : 10;

		/// Available buffer space (in words)
		unsigned int credits : 10;

		/// Sequence number of the frame
		unsigned int sequence : 10;

		/// 1 if frame contains a negative acknowledgement, 0 otherwise
		unsigned int nak : 1;

		/// 1 if frame contains an acknowledgement, 0 otherwise
		unsigned int ack : 1;

		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// SECOND WORD

		/// Checksum of the header
		unsigned int header_checksum : 8;

		/// Length (in words) of our payload
		unsigned int length : 10;

		/// Reserved, write as zero
		unsigned int reserved_zero : 11;

		/// 1 if payload is DMA packet, 0 otherwise
		unsigned int dma : 1;

		/// 1 if payload is RPC packet, 0 otherwise
		unsigned int rpc : 1;

		/// 1 if we have a payload, 0 otherwise
		unsigned int payload_present : 1;

	} __attribute__ ((packed)) bits;

	uint32_t words[2];
	uint8_t bytes[8];
};

/**
	@brief A NOCBridgeInterface that runs over JTAG
 */
class JTAGNOCBridgeInterface : public NOCBridgeInterface
{
public:
	JTAGNOCBridgeInterface(JtagFPGA* pfpga);
	virtual ~JTAGNOCBridgeInterface();

	virtual bool AllocateClientAddress(uint16_t& addr);
	virtual void FreeClientAddress(uint16_t addr);

	void Cycle();

protected:
	void ComputeHeaderChecksum(AntikernelJTAGFrameHeader& header);
	bool VerifyHeaderChecksum(AntikernelJTAGFrameHeader header);

	unsigned int NextSeq(unsigned int seq)
	{
		if(seq < 0x3ff)
			return seq + 1;
		else
			return 0;
	}

	unsigned int PrevSeq(unsigned int seq)
	{
		if(seq > 0)
			return seq - 1;
		else
			return 0x3ff;
	}

	void PrintMessageHeader(const AntikernelJTAGFrameHeader& header);

	uint8_t CRC8(uint32_t* data, unsigned int len);
	uint32_t CRC32(uint32_t* data, unsigned int len);

	/// The device we're debugging
	JtagFPGA* m_fpga;

	/// Set of free addresses
	std::set<uint16_t> m_freeAddresses;

	/// Sequence number of the next packet to be sent
	unsigned int m_nextSequence;

	/// ACK number of next packet to be sent
	unsigned int m_nextAck;

	///True if we're sending ACKs
	bool m_acking;

	///TODO: handle NAKs

	/// Data to be sent to the DUT
	std::list<uint32_t> m_txBuffer;

	/// Data that came back from the DUT
	std::list<uint32_t> m_rxBuffer;

	//TODO: retransmit buffer
};

#endif
