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
	@brief RPC network API
 */
#ifndef rpc_h
#define rpc_h

#include <RPCv2Router_type_constants.h>

#ifdef _cplusplus 
extern "C" 
{
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Layer 2 API

/**
	An RPC message (unpacked for faster manipulation)
 */
typedef struct RPCMessage_t
{
	//Word 0
	unsigned int from;
	unsigned int to;
	
	//Word 1
	unsigned int callnum;
	unsigned int type;
	
	//Words 1-2-3
	unsigned int data[3];

} RPCMessage_t;

void SendRPCMessage(RPCMessage_t* msg);
void RecvRPCMessage(RPCMessage_t* msg);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Layer 3 API

int RPCFunctionCall(
	unsigned int addr, 
	unsigned int callnum,
	unsigned int d0,
	unsigned int d1,
	unsigned int d2,
	RPCMessage_t* retval);

void GetRPCInterrupt(RPCMessage_t* msg);

void SendRPCInterrupt(
	unsigned int addr, 
	unsigned int callnum,
	unsigned int d0,
	unsigned int d1,
	unsigned int d2);

void InterruptQueueInit();

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Layer 4 API

#define NAMESERVER_ADDR 0x8000

#define INVALID_HOST 0xffffffff

unsigned int LookupHostByName(const char* hostname);

int RegisterHost(const unsigned int* hostname, const unsigned int* signature);

#ifdef _cplusplus
}
#endif

#endif
