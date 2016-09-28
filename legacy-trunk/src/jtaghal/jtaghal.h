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
	@brief Main library include file
 */

#ifndef jtaghal_h
#define jtaghal_h

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Global config stuff

#include <config.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// System headers

#include <unistd.h>
#include <stdint.h>

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#ifdef _WINDOWS
#include <ws2tcpip.h>
#include <windows.h>
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// libc headers

#include <stdio.h>
#include <memory.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// libstdc++ headers

#include <map>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// File handle stuff

#ifdef _WINDOWS
	#define ZFILE_DESCRIPTOR HANDLE
#else
	#define ZFILE_DESCRIPTOR int
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Class includes

//Error handling
#include "JtagException.h"

//General helpers
#include "Mutex.h"
#include "Thread.h"
#include "Socket.h"

//GPIO interface classes
#include "GPIOInterface.h"

//JTAG interface classes
#include "JtagInterface.h"
#include "DigilentJtagInterface.h"
#include "FTDIJtagInterface.h"
#include "NetworkedJtagInterface.h"
#include "NocJtagInterface.h"

//Device classes
#include "FPGA.h"
#include "CPLD.h"

//Debugging stuff
#include "DebuggableDevice.h"
#include "DebuggerInterface.h"

//NoC classes
#include "RPCMessage.h"
#include "NameServer.h"
#include "NOCSwitchInterface.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Global functions

//Byte manipulation
extern "C" bool PeekBit(const unsigned char* data, int nbit);
extern "C" void PokeBit(unsigned char* data, int nbit, bool val);
extern "C" unsigned char FlipByte(unsigned char c);

//Array manipulation
extern "C" void FlipByteArray(unsigned char* data, int len);
extern "C" void FlipBitArray(unsigned char* data, int len);
extern "C" void FlipEndianArray(unsigned char* data, int len);
extern "C" void FlipEndian32Array(unsigned char* data, int len);
extern "C" void FlipBitAndEndianArray(unsigned char* data, int len);
extern "C" void FlipBitAndEndian32Array(unsigned char* data, int len);

extern "C" void MirrorBitArray(unsigned char* data, int bitlen);

//Performance measurement
extern "C" double GetTime();

#endif
