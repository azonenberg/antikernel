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
	@brief Helpers related to RPC function calls
 */

#include <rpc.h>

void PushInterrupt(RPCMessage_t* msg);

/**
	@brief Performs a function call through the RPC network.
	
	@param addr		Address of target node
	@param callnum	The RPC function to call
	@param d0		First argument (only low 21 bits valid)
	@param d1		Second argument
	@param d2		Third argument
	@param retval	Return value of the function
	
	@return zero on success, -1 on failure
 */
int RPCFunctionCall(
	unsigned int addr, 
	unsigned int callnum,
	unsigned int d0,
	unsigned int d1,
	unsigned int d2,
	RPCMessage_t* retval)
{
	//Send the query
	RPCMessage_t msg;
	msg.from = 0;
	msg.to = addr;
	msg.type = RPC_TYPE_CALL;
	msg.callnum = callnum;
	msg.data[0] = d0;
	msg.data[1] = d1;
	msg.data[2] = d2;
	SendRPCMessage(&msg);
	
	//Wait for a response
	while(1)
	{
		//Get the message
		RecvRPCMessage(retval);
		
		//Ignore anything not from the host of interest; save for future processing
		if(retval->from != addr)
		{
			//TODO: Support saving function calls / returns
			//TODO: Support out-of-order function call/return structures
			if(retval->type == RPC_TYPE_INTERRUPT)
				PushInterrupt(retval);
			continue;
		}
			
		//See what it is
		switch(retval->type)
		{
			//Send it again
			case RPC_TYPE_RETURN_RETRY:
				SendRPCMessage(&msg);
				break;
				
			//Fail
			case RPC_TYPE_RETURN_FAIL:
				return -1;
				
			//Success, we're done
			case RPC_TYPE_RETURN_SUCCESS:
				return 0;
				
			//We're not ready for interrupts, save them
			case RPC_TYPE_INTERRUPT:
				PushInterrupt(retval);
				break;
				
			default:
				break;
		}

	}
}
