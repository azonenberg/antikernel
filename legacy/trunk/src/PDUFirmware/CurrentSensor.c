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
	@brief Implementation of current sensor API
 */

#include "PDUFirmware.h"
#include <PDUPeripheralInterface_opcodes_constants.h>

unsigned int GetCurrent(unsigned char sensor)
{
	//Sanity check
	if(sensor > 9)
		sensor = 0;
		
	//Tables mapping sensor IDs to channel info
	static const unsigned char spi_channels[10] =
	{
		   0, 0, 0,
		1, 1, 1, 1,
		2, 2, 2
	};
	static const unsigned char adc_channels[10] =
	{
		   1, 2, 3,
		0, 1, 2, 3,
		0, 1, 2
	};
	unsigned char spi_channel = spi_channels[sensor];
	unsigned char adc_channel = adc_channels[sensor];
			
	/*
		Get the actual sensor reading and scale it
		
		Do conversions in fixed point
			ADC reading is out of 4096
			5A = full scale
			
			amps = (ticks*5)/4096
			milliamps = (ticks*5000)/4096
	 */
	return (ADCRead(spi_channel, adc_channel) * 5000) >> 12;
}
