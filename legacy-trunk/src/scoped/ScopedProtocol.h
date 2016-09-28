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
	@brief Declaration of scoped protocol constants
 */

#ifndef ScopedProtocol_h
#define ScopedProtocol_h

enum ScopedOps
{
	//Send opcode, get a string back
	SCOPED_OP_GET_NAME,
	SCOPED_OP_GET_VENDOR,
	SCOPED_OP_GET_SERIAL,
	
	//Send opcode, get a uint16_t back
	SCOPED_OP_GET_CHANNELS,
	SCOPED_OP_GET_TRIGGER_MODE,
	
	//Send opcode and channel number as uint16_t, get a string back
	SCOPED_OP_GET_HWNAME,
	SCOPED_OP_GET_DISPLAYCOLOR,
	
	//Send opcode and channel number as uint16_t, get a uint16_t back
	SCOPED_OP_GET_CHANNEL_TYPE,
	
	//Commands with no data returned
	SCOPED_OP_ACQUIRE,
	SCOPED_OP_START,
	SCOPED_OP_START_SINGLE,
	SCOPED_OP_STOP,
	
	//Send opcode and channel number as uint16_t, get a uint32_t back
	SCOPED_OP_CAPTURE_DEPTH,
	
	//Send opcode and channel number as uint16_t, get N samples back
	SCOPED_OP_CAPTURE_DATA,
	
	//Send opcode and channel number as uint16_t, get an int64_t back
	SCOPED_OP_CAPTURE_TIMESCALE,
	
	//Placeholder
	SCOPED_OP_COUNT
};

#endif
