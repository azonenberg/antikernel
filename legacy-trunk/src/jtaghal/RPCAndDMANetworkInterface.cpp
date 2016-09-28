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
	@brief Implementation of RPCAndDMANetworkInterface
 */

#include "jtaghal.h"
#include "RPCNetworkInterface.h"
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>
#include <DMARouter_constants.h>

using namespace std;

RPCAndDMANetworkInterface::~RPCAndDMANetworkInterface()
{
	
}

/**
	@brief Performs a function call through the RPC network.
	
	Do not use directly, use RPCFunctionCall() or RPCFunctionCallWithTimeout() instead
	
	@throw JtagException if a message send fails, the call fails, or the call times out.
	
	@param addr		Address of target node
	@param callnum	The RPC function to call
	@param callname	String description for callnum (used in error messages)
	@param d0		First argument (only low 21 bits valid)
	@param d1		Second argument
	@param d2		Third argument
	@param retval	Return value of the function
	@param timeout	Time to wait for a response
 */
void RPCAndDMANetworkInterface::RPCFunctionCallInternal(
	uint16_t addr, uint8_t callnum, const char* callname, uint32_t d0, uint32_t d1, uint32_t d2,
	RPCMessage& retval, float timeout)
{
	//Send the call request
	RPCMessage msg;
	msg.from = 0x0000;
	msg.to = addr;
	msg.type = RPC_TYPE_CALL;
	msg.callnum = callnum;
	msg.data[0] = d0;
	msg.data[1] = d1;
	msg.data[2] = d2;
	SendRPCMessage(msg);
	
	while(true)
	{
		//Wait for the response
		if(!RecvRPCMessageBlockingWithTimeout(retval, timeout))
		{
			throw JtagExceptionWrapper(
				string("Timed out waiting for response to RPC call ") + callname,
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);	
		}
		
		//Process the message
		switch(retval.type)
		{
			
		//Save interrupts for future processing
		case RPC_TYPE_INTERRUPT:
			pending_interrupts.push_back(retval);
			continue;
			
		//Success? We're done if it's from the destination
		//We should not get unsolicited success messages from strangers, warn if that happens
		case RPC_TYPE_RETURN_SUCCESS:
			if(retval.from != addr)
			{
				printf("WARNING: RPCAndDMANetworkInterface::RPCFunctionCallInternal() waiting for return from %04x (for %s), got return success from %04x\n",
					addr, callname, retval.from);
			}
			else
				return;
			break;
			
		//Fail? We fail no matter where it came from
		case RPC_TYPE_RETURN_FAIL:
		
			if(retval.from != addr)
			{
				printf("WARNING: RPCAndDMANetworkInterface::RPCFunctionCallInternal() waiting for return from %04x (for %s), got return fail from %04x\n",
					addr, callname, retval.from);
			}
			else
			{
				//TODO: Optional print flag?
				//printf("    Got: %s\n", retval.Format().c_str());
				
				throw JtagExceptionWrapper(
					string("RPC call ") +  callname + " failed",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
			break;
			
		//Retry? Send the message again
		//We should not get unsolicited retry messages from strangers, warn if that happens
		case RPC_TYPE_RETURN_RETRY:
			if(retval.from != addr)
			{
				//printf("    Got: %s\n", retval.Format().c_str());
				throw JtagExceptionWrapper(
					"Got unexpected message",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
			SendRPCMessage(msg);
			break;
			
		//Call? Save it
		case RPC_TYPE_CALL:
			pending_function_calls.push_back(msg);
			break;
		
		//Unknown type? Something is wrong
		default:
			throw JtagExceptionWrapper(
				"Got RPC message of invalid / reserved type",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}		
	}
}

/**
	@brief Performs a bulk write through the DMA network
	
	@param addr					The NoC address to send the write to
	@param mem_addr				The physical memory to write to within the target host's address space
	@param len					Length, in words, of the data to write
	@param data					The data to write
	@param success_interrupt	Interrupt indicating the write has completed successfully
	@param fail_interrupt		Interrupt indicating the write has failed
 */
void RPCAndDMANetworkInterface::DMAWrite(uint16_t addr, uint32_t mem_addr, unsigned int len, uint32_t* data, uint8_t success_interrupt, uint8_t fail_interrupt)
{
	//Send the message
	DMAMessage msg;
	msg.from = 0;
	msg.to = addr;
	msg.address = mem_addr;
	msg.len = len;
	msg.opcode = DMA_OP_WRITE_REQUEST;
	memset(msg.data,  0, sizeof(msg.data));
	for(unsigned int i=0; i<len; i++)
		msg.data[i] = data[i];
	SendDMAMessage(msg);
	
	//Do not check pending interrupts
	//There's no way we can get the acknowledgement before the original message is sent!
	float timeout = 0.5;
	double tend = GetTime() + timeout;
	while(true)
	{
		//Timeout check
		if(GetTime() > tend)
		{
			throw JtagExceptionWrapper(
				"Timed out waiting for response to DMA write",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);	
		}
		
		//Wait for the response
		RPCMessage rmsg;
		if(!RecvRPCMessage(rmsg))
			continue;
		
		//Process the message
		switch(rmsg.type)
		{
		case RPC_TYPE_INTERRUPT:
			
			//Interrupt from any other source gets saved
			if(rmsg.from != addr)
				pending_interrupts.push_back(rmsg);
				
			//If success, we're done
			else if(rmsg.callnum == success_interrupt)
				return;
				
			//Fail? Die
			else if(rmsg.callnum == fail_interrupt)
			{
				throw JtagExceptionWrapper(
					"DMA write failed",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);	
			}
			
			//Unknown interrupt from the same host, just buffer it
			else
				pending_interrupts.push_back(rmsg);
				
			break;
			
		//Call? Save it
		case RPC_TYPE_CALL:
			pending_function_calls.push_back(rmsg);
			break;
			
		//We should not get unsolicited success messages from strangers, warn if that happens
		case RPC_TYPE_RETURN_SUCCESS:
			printf("WARNING: RPCAndDMANetworkInterface::DMAWrite() waiting for DMA ack from %04x, got return success from %04x\n",
				addr, rmsg.from);
			break;
		case RPC_TYPE_RETURN_FAIL:
			printf("WARNING: RPCAndDMANetworkInterface::DMAWrite() waiting for DMA ack from %04x, got return fail from %04x\n",
				addr, rmsg.from);
			break;
		case RPC_TYPE_RETURN_RETRY:
			printf("WARNING: RPCAndDMANetworkInterface::DMAWrite() waiting for DMA ack from %04x, got return retry from %04x\n",
				addr, rmsg.from);
			break;
		
		//Unknown type? Something is wrong
		default:
			throw JtagExceptionWrapper(
				"Got RPC message of invalid / reserved type",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
			break;
		}		
	}
}

/**
	@brief Performs a bulk read through the DMA network
	
	@param addr					The NoC address to send the read to
	@param mem_addr				The physical memory to read to within the target host's address space
	@param len					Length, in words, of the data to read
	@param data					Buffer to read to (must be >=512 words in size)
	@param fail_interrupt		Interrupt indicating the read has failed
 */
void RPCAndDMANetworkInterface::DMARead(uint16_t addr, uint32_t mem_addr, unsigned int len, uint32_t* data, uint8_t fail_interrupt, float timeout)
{
	//Send the message
	DMAMessage msg;
	msg.from = 0;
	msg.to = addr;
	msg.address = mem_addr;
	msg.len = len;
	msg.opcode = DMA_OP_READ_REQUEST;
	memset(msg.data,  0, sizeof(msg.data));
	SendDMAMessage(msg);
	
	//Do not check pending interrupts
	//There's no way we can get the acknowledgement before the original message is sent!
	double tend = GetTime() + timeout;
	while(true)
	{
		//Timeout check
		if(GetTime() > tend)
		{
			throw JtagExceptionWrapper(
				"Timed out waiting for response to DMA read",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);	
		}
		
		//Check for DMA messages
		DMAMessage dmsg;
		if(RecvDMAMessage(dmsg))
		{
			//The message must be the read data
			//TODO: Process other messages?
			if( (dmsg.from != addr) || (dmsg.opcode != DMA_OP_READ_DATA) )
			{
				throw JtagExceptionWrapper(
					"Got unexpected message",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
			
			//Good, return it
			for(unsigned int i=0; i<len; i++)
				data[i] = dmsg.data[i];
			return;
		}
		
		//Check for RPC messages
		RPCMessage rmsg;
		if(RecvRPCMessage(rmsg))
		{
			switch(rmsg.type)
			{
			case RPC_TYPE_INTERRUPT:
				
				//Interrupt from any other source gets saved
				if(rmsg.from != addr)
					pending_interrupts.push_back(rmsg);
					
				//Fail? Die
				else if(rmsg.callnum == fail_interrupt)
				{
					throw JtagExceptionWrapper(
						"DMA read failed",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);	
				}
				
				//Unknown interrupt from the same host, just buffer it
				else
					pending_interrupts.push_back(rmsg);
					
				break;
				
			//Call? Save it
			case RPC_TYPE_CALL:
				pending_function_calls.push_back(rmsg);
				break;
				
			//We should not get unsolicited success messages from strangers, warn if that happens
			case RPC_TYPE_RETURN_SUCCESS:
				printf("WARNING: RPCAndDMANetworkInterface::DMARead() waiting for DMA ack from %04x, got return success from %04x\n",
					addr, rmsg.from);
				break;
			case RPC_TYPE_RETURN_FAIL:
				printf("WARNING: RPCAndDMANetworkInterface::DMARead() waiting for DMA ack from %04x, got return fail from %04x\n",
					addr, rmsg.from);
				break;
			case RPC_TYPE_RETURN_RETRY:
				printf("WARNING: RPCAndDMANetworkInterface::DMARead() waiting for DMA ack from %04x, got return retry from %04x\n",
					addr, rmsg.from);
				break;
			
			//Unknown type? Something is wrong
			default:
				throw JtagExceptionWrapper(
					"Got RPC message of invalid / reserved type",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
				break;
			}
		}
	}
}

/**
	@brief Blocking wait until an interrupt from the specified address is received.
	
	@param	addr	The address to read from
	@param	retval	The interrupt message
	@param	timeout	Timeout
 */
void RPCAndDMANetworkInterface::WaitForInterruptFrom(uint16_t addr, RPCMessage& retval, float timeout)
{
	//Check existing queued interrupts
	//Woo c++ 11!
	for(auto it = pending_interrupts.begin(); it != pending_interrupts.end(); it++)
	{
		const RPCMessage& msg = *it;
		if(msg.from == addr)
		{
			retval = msg;
			pending_interrupts.erase(it);
			return;
		}
	}
	
	//Not in the queue
	//Block until it arrives
	double tend = GetTime() + timeout;
	while(true)
	{
		//Timeout check
		if(GetTime() > tend)
		{
			throw JtagExceptionWrapper(
				"Timed out waiting for interrupt",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);	
		}
		
		//Check for RPC messages
		RPCMessage rmsg;
		if(RecvRPCMessage(rmsg))
		{
			switch(rmsg.type)
			{
			case RPC_TYPE_INTERRUPT:
				
				//Interrupt from any other source gets saved
				if(rmsg.from != addr)
					pending_interrupts.push_back(rmsg);
					
				else
				{
					retval = rmsg;
					return;
				}
				break;
				
			//Call? Save it
			case RPC_TYPE_CALL:
				pending_function_calls.push_back(rmsg);
				break;
				
			//We should not get unsolicited success messages from strangers, warn if that happens
			case RPC_TYPE_RETURN_SUCCESS:
				printf("WARNING: RPCAndDMANetworkInterface::WaitForInterruptFrom() waiting for interrupt from %04x, got return success from %04x\n",
					addr, rmsg.from);
				break;
			case RPC_TYPE_RETURN_FAIL:
				printf("WARNING: RPCAndDMANetworkInterface::WaitForInterruptFrom() waiting for interrupt from %04x, got return fail from %04x\n",
					addr, rmsg.from);
				break;
			case RPC_TYPE_RETURN_RETRY:
				printf("WARNING: RPCAndDMANetworkInterface::WaitForInterruptFrom() waiting for interrupt from %04x, got return retry from %04x\n",
					addr, rmsg.from);
				break;
			
			//Unknown type? Something is wrong
			default:
				throw JtagExceptionWrapper(
					"Got RPC message of invalid / reserved type",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
				break;
			}
		}
		
		usleep(100);
	}
}
