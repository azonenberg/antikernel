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
	@brief Implementation of misc noc bridge stuff that has to go somewhere
 */
#include "nocbridge.h"
//#include "jtaghal.h"
//#include "XilinxFPGA.h"

using namespace std;

/*
void XilinxFPGA::ProgramIndirect(
	ByteArrayFirmwareImage* image,
	int buswidth,
	bool reboot,
	unsigned int base_address,
	string prog_image)
{
	//Program the FPGA with the indirect bitstream
	uint16_t faddr = LoadIndirectProgrammingImage(buswidth, prog_image);

	ByteArrayFirmwareImage* bitstream = dynamic_cast<ByteArrayFirmwareImage*>(image);
	if(bitstream == NULL)
	{
		throw JtagExceptionWrapper(
			"Invalid bitstream (not a ByteArrayFirmwareImage)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}

	//Get the flash size
	RPCMessage rxm;
	RPCAndDMANetworkInterface* iface = dynamic_cast<RPCAndDMANetworkInterface*>(this);
	iface->RPCFunctionCallWithTimeout(faddr, NOR_GET_SIZE, 0, 0, 0, rxm, 5);
	unsigned int sector_count = rxm.data[1] / (4096*8);
	unsigned int size_KB = rxm.data[1] / 8192;
	printf("    Flash size is %u KB (%u sectors)\n", size_KB, sector_count);

	//Get the bitstream size
	printf("    Programming flash with %s\n", bitstream->GetDescription().c_str());
	unsigned int sectorlen = ceil(static_cast<float>(bitstream->raw_bitstream_len)/4096.0f);
	unsigned int wordmax = ceil(static_cast<float>(bitstream->raw_bitstream_len)/4.0f);
	printf("    Bitstream size is %.2f KB (%u words, %u 4KB sectors)\n",
		bitstream->raw_bitstream_len / 1024.0f,
		wordmax,
		sectorlen);

	vector<unsigned int> promdata;

	//If it's a FPGA bitstream, add some filler before the start.
	//Don't do this for software images etc
	if(dynamic_cast<XilinxFPGABitstream*>(bitstream) != NULL)
	{
		for(unsigned int i=0; i<4; i++)
			promdata.push_back(0xFFFFFFFF);
	}

	//Add the data itself
	for(unsigned int i=0; i<bitstream->raw_bitstream_len; i+=4)
		promdata.push_back(GetBigEndianUint32FromByteArray(bitstream->raw_bitstream, i));
	unsigned int nmax = promdata.size();

	//Add some filler at the end of the bitstream so we can safely read up to one flash page beyond (for sector writes)
	for(unsigned int i=0; i<512; i++)
		promdata.push_back(0xFFFFFFFF);

	//Flip word ordering
	FlipEndian32Array((unsigned char*)&promdata[0], promdata.size()*4);

	//Actually write to the flash
	printf("    Erasing (using design specific sector erase)...\n");
	for(unsigned int sec=0; sec<sectorlen; sec++)
		iface->RPCFunctionCallWithTimeout(faddr, NOR_PAGE_ERASE, 0, base_address + sec*4096, 0, rxm, 5);

	//Debug code: erase the whole chip and stop
	//TODO: Make a function for doing this
	//for(unsigned int sec=0; sec<sector_count; sec++)
	//	iface->RPCFunctionCallWithTimeout(faddr, NOR_PAGE_ERASE, 0, sec*4096, 0, rxm, 5);
	//return;

	printf("    Programming...\n");
	for(unsigned int i=0; i<nmax; i+=64)
		iface->DMAWrite(faddr, base_address + i*4, 64, &promdata[i], NOR_WRITE_DONE, NOR_OP_FAILED);

	//Verify
	printf("    Verifying...\n");
	unsigned int rdata[512] = {0};
	for(unsigned int block=0; block<(sectorlen*2); block++)
	{
		iface->DMARead(faddr, base_address + (block*512)*4, 512, rdata, NOR_OP_FAILED);

		for(unsigned int i=0; i<512; i++)
		{
			unsigned int n = block*512 + i;
			if(n >= wordmax)
				break;
			if(promdata[n] != rdata[i])
			{
				printf("    Mismatch (at word address %u, got %08x, expected %08x)\n",
					 n, rdata[i], promdata[n]);
				throw JtagExceptionWrapper(
					"Got bad data back from board",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
	}

	//Reset the FPGA and load the new bitstream
	if(reboot)
	{
		printf("    Resetting FPGA...\n");
		Reboot();

		//Wait for it to boot
		for(int i=0; i<5; i++)
		{
			usleep(5 * 1000 * 1000);
			if(IsProgrammed())
				return;
		}

		PrintStatusRegister();
		throw JtagExceptionWrapper(
			"Timed out after 25 sec waiting for FPGA to boot from flash",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
}
*/

