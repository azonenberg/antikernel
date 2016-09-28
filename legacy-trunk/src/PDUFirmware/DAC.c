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
	@brief Implementation of DAC API
 */

#include "PDUFirmware.h"

#include <PDUPeripheralInterface_opcodes_constants.h>

/**
	@brief Writes a channel of a DAC5573
	
	@param daddr		I2C address of the DAC
	@param chan			Channel number of the DAC
	@param code			The DAC code value
 */
void DACWrite(unsigned int daddr, unsigned int chan, unsigned int code)
{
	RPCMessage_t rmsg;
	
	int opcode = 0x10;
	opcode |= (chan << 1);
	
	RPCFunctionCall(g_periphAddr, PERIPH_I2C_SEND_START, 0, 0, 0, &rmsg);
	RPCFunctionCall(g_periphAddr, PERIPH_I2C_SEND_BYTE, daddr | I2C_WRITE, 0, 0, &rmsg);
	RPCFunctionCall(g_periphAddr, PERIPH_I2C_SEND_BYTE, opcode, 0, 0, &rmsg);	//7:6 = 00 = extended address bits
																				//5:4 = 01 = write to DAC output
																				//3   = 0  = unused
																				//2:1 = xx = channel number
																				//0   = 0  = not power down
	RPCFunctionCall(g_periphAddr, PERIPH_I2C_SEND_BYTE, code, 0, 0, &rmsg);		//Data byte
	RPCFunctionCall(g_periphAddr, PERIPH_I2C_SEND_BYTE, 0x00, 0, 0, &rmsg);		//Dummy byte
	RPCFunctionCall(g_periphAddr, PERIPH_I2C_SEND_STOP, 0, 0, 0, &rmsg);
}
