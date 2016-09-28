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
	@brief Tests that a specific race condition in GRAFTON is fixed
 */

#include <grafton/grafton.h>
#include <rpc.h>

#include <NOCNameServer_constants.h>
#include <NOCSysinfo_constants.h>

int RaceConditionTest();

int main()
{
	RPCMessage_t rmsg;
	GetRPCInterrupt(&rmsg);
	unsigned int notify_addr = rmsg.from;
	
	//Send the debug messages
	SendRPCInterrupt(notify_addr, 1, 0, 0, 0);
	SendRPCInterrupt(notify_addr, 2, 0, 0, 0);
	
	//Get the serial number
	unsigned int sysinfo_addr = LookupHostByName("sysinfo");
	RPCFunctionCall(sysinfo_addr, SYSINFO_CHIP_SERIAL, 0, 0, 0, &rmsg);
	SendRPCInterrupt(notify_addr, 3, 0, rmsg.data[1], rmsg.data[2]);
	
	int i = RaceConditionTest();
	SendRPCInterrupt(notify_addr, 4, 0, i, 0);
	
	return 0;
}