/**
	@brief Loads an indirect programming image suitable for the given bus width
 */
/*
uint16_t XilinxFPGA::LoadIndirectProgrammingImage(int buswidth, std::string image_fname)
{
	//Only support QSPI for now
	if(buswidth != 4)
	{
		throw JtagExceptionWrapper(
			"Unsupported SPI bus width (BPI and non-quad SPI not implemented yet).",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}

	//Find the correct indirect-programming image (TODO: don't hard code path - how do we get this?)
	std::string basepath = "/nfs4/home/azonenberg/code/antikernel/trunk/splashbuild/xilinx-fpga-";

	if(image_fname.empty())
	{
		static struct
		{
			string name;
			string bit;
		} images[] =
		{
			{ "Xilinx XC6SLX9",  "spartan6-xc6slx9-2tqg144/IndirectFlash-xc6slx9-2tqg144.bit"},
			{ "Xilinx XC6SLX16", "spartan6-xc6slx16-2ftg256/IndirectFlash-xc6slx16-2ftg256.bit"},
			{ "Xilinx XC6SLX25", "spartan6-xc6slx25-2ftg256/IndirectFlash-xc6slx25-2ftg256.bit"},
			{ "Xilinx XC6SLX45", "spartan6-xc6slx45-2csg324/IndirectFlash-xc6slx45-2csg324.bit"},
			{ "Xilinx XC7A200T", "artix7-xc7a200t-1fbg676/IndirectFlash-xc7a200t-1fbg676.bit"},
			{ "Xilinx XC7K70T",  "kintex7-xc7k70t-1fbg484/IndirectFlash-xc7k70t-1fbg484.bit"}
		};

		bool found = false;
		for(auto x : images)
		{
			if(GetDescription().find(x.name) != string::npos)
			{
				basepath += x.bit;
				found = true;
				break;
			}
		}

		if(!found)
		{
			throw JtagExceptionWrapper(
				"The selected FPGA does not have an indirect SPI programming image available",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
	}
	else
		basepath = image_fname;

	//Load the SPI image
	FirmwareImage* spi_image = LoadFirmwareImage(basepath);
	printf("    Loading indirect programming image...\n");
	Program(spi_image);
	delete spi_image;

	//Verify we got something
	ProbeVirtualTAPs();
	if(!HasRPCInterface())
	{
		throw JtagExceptionWrapper(
			"No RPC network interface found",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}

	RPCAndDMANetworkInterface* iface = dynamic_cast<RPCAndDMANetworkInterface*>(this);
	if(iface == NULL)
	{
		throw JtagExceptionWrapper(
			"Not an RPCAndDMANetworkInterface",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}

	//Address lookup
	printf("    Looking up flash info\n");
	NameServer nameserver(iface);
	uint16_t faddr = nameserver.ForwardLookup("flash");
	printf("    Flash is at NoC address %04x\n", faddr);
	return faddr;
}

void XilinxFPGA::DumpIndirect(int buswidth, std::string fname)
{
	//Program the FPGA with the indirect bitstream
	uint16_t faddr = LoadIndirectProgrammingImage(buswidth);

	//Get the flash size
	RPCMessage rxm;
	RPCAndDMANetworkInterface* iface = dynamic_cast<RPCAndDMANetworkInterface*>(this);
	iface->RPCFunctionCallWithTimeout(faddr, NOR_GET_SIZE, 0, 0, 0, rxm, 5);
	unsigned int sector_count = rxm.data[1] / (4096*8);
	unsigned int read_count = sector_count * 2;
	unsigned int size_KB = rxm.data[1] / 8192;
	printf("    Flash size is %u KB (%u sectors, %u read blocks)\n", size_KB, sector_count, read_count);

	//Open output file
	FILE* fp = fopen(fname.c_str(), "wb");
	if(fp == NULL)
	{
		throw JtagExceptionWrapper(
			"Couldn't open output file",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}

	//Dump it
	uint32_t rdata[512];
	printf("    Dumping...\n");
	for(unsigned int block=0; block<read_count; block++)
	{
		iface->DMARead(faddr, block*2048, 512, rdata, NOR_OP_FAILED);
		fwrite(rdata, 512, 4,  fp);
	}

	fclose(fp);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NoC helpers

RPCNetworkInterface* XilinxFPGA::GetRPCNetworkInterface()
{
	return static_cast<RPCNetworkInterface*> (this);
}

DMANetworkInterface* XilinxFPGA::GetDMANetworkInterface()
{
	return static_cast<DMANetworkInterface*> (this);
}
*/
/**
	@brief Push all pending OCD operations to the device and get data back
 */
