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
	@brief Implementation of XilinxSpartan3ADevice
 */
#include "jtaghal.h"
#include <stdio.h>
#include <memory.h>
#include "XilinxSpartan3ADevice.h"
#include "XilinxFPGABitstream.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Initializes this device
	
	@param arraysize	Array size from JTAG ID code
	@param rev			Revision number from JTAG ID code
	@param idcode		The ID code of this device
	@param iface		The JTAG adapter this device was discovered on
	@param pos			Position in the chain that this device was discovered
 */
XilinxSpartan3ADevice::XilinxSpartan3ADevice(
	unsigned int arraysize,
	unsigned int rev,
	unsigned int idcode,
	JtagInterface* iface,
	size_t pos)
: XilinxFPGA(idcode, iface, pos)
, m_arraysize(arraysize)
, m_rev(rev)
{
	m_irlength = 6;
}

/**
	@brief Empty virtual destructor
 */
XilinxSpartan3ADevice::~XilinxSpartan3ADevice()
{
}

/**
	@brief Factory method
 */
JtagDevice* XilinxSpartan3ADevice::CreateDevice(
	unsigned int arraysize,
	unsigned int rev,
	unsigned int idcode,
	JtagInterface* iface,
	size_t pos)
{
	switch(arraysize)
	{
	case SPARTAN3A_50A:
		return new XilinxSpartan3ADevice(arraysize, rev, idcode, iface, pos);
		
	default:
		throw JtagExceptionWrapper(
			"Unknown Spartan-3A device (ID code not in database)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
		//fprintf(stderr, "Unknown Spartan-3A device (arraysize=%x, rev=%x)!\n", arraysize, rev);
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Generic device information

string XilinxSpartan3ADevice::GetDescription()
{
	string devname = "(unknown Spartan-3A)";
	
	switch(m_arraysize)
	{
	case SPARTAN3A_50A:
		devname = "XC3S50A";
		break;
	default:
		throw JtagExceptionWrapper(
			"Unknown Spartan-3A device (ID code not in database)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	char srev[16];
	snprintf(srev, 15, "%u", m_rev);
	
	return string("Xilinx ") + devname + " stepping " + srev;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// FPGA-specific device properties

bool XilinxSpartan3ADevice::HasSerialNumber()
{
	return true;
}

int XilinxSpartan3ADevice::GetSerialNumberLength()
{
	return 8;
}

int XilinxSpartan3ADevice::GetSerialNumberLengthBits()
{
	return 57;
}

void XilinxSpartan3ADevice::GetSerialNumber(unsigned char* data)
{
	InternalErase();
	
	//Enter ISC mode (wipes configuration)
	ResetToIdle();
	SetIR(INST_ISC_ENABLE);
	
	//Read the DNA value
	SetIR(INST_ISC_DNA);
	unsigned char zeros[8] = {0x00};
	ScanDR(zeros, data, 57);
	
	//Done
	SetIR(INST_ISC_DISABLE);
}

bool XilinxSpartan3ADevice::IsProgrammed()
{
	XilinxSpartan3ADeviceStatusRegister statreg;
	statreg.word = ReadWordConfigRegister(S3A_CONFIG_REG_STAT);
	return statreg.bits.done;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Configuration

void XilinxSpartan3ADevice::Erase(bool bVerbose)
{
	ResetToIdle();
	InternalErase(bVerbose);
	SetIR(INST_BYPASS);
}

void XilinxSpartan3ADevice::InternalErase(bool bVerbose)
{
	//Load the JPROGRAM instruction to clear configuration memory
	if(bVerbose)
		printf("    Clearing configuration memory...\n");
	SetIR(INST_JPROGRAM);
	SendDummyClocks(32);
	
	//Poll status register until housecleaning is done
	XilinxSpartan3ADeviceStatusRegister statreg;
	int i;
	for(i=0; i<10; i++)
	{
		statreg.word = ReadWordConfigRegister(S3A_CONFIG_REG_STAT);
		if(statreg.bits.init_b)
			break;
			
		//wait 500ms
		usleep(500 * 1000);
	}
	if(i == 10) 
	{
		throw JtagExceptionWrapper(
			"INIT_B not high after 5 seconds, possible board fault",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
}

void XilinxSpartan3ADevice::Reboot()
{
	ResetToIdle();
	SetIR(INST_JPROGRAM);
	SetIR(INST_BYPASS);
}

FirmwareImage* XilinxSpartan3ADevice::LoadFirmwareImage(const unsigned char* data, size_t len, bool bVerbose)
{
	return static_cast<FirmwareImage*>(XilinxFPGA::ParseBitstreamCore(data, len, bVerbose));
}

void XilinxSpartan3ADevice::Program(FirmwareImage* image)
{
	//Should be an FPGA bitstream
	FPGABitstream* bitstream = dynamic_cast<FPGABitstream*>(image);
	if(bitstream == NULL)
	{
		throw JtagExceptionWrapper(
			"Invalid firmware image (not an FPGABitstream)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Verify the ID code matches the device we're plugged into
	//AND out the stepping number since this is irrelevant
	if((0x0fffffff & bitstream->idcode) != (0x0fffffff & m_idcode) )
	{
		//Print verbose error message
		//TODO: sprintf and put in the exception?
		JtagDevice* dummy = JtagDevice::CreateDevice(bitstream->idcode, NULL, 0);
		if(dummy != NULL)
		{
			printf("    You are attempting to program a \"%s\" with a bitstream meant for a \"%s\"\n",
				GetDescription().c_str(), dummy->GetDescription().c_str());
			delete dummy;
		}
		
		throw JtagExceptionWrapper(
			"Bitstream ID code does not match ID code of this device",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	printf("    Checking ID code... OK\n");
	
	//If the ID code check passes it's a valid Xilinx bitstream so go do stuff with it
	XilinxFPGABitstream* xbit = dynamic_cast<XilinxFPGABitstream*>(bitstream);
	if(xbit == NULL)
	{
		throw JtagExceptionWrapper(
			"Valid ID code but not a XilinxFPGABitstream",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	printf("    Using %s\n", xbit->GetDescription().c_str());

	//Make a copy of the bitstream with the proper byte ordering for the JTAG API
	unsigned char* flipped_bitstream = new unsigned char[xbit->raw_bitstream_len];
	memcpy(flipped_bitstream, xbit->raw_bitstream, xbit->raw_bitstream_len);
	FlipBitArray(flipped_bitstream, xbit->raw_bitstream_len);

	//Reset the scan chain
	ResetToIdle();	

	//Erase the configuration
	InternalErase();
	
	//Send the bitstream to the FPGA
	printf("    Loading new bitstream...\n");
	SetIR(INST_CFG_IN);
	ScanDR(flipped_bitstream, NULL, xbit->raw_bitstream_len * 8);
	
	//Start up the FPGA
	SetIR(INST_JSTART);
	SendDummyClocks(64);
	
	//Clean up
	delete[] flipped_bitstream;
	flipped_bitstream = NULL;
	
	//Get the status register and verify that configuration was successful
	XilinxSpartan3ADeviceStatusRegister statreg;
	statreg.word = ReadWordConfigRegister(S3A_CONFIG_REG_STAT);
	if(statreg.bits.done != 1 || statreg.bits.gwe != 1)
	{
		if(statreg.bits.crc_err)
		{
			throw JtagExceptionWrapper(
				"Configuration failed (CRC error)",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		else
		{
			PrintStatusRegister();
			throw JtagExceptionWrapper(
				"Configuration failed (unknown error)",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
	}
	
	ResetToIdle();
}

void XilinxSpartan3ADevice::PrintStatusRegister()
{
	XilinxSpartan3ADeviceStatusRegister statreg;
	statreg.word = ReadWordConfigRegister(S3A_CONFIG_REG_STAT);
	printf(	"    Status register is 0x%04x\n"
		"      CRC error         : %u\n"
		"      IDCODE error      : %u\n"
		"      DCM lock status   : %u\n"
		"      GTS_CFG_B status  : %u\n"
		"      GWE status        : %u\n"
		"      GHIGH status      : %u\n"
		"      VSEL pins         : %u\n"
		"      MODE pins         : %u\n"
		"      INIT_B pin        : %u\n"
		"      DONE pin          : %u\n"
		"      SEU error         : %u\n"
		"      Sync timeout      : %u\n",
		statreg.word,
		statreg.bits.crc_err,
		statreg.bits.idcode_err,
		statreg.bits.dcm_lock,
		statreg.bits.gts_cfg_b,
		statreg.bits.gwe,
		statreg.bits.ghigh,
		statreg.bits.vsel,
		statreg.bits.mode,
		statreg.bits.init_b,
		statreg.bits.done,
		statreg.bits.seu_err,
		statreg.bits.sync_timeout);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Internal configuration helpers

/**
	@brief Reads a single 32-bit word from a config register
	
	Note that Spartan-3A devices expect data clocked in MSB first but the JTAG API clocks data LSB first.
	Some swapping is required as a result.
	
	@throw JtagException if the read fails
	
	@param reg The configuration register to read
 */

uint32_t XilinxSpartan3ADevice::ReadWordConfigRegister(unsigned int reg)
{	
	//Send the read request
	SetIR(INST_CFG_IN);
	XilinxSpartan3ADeviceConfigurationFrame frames[] =
	{
		{ bits: {0, 0,					S3A_CONFIG_OP_NOP,		S3A_CONFIG_FRAME_TYPE_1} },	//Dummy word
		{ word: 0xaa99 },																	//Sync word
		{ bits: {1, reg, 				S3A_CONFIG_OP_READ,		S3A_CONFIG_FRAME_TYPE_1} },	//Read the register
		{ bits: {1, S3A_CONFIG_REG_CMD, S3A_CONFIG_OP_WRITE,	S3A_CONFIG_FRAME_TYPE_1} },	//Desync
		{ word: S3A_CMD_DESYNC															 },
		{ bits: {0, 0,   				S3A_CONFIG_OP_NOP,		S3A_CONFIG_FRAME_TYPE_1} },	//Flush pipeline
		{ bits: {0, 0,   				S3A_CONFIG_OP_NOP,		S3A_CONFIG_FRAME_TYPE_1} }
	};
	unsigned char* packet = (unsigned char*) frames;
	FlipBitAndEndianArray(packet, sizeof(frames));		//MSB needs to get sent first
	ScanDR(packet, NULL, sizeof(frames) * 8);
	
	//Read the data																	
	SetIR(INST_CFG_OUT);
	unsigned char unused[2] = {0};
	uint16_t reg_out = {0};
	ScanDR(unused, (unsigned char*)&reg_out, 16);
	FlipBitAndEndianArray((unsigned char*)&reg_out, 2);
	
	return reg_out;
}

/**
	@brief Reads several 16-bit words from a config register.
	
	The current implementation uses type 1 packets and is thus limited to reading less than 32 words.
	
	@throw JtagException if the read fails
	
	@param reg		The configuration register to read
	@param dout 	Buffer to read into
	@param count	Number of 16-bit words to read
 */
/*
void XilinxSpartan3ADevice::ReadWordsConfigRegister(unsigned int reg, uint16_t* dout, unsigned int count)
{
	if(count < 32)
	{
		//Send the read request
		SetIR(INST_CFG_IN);
		XilinxSpartan3ADeviceConfigurationFrame frames[] =
		{
			{ bits: {0,     0,   S6_CONFIG_OP_NOP,  S6_CONFIG_FRAME_TYPE_1} },	//Dummy word
			{ word: 0xaa99 },													//Sync word
			{ word: 0x5566 },
			{ bits: {count, reg, S6_CONFIG_OP_READ, S6_CONFIG_FRAME_TYPE_1} },	//Read the register
			{ bits: {0,     0,   S6_CONFIG_OP_NOP,  S6_CONFIG_FRAME_TYPE_1} },	//Two dummy words required
			{ bits: {0,     0,   S6_CONFIG_OP_NOP,  S6_CONFIG_FRAME_TYPE_1} }
		};
		unsigned char* packet = (unsigned char*) frames;
		FlipBitAndEndianArray(packet, sizeof(frames));			//MSB needs to get sent first
		ScanDR(packet, NULL, sizeof(frames) * 8);								//Table 6-5 of UG380 v2.4 says we need 160 clocks
																				//but it seems we only need 80. See WebCase 948541
			
		//Read the data																	
		SetIR(INST_CFG_OUT);
		unsigned char unused[32];
		ScanDR(unused, (unsigned char*)dout, count*16);
		FlipBitAndEndianArray((unsigned char*)dout, count*2);
	}
	
	else
	{
		//TODO: use type 2 read
		throw JtagExceptionWrapper(
			"ReadWordsConfigRegister() not implemented for count>32",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
}
*/
//void XilinxSpartan3ADevice::WriteWordConfigRegister(unsigned int /*reg*/, uint16_t /*value*/)
/*{
	throw JtagExceptionWrapper(
		"WriteWordConfigRegister() not implemented",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Bitstream parsing
*/
XilinxFPGABitstream* XilinxSpartan3ADevice::ParseBitstreamInternals(
	const unsigned char* data,
	size_t len,
	XilinxFPGABitstream* bitstream,
	size_t fpos,
	bool bVerbose)
{
	if(bVerbose)
	{
		printf("Parsing bitstream internals...\n");
		printf("    Using %s\n", bitstream->GetDescription().c_str());
	}
	
	//Expect aa 99 (sync word). Note that this is not the full aa 99 55 66 sync word used in Spartan-6 and later.
	unsigned char syncword[2] = {0xaa, 0x99};
	if(0 != memcmp(data+fpos, syncword, sizeof(syncword)))
	{
		delete bitstream;
		throw JtagExceptionWrapper(
			"No valid sync word found",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Allocate space and copy the entire bitstream into raw_bitstream
	bitstream->raw_bitstream_len = len-fpos;
	bitstream->raw_bitstream = new unsigned char[bitstream->raw_bitstream_len];
	memcpy(bitstream->raw_bitstream, data+fpos, bitstream->raw_bitstream_len);
	
	//Skip the sync word
	//size_t start = fpos;
	fpos += sizeof(syncword);
	
	//String names for config regs
	static const char* config_register_names[]=
	{
		"CRC",
		"FAR_MAJ",
		"FAR_MIN",
		"FDRI",
		"FDRO",
		"CMD",
		"CTL",
		"MASK",
		"STAT",
		"LOUT",
		"COR1",
		"COR2",
		"PWRDN",
		"FLR",
		"IDCODE",
		"SNOWPLOW",
		"HC_OPT",
		"RESERVED_0x11",
		"CSB0",
		"GENERAL1",
		"GENERAL2",
		"MODE_REG",
		"PU_GWE",
		"PU_GTS",
		"MFWR",
		"CCLK_FREQ",
		"SEU_OPT",
		"EXP_SIGN",
		"RDBK_SIGN"
	};
	
	static const char* config_opcodes[]=
	{
		"NOP",
		"READ",
		"WRITE",
		"INVALID"
	};
	
	static const char* cmd_values[]=
	{
		"NULL",
		"WCFG",
		"MFWR",
		"LFRM",
		"RCFG",
		"START",
		"RCAP",
		"RCRC",
		"AGHIGH",
		"UNDOCUMENTED_9",
		"GRESTORE",
		"SHUTDOWN",
		"GCAPTURE",
		"DESYNC",
		"REBOOT",
		"UNDOCUMENTED_F"
	};
	
	//Parse frames
	while(fpos < len)
	{	
		//Pull and byte-swap the frame header
		XilinxSpartan3ADeviceConfigurationFrame frame = 
			*reinterpret_cast<const XilinxSpartan3ADeviceConfigurationFrame*>(data + fpos);
		FlipEndianArray((unsigned char*)&frame, sizeof(frame));
		
		//Skip nops, dont print details
		if(frame.bits.op == S3A_CONFIG_OP_NOP)
		{
			//printf("NOP at 0x%x\n", (int)fpos);
			fpos += 2;
			continue;
		}
		
		//Validate frame
		if(frame.bits.reg_addr >= S3A_CONFIG_REG_MAX)
		{
			printf("[XilinxSpartan3ADevice] Invalid register address 0x%x in config frame at bitstream offset %02x\n",
				frame.bits.reg_addr, (int)fpos);
			delete bitstream; 	
			throw JtagExceptionWrapper(
				"Invalid register address in bitstream",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Print stats
		if(bVerbose)
		{
			printf("    Config frame starting at 0x%x: Type %u %s to register 0x%02x (%s), ",
				static_cast<unsigned int>(fpos),
				frame.bits.type,
				config_opcodes[frame.bits.op],
				frame.bits.reg_addr,
				config_register_names[frame.bits.reg_addr]
				);
		}
	
		//Go past the header
		fpos += 2;
		
		//Look at the frame type and process it
		if(frame.bits.type == S3A_CONFIG_FRAME_TYPE_1)
		{
			//Type 1 frame
			if(bVerbose)
				printf("%u words\n", frame.bits.count);
			
			//See if it's a write, if so pull out some data
			if(frame.bits.op == S3A_CONFIG_OP_WRITE)
			{
				//Look at the frame data
				switch(frame.bits.reg_addr)
				{
					case S3A_CONFIG_REG_CMD:
					{
						//Expect 1 word
						if(frame.bits.count != 1)
						{
							delete bitstream; 
							throw JtagExceptionWrapper(
								"Invalid write (not 1 word) to CMD register in config frame",
								"",
								JtagException::EXCEPTION_TYPE_GIGO);
						}
						
						uint16_t cmd_value = GetBigEndianUint16FromByteArray(data, fpos);
						if(bVerbose)
						{
							if(cmd_value > 16)
								printf("        Invalid command value");
							else
								printf("        Command = %s\n", cmd_values[cmd_value]);
						}
						
						//We're done, skip to the end of the bitstream
						if(cmd_value == S3A_CMD_DESYNC)
						{
							fpos = len;
							continue;
						}

					}
					break;
					
					case S3A_CONFIG_REG_IDCODE:
					{
						//Expect 2 words
						if(frame.bits.count != 2)
						{
							delete bitstream;
							throw JtagExceptionWrapper(
								"Invalid write (not 1 word) to IDCODE register in config frame",
								"",
								JtagException::EXCEPTION_TYPE_GIGO);
						}
						
						//Pull the value
						uint16_t idcode_hi = GetBigEndianUint16FromByteArray(data, fpos);
						uint16_t idcode_lo = GetBigEndianUint16FromByteArray(data, fpos+2);
						uint32_t idcode = (idcode_hi << 16) | idcode_lo;
						if(bVerbose)
							printf("        ID code = %08x\n", idcode);
						bitstream->idcode = idcode;
					}
					break;
					
					case S3A_CONFIG_REG_CRC:
					{
						//Expect 2 words
						if(frame.bits.count != 2)
						{
							delete bitstream;
							throw JtagExceptionWrapper(
								"Invalid write (not 2 word) to CRC register in config frame",
								"",
								JtagException::EXCEPTION_TYPE_GIGO);
						}
						
						//Pull the value
						uint16_t crc_hi = GetBigEndianUint16FromByteArray(data, fpos);
						uint16_t crc_lo = GetBigEndianUint16FromByteArray(data, fpos+2);
						uint32_t crc = (crc_hi << 16) | crc_lo;
						if(bVerbose)
							printf("        CRC = %08x\n", crc);
					}
					break;

					default:
						if(frame.bits.count == 1)
						{
							if(bVerbose)
								printf("        Value = %x\n", GetBigEndianUint16FromByteArray(data, fpos));							
						}
						else if(frame.bits.count == 2)
						{
							//Pull the value
							uint16_t value_hi = GetBigEndianUint16FromByteArray(data, fpos);
							uint16_t value_lo = GetBigEndianUint16FromByteArray(data, fpos+2);
							uint32_t value = (value_hi << 16) | value_lo;
							if(bVerbose)
								printf("        Value = %08x\n", value);
						}
					break;
					
				}
			}
			
			//Discard the contents
			fpos += 2*frame.bits.count;
		}
		else if(frame.bits.type == S3A_CONFIG_FRAME_TYPE_2)
		{
			//Type 2 frame - not implemented		
			//Get the size (32 bits)
			uint16_t framesize_hi = GetBigEndianUint16FromByteArray(data, fpos);
			uint16_t framesize_lo = GetBigEndianUint16FromByteArray(data, fpos+2);
			uint32_t framesize = (framesize_hi << 16) | framesize_lo;
			fpos += 4;
			if(bVerbose)
				printf("%d words\n", framesize);
			
			//Discard the contents
			fpos += 2*framesize;
		}
		else
		{
			delete bitstream; 
			throw JtagExceptionWrapper(
				"Invalid frame type",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
	}
	
	//All OK
	return bitstream;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// General NoC support stuff

void XilinxSpartan3ADevice::SetOCDInstruction()
{
	SetIRDeferred(INST_USER1);
}
