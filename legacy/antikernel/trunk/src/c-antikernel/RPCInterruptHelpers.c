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
	@brief Helpers related to RPC interrupts
 */

#include <grafton/grafton.h>
#include <rpc.h>
#include <stdio.h>
#include <string.h>

#define INTERRUPT_QUEUE_SIZE 32

void PushInterrupt(RPCMessage_t* msg);

/**
	@brief Circular queue of pending interrupts
 */
RPCMessage_t g_pendingInterrupts[INTERRUPT_QUEUE_SIZE];
int g_pendingInterruptCount;
int g_pendingInterruptRdPtr;
int g_pendingInterruptWrPtr;

/**
	@brief Clears the interrupt queue
 */
void InterruptQueueInit()
{
	g_pendingInterruptCount = 0;
	g_pendingInterruptRdPtr = 0;
	g_pendingInterruptWrPtr = 0;
}

/**
	@brief Pushes a new interrupt onto the queue
 */
void PushInterrupt(RPCMessage_t* msg)
{
	if(g_pendingInterruptCount == INTERRUPT_QUEUE_SIZE)
	{
		//queue is full, drop the message
		return;
	}
	
	g_pendingInterrupts[g_pendingInterruptWrPtr] = *msg;
	g_pendingInterruptWrPtr ++;
	if(g_pendingInterruptWrPtr == INTERRUPT_QUEUE_SIZE)
		g_pendingInterruptWrPtr = 0;
	g_pendingInterruptCount ++;
}

/**
	@brief Blocks until an RPC interrupt shows up
 */
void GetRPCInterrupt(RPCMessage_t* msg)
{
	//Pending interrupt? Return it
	if(g_pendingInterruptCount > 0)
	{
		*msg = g_pendingInterrupts[g_pendingInterruptRdPtr];
		
		g_pendingInterruptRdPtr ++;
		if(g_pendingInterruptRdPtr == INTERRUPT_QUEUE_SIZE)
			g_pendingInterruptRdPtr = 0;
			
		g_pendingInterruptCount --;
		return;
	}
	
	//Nope, wait for a new one to arrive
	while(1)
	{
		RecvRPCMessage(msg);
		if(msg->type == RPC_TYPE_INTERRUPT)
			return;
			
		//TODO: Save function calls / return
	}
}

/**
	@brief Sends an RPC interrupt
 */
void SendRPCInterrupt(
	unsigned int addr, 
	unsigned int callnum,
	unsigned int d0,
	unsigned int d1,
	unsigned int d2)
{
	//Send the query
	RPCMessage_t msg;
	msg.from = 0;
	msg.to = addr;
	msg.type = RPC_TYPE_INTERRUPT;
	msg.callnum = callnum;
	msg.data[0] = d0;
	msg.data[1] = d1;
	msg.data[2] = d2;
	SendRPCMessage(&msg);
}
