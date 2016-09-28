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
	@brief Declaration of XilinxDevice
 */

#ifndef XilinxDevice_h
#define XilinxDevice_h

///JTAG ID code for Xilinx
#define IDCODE_XILINX				0x49

///JTAG family code for Spartan-3A
#define XILINX_FAMILY_SPARTAN3A  	0x11

///JTAG family code for Spartan-6
#define XILINX_FAMILY_SPARTAN6  	0x20

///JTAG family code for CoolRunner-II devices
///(both values are possible)
#define XILINX_FAMILY_CR2_A			0x36
#define XILINX_FAMILY_CR2_B			0x37

///JTAG family code for 7-series devices
#define XILINX_FAMILY_7SERIES		0x1b

#include "JtagDevice.h"

/**
	@brief Abstract base class for all Xilinx devices (FPGA, CPLD, flash, etc)
	
	\ingroup libjtaghal
 */
class XilinxDevice : public JtagDevice
{
public:
	XilinxDevice(unsigned int idcode, JtagInterface* iface, size_t pos);
	virtual ~XilinxDevice();

	static JtagDevice* CreateDevice(unsigned int idcode, JtagInterface* iface, size_t pos);
	
	//TODO: Move this to other class? Need to find a good spot for it
	static uint16_t GetBigEndianUint16FromByteArray(const unsigned char* data, size_t offset);
	static uint32_t GetBigEndianUint32FromByteArray(const unsigned char* data, size_t offset);
};

#endif