/*
void XilinxFPGA::OCDPush()
{
	//Make room for receive data
	size_t wcount = m_ocdtxbuf.size();
	size_t base = m_ocdrxbuf.size();
	for(size_t i=0; i<wcount; i++)
		m_ocdrxbuf.push_back(0);

	//Push all pending data to the device and get stuff back
	m_iface->ShiftData(0, (unsigned char*)m_ocdtxbuf.data(), (unsigned char*)(m_ocdrxbuf.data() + base), wcount*32);
	m_ocdtxbuf.clear();

	//Decode incoming packets
	while(!m_ocdrxbuf.empty())
	{
		//Remove null words from start of buffer
		if(!m_ocdrxbuf.empty() && (m_ocdrxbuf[0] == 0) )
		{
			//See how many nulls there are
			size_t i = 0;
			for(; (i<m_ocdrxbuf.size()) && (m_ocdrxbuf[i] == 0); i++)
			{}

			//Remove them
			m_ocdrxbuf.erase(m_ocdrxbuf.begin(), m_ocdrxbuf.begin() + i);
		}

		//Stop if we don't have enough words to constitute a complete frame
		if(m_ocdrxbuf.size() < 2)
			break;

		//Next word should be a preamble. If not, ignore it.
		if(m_ocdrxbuf[0] != JTAG_FRAME_PREAMBLE)
		{
			printf("    Ignoring unknown word %08x\n", m_ocdrxbuf[0]);
			m_ocdrxbuf.erase(m_ocdrxbuf.begin());
			continue;
		}

		//Got the preamble OK.
		//Read the header word and see how much data we expect. If frame isn't fully received then stop now
		uint32_t header = m_ocdrxbuf[1];
		unsigned int type = header >> 29;
		unsigned int len = (header >> 19) & 0x3ff;
		unsigned int seq = (header >> 11) & 0xff;
		unsigned int credits = header & 0x7ff;
		if(m_ocdrxbuf.size() < (2 + len))
			break;

		//Update credit count
		if(m_credits != credits)
			m_credits = credits;

		//If it's an ACK for a sent packet, process it. Allow a few packets worth of wraparound.
		if(!m_pendingSendCounts.empty())
		{
			while(!m_pendingSendCounts.empty())
			{
				unsigned int pseq = m_pendingSendCounts[0].first;

				//Packet with seq >250 should not ack packet with seq <5 due to wraparound
				//(this limits us to ~240 packets in the pipeline)
				if( (seq > 250) && (pseq < 5) )
					break;

				//If acknowledged sequence number is >= sequence of first packet in buffer, clear it out.
				//ACKs with small sequence numbers should cover packets with huge seq
				if( (seq >= m_pendingSendCounts[0].first) || ((seq < 5) && (pseq > 250)) )
					m_pendingSendCounts.erase(m_pendingSendCounts.begin());

				//Nothing matched, give up
				break;
			}
		}

		//If it's a keepalive, don't waste buffer space... just update credits etc
		if(type == JTAG_FRAME_TYPE_KEEPALIVE)
		{
			//static unsigned int old = 0;
			//if(old != m_ocdrxbuf[2])
			//{
			//	printf("Keepalive: data = %08x\n", m_ocdrxbuf[2]);
			//	fflush(stdout);
			//	old = m_ocdrxbuf[2];
			//}
		}

		//No, normal packet but we got the whole frame. Store it.
		else
		{
			AntikernelOCDFrame* frame = new AntikernelOCDFrame;
			frame->m_type = type;
			frame->m_seq = seq;
			frame->m_credits = credits;
			for(size_t i=0; i<len; i++)
				frame->m_data.push_back(m_ocdrxbuf[2 + i]);
			m_ocdrxframes.push_back(frame);
		}

		//Clear the fully processed frame out of the fifo no matter what it is
		m_ocdrxbuf.erase(m_ocdrxbuf.begin(), m_ocdrxbuf.begin() + 2 + len);
	}
}
*/
/*
void XilinxFPGA::ProbeVirtualTAPs()
{
	//TODO: Figure out how to stream if there's >1 device in the chain
	if(m_iface->GetDeviceCount() != 1)
	{
		throw JtagExceptionWrapper(
			"Don't know how to handle >1 device in OCD mode",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}

	//Flush buffers and try to synchronize
	printf("    Synchronizing OCD link...\n");
	ResetToIdle();
	m_ocdtxbuf.clear();
	m_ocdrxbuf.clear();
	for(auto x : m_ocdrxframes)
		delete x;
	m_ocdrxframes.clear();

	//Get ready to do OCD operations
	//We want to enter SHIFT-DR and stay there
	SetOCDInstruction();
	m_iface->EnterShiftDR();

	//Ask for the ID code (flush with a bunch of null words)
	m_ocdtxbuf.push_back(JTAG_FRAME_PREAMBLE);
	m_ocdtxbuf.push_back(JTAG_FRAME_TYPE_IDCODE << 29);	//length zero
														//sequence 0 to resynchronize
														//credits ignored from host to device
	for(int i=0; i<32; i++)
		m_ocdtxbuf.push_back(0);
	OCDPush();

	//Make sure we got the frame
	if(m_ocdrxframes.empty())
	{
		printf("    No OCD IDCODE packet found (waited for 32 data words)\n");
		ResetToIdle();	//don't leave bad jtag instruction if no virtual TAPs are present
		return;
	}

	//Verify it's well-formed
	AntikernelOCDFrame* frame = m_ocdrxframes[0];
	if(frame->m_type != JTAG_FRAME_TYPE_IDCODE)
		printf("    Invalid frame type %x on IDCODE packet\n", frame->m_type);
	else if(frame->m_data.size() != 1)
		printf("    Invalid frame length on IDCODE packet\n");
	else if(frame->m_data[0] != JTAG_FRAME_MAGIC)
		printf("    Invalid magic number on IDCODE packet\n");
	else
	{
		printf("    Valid NoC endpoint detected\n");
		m_bHasRPCInterface = true;
		m_bHasDMAInterface = true;
	}

	//Done
	m_ocdrxframes.erase(m_ocdrxframes.begin());
	delete frame;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RPC network stuff

bool XilinxFPGA::HasRPCInterface()
{
	return m_bHasRPCInterface;
}

unsigned int XilinxFPGA::GetActualCreditCount()
{
	//The available buffer space on the board is the credit count in this frame, minus the number of words sent
	//since that sequence number. One credit is required for the header, then N for N layer-2 data words. The preamble
	//does not use buffer space.

	unsigned int credits = m_credits;

	for(auto x : m_pendingSendCounts)
	{
		//If a packet is half processed, it may double-count.
		//During this time, bottom out at zero rather than going negative
		if(credits < x.second)
		{
			credits = 0;
			break;
		}
		else
			credits -= x.second;
	}

	return credits;
}

void XilinxFPGA::SendRPCMessage(const RPCMessage& tx_msg)
{
	//Keep trying until it goes through
	while(!SendRPCMessageNonblocking(tx_msg))
	{
		//Send a few nulls and try again
		for(int i=0; i<32; i++)
			m_ocdtxbuf.push_back(0);
		OCDPush();
	}
}

bool XilinxFPGA::SendRPCMessageNonblocking(const RPCMessage& tx_msg)
{
	//We need at least 5 credits (4 body + 1 header) free.
	if(GetActualCreditCount() < 5)
		return false;

	//Pack the message
	uint32_t tx_buf[4];
	tx_msg.Pack(tx_buf);

	//Make a note of the fact that this message has been sent
	m_pendingSendCounts.push_back(pair<int, int>(m_sequence, 5));

	//Push onto transmit buffer, but don't necessarily send immediately
	m_ocdtxbuf.push_back(JTAG_FRAME_PREAMBLE);
	m_ocdtxbuf.push_back((JTAG_FRAME_TYPE_RPC << 29) | (4 << 19) | ( (m_sequence++) << 11) ); //credits zero for now
	for(size_t i=0; i<4; i++)
		m_ocdtxbuf.push_back(tx_buf[i]);

	//If send buffer is big, flush immediately
	//if(m_ocdtxbuf.size() > 300)
	//	OCDPush();

	return true;
}

bool XilinxFPGA::RecvRPCMessage(RPCMessage& rx_msg)
{
	//If nothing to receive, send a couple of nulls and try again
	if(m_ocdrxframes.empty())
	{
		for(int i=0; i<16; i++)
			m_ocdtxbuf.push_back(0);
		OCDPush();
	}

	//Check the FIFO
	for(size_t i=0; i<m_ocdrxframes.size(); i++)
	{
		auto frame = m_ocdrxframes[i];
		if(frame->m_type != JTAG_FRAME_TYPE_RPC)
			continue;

		rx_msg.Unpack(frame->m_data.data());

		//Done
		delete frame;
		m_ocdrxframes.erase(m_ocdrxframes.begin() + i);
		return true;
	}

	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DMA network stuff

bool XilinxFPGA::HasDMAInterface()
{
	return m_bHasDMAInterface;
}

void XilinxFPGA::SendDMAMessage(const DMAMessage& tx_msg)
{
	//Keep trying until it goes through
	while(!SendDMAMessageNonblocking(tx_msg))
	{
		//Send a few nulls and try again
		for(int i=0; i<32; i++)
			m_ocdtxbuf.push_back(0);
		OCDPush();
	}
}

bool XilinxFPGA::SendDMAMessageNonblocking(const DMAMessage& tx_msg)
{
	//We need at least N+4 credits (JTAG header word, NoC header word, two DMA header words, then data)
	if(GetActualCreditCount() < (tx_msg.len + 4U))
		return false;

	//Pack the message
	uint32_t tx_buf[515];
	tx_msg.Pack(tx_buf);

	//Make a note of the fact that this message has been sent
	unsigned int wlen = tx_msg.len + 3;
	m_pendingSendCounts.push_back(pair<int, int>(m_sequence, wlen));

	//Push onto transmit buffer, but don't necessarily send immediately
	m_ocdtxbuf.push_back(JTAG_FRAME_PREAMBLE);
	m_ocdtxbuf.push_back((JTAG_FRAME_TYPE_DMA << 29) | (wlen << 19) | ( (m_sequence++) << 11) ); //credits zero for now
	for(size_t i=0; i<wlen; i++)
		m_ocdtxbuf.push_back(tx_buf[i]);

	//If send buffer is big, flush immediately
	//if(m_ocdtxbuf.size() > 300)
	//	OCDPush();

	//Return true if there are sufficient credits, since we buffer internally
	return true;
}

bool XilinxFPGA::RecvDMAMessage(DMAMessage& rx_msg)
{
	//If nothing to receive, send a couple of nulls and try again
	if(m_ocdrxframes.empty())
	{
		for(int i=0; i<16; i++)
			m_ocdtxbuf.push_back(0);
		OCDPush();
	}

	//Check the FIFO
	for(size_t i=0; i<m_ocdrxframes.size(); i++)
	{
		auto frame = m_ocdrxframes[i];
		if(frame->m_type != JTAG_FRAME_TYPE_DMA)
			continue;

		rx_msg.Unpack(frame->m_data.data());

		//Done
		delete frame;
		m_ocdrxframes.erase(m_ocdrxframes.begin() + i);
		return true;
	}

	return false;
}
*/
