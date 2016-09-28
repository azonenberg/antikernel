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
	@brief Implementation of output stage API
 */

#include "PDUFirmware.h"
#include "Output.h"
#include <NOCSysinfo_constants.h>
#include <OutputStageController_opcodes_constants.h>

unsigned int g_outputStageAddr;
unsigned int g_currentLimits[10];
unsigned int g_inrushTimers[10];

//I2C addresses of various peripherals
#define DAC0_ADDR 0x98
#define DAC1_ADDR 0x9A
#define DAC2_ADDR 0x9C

void OutputInitialize()
{
	g_outputStageAddr = LookupHostByName("outputs");
	
	//Initialize each channel
	RPCMessage_t rmsg;
	for(unsigned int i=0; i<10; i++)
	{
		//Turn off output
		RPCFunctionCall(g_outputStageAddr, OUTSTAGE_POWER_STATE, i, 0, 0, &rmsg);
		
		//Set current limit to 50 mA
		//Do not use zero since a few mV of offset voltage in the INA199 could cause a false trip
		//before we even turn it on!
		OutputSetCurrentLimit(i, 50);
		
		//Set inrush limits for all channels to 1ms
		OutputSetInrushTime(i, 1);
	}
}

/**
	@brief Gets the status of an output channel
	
	0 = administratively down
	1 = up
	2 = error-disable
 */
unsigned int OutputGetStatus(unsigned char chnum)
{
	RPCMessage_t rmsg;
	RPCFunctionCall(g_outputStageAddr, OUTSTAGE_GET_STATUS, chnum, 0, 0, &rmsg);
	return rmsg.data[0];
}

/**
	@brief Sets the current limit for a single channel
	
	@param channel		Channel number (0-9)
	@param limit		Current limit, in mA
 */
void OutputSetCurrentLimit(unsigned int channel, unsigned int limit)
{
	if(channel > 9)
		return;
		
	//Clamp to 5A and save un-rounded limit
	if(limit > 5000)
		limit = 5000;
	g_currentLimits[channel] = limit;
	
	/**
		Fixed-point calculation of DAC code value
		
		5000 mA = full scale
	 */
	unsigned int code = (limit * 256) / 5000;
	
	//I2C address for each channel
	static const unsigned char dac_addr[10]=
	{
		DAC0_ADDR,	DAC0_ADDR,	DAC0_ADDR,	DAC0_ADDR,
		DAC1_ADDR,	DAC1_ADDR,	DAC1_ADDR,	DAC1_ADDR,
		DAC2_ADDR,	DAC2_ADDR
	};
	
	//Port number for each channel
	static const unsigned char chan_num[10]=
	{
		0, 1, 2, 3,
		0, 1, 2, 3,
		0, 1
	};
	
	//Do it
	DACWrite(dac_addr[channel], chan_num[channel], code);
}

/**
	@brief Sets the inrush timer for a given channel
 */
void OutputSetInrushTime(unsigned int channel, unsigned int ms)
{
	if(channel > 9)
		return;
	g_inrushTimers[channel] = ms;
	
	//Get clock cycles in 1ms
	RPCMessage_t rmsg;
	unsigned int inrush_hz = 1000;	//1ms
	RPCFunctionCall(g_sysinfoAddr, SYSINFO_GET_CYCFREQ, 0, inrush_hz, 0, &rmsg);
	unsigned int clocks_per_ms = rmsg.data[1];
	
	//Set the resulting delay in clock cycles
	RPCFunctionCall(g_outputStageAddr, OUTSTAGE_INRUSH_TIME, channel, ms*clocks_per_ms, 0, &rmsg);
}
