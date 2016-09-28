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
	@brief Implementation of API for A-D converter
 */

#include "PDUFirmware.h"
#include <NOCSysinfo_constants.h>
#include <PDUPeripheralInterface_opcodes_constants.h>

void ADCInitialize()
{
	//SPI clock = 250 KHz
	RPCMessage_t rmsg;
	RPCFunctionCall(g_sysinfoAddr, SYSINFO_GET_CYCFREQ, 0, 250 * 1000, 0, &rmsg);
	int spiclk = rmsg.data[1];
	for(unsigned int i=0; i<3; i++)
		RPCFunctionCall(g_periphAddr, PERIPH_SPI_SET_CLKDIV, spiclk, i, 0, &rmsg);
}

unsigned int ADCRead(unsigned char spi_channel, unsigned char adc_channel)
{
	//Get the actual sensor reading
	RPCMessage_t rmsg;
	unsigned char opcode = 0x30;
	opcode |= (adc_channel << 1);
	opcode <<= 1;
	RPCFunctionCall(g_periphAddr, PERIPH_SPI_ASSERT_CS, 0,		spi_channel, 0, &rmsg);
	RPCFunctionCall(g_periphAddr, PERIPH_SPI_SEND_BYTE, opcode,	spi_channel, 0, &rmsg);	//Three dummy bits first
																						//then request read of CH0
																						//(single ended)
	RPCFunctionCall(g_periphAddr, PERIPH_SPI_RECV_BYTE, 0, 		spi_channel, 0, &rmsg);	//Read first 8 data bits
	unsigned int d0 = rmsg.data[0];
	RPCFunctionCall(g_periphAddr, PERIPH_SPI_RECV_BYTE, 0,		spi_channel, 0, &rmsg);	//Read next 4 data bits
																						//followed by 4 garbage bits
	unsigned int d1 = rmsg.data[0];
	RPCFunctionCall(g_periphAddr, PERIPH_SPI_DEASSERT_CS, 0, 	spi_channel, 0, &rmsg);
	
	return ((d0 << 4) & 0xFF0) | ( (d1 >> 4) & 0xF);
}
