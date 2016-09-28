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
	@brief NetworkedUART loopback test
	
	Sends data to and from the UART over the DMA network and verifies correctness of the data.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/UART.h"
#include "../../src/jtagboards/jtagboards.h"

#include <NetworkedUART_constants.h>

#include <signal.h>

using namespace std;

int main(int argc, char* argv[])
{
	int err_code = 0;
	try
	{
		//Connect to the server
		string server;
		string tty;
		int port = 0;
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);
			
			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
			else if(s == "--tty")
				tty = argv[++i];
			else
			{
				printf("Unrecognized command-line argument \"%s\", expected --server or --port\n", s.c_str());
				return 1;
			}
		}
		if( (server == "") || (port == 0) )
		{
			throw JtagExceptionWrapper(
				"No server or port name specified",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}		
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Address lookup
		printf("Looking up address of UART\n");
		NameServer nameserver(&iface);
		uint16_t uaddr = nameserver.ForwardLookup("uart");
		printf("UART is at %04x\n", uaddr);
		
		//Connect to the UART
		const int baud = 115200;
		UART uart(tty, baud);
		
		//Set the baud rate
		//Return value is of no use, we just block until it returns so that we know it took effect
		printf("Setting baud rate to %d...\n", baud);
		RPCMessage rmsg;
		iface.RPCFunctionCall(uaddr, UART_SET_BAUD, baud, 0, 0, rmsg);
		printf("    UART reports baud rate divisor %d selected\n", rmsg.data[1]);

		DMAMessage msg;

		//Send the message
		char send_data[] = "Hello World";
		printf("Sending [via DMA]   : %s\n", send_data);
		msg.from = 0x0000;
		msg.to = uaddr;
		msg.opcode = DMA_OP_WRITE_REQUEST;
		msg.len = ceil(sizeof(send_data)/4.0f);
		msg.address = 0x00000000;
		strcpy((char*)msg.data, send_data);
		iface.SendDMAMessage(msg);
		
		//Read back and verify we got back the desired data
		printf("Reading back...\n");
		char rx_buf[sizeof(send_data)];
		uart.Read((unsigned char*)rx_buf, sizeof(send_data)-1);
		rx_buf[sizeof(send_data)-1] = 0;
		printf("Received [via UART] : %s\n", rx_buf);
		if(0 == strcmp(send_data, rx_buf))
			printf("Transmit check OK\n");
		else
		{
			throw JtagExceptionWrapper(
				"Bad data received",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Send test message to the UART
		char send_data_2[] = "Test Message";
		printf("Sending [via UART]  : %s\n", send_data_2);
		uart.Write((unsigned char*)send_data_2, strlen(send_data_2));
		
		//12 characters * 10 bits * 8.68us per bit = 1.04ms
		//Wait 2ms to be safe
		usleep(2 * 1000);
		
		//Flush the buffer and wait for the response
		printf("Flushing buffer...\n");
		iface.RPCFunctionCall(uaddr, UART_RX_START, 0, 0, 0, rmsg);
		unsigned int count = rmsg.data[0] & 0xFFFF;
		printf("UART has %u bytes in buffer\n", count);
		if(count != strlen(send_data_2))
		{
			throw JtagExceptionWrapper(
				"UART buffer size is wrong",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Issue a DMA read and wait for the response
		msg.opcode = DMA_OP_READ_REQUEST;
		msg.len = ceil(count / 4.0f);
		msg.address = 0x00000000;
		iface.SendDMAMessage(msg);
		if(!iface.RecvDMAMessageBlockingWithTimeout(msg, 0.5))
		{
			throw JtagExceptionWrapper(
				"Timeout while waiting for UART read data",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Sanity check headers
		if(msg.opcode != DMA_OP_READ_DATA)
		{
			throw JtagExceptionWrapper(
				"Expected read data, got something else",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		if(msg.from != uaddr)
		{
			throw JtagExceptionWrapper(
				"Expected data from UART, got something else",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		if(msg.len != ceil(strlen(send_data_2) / 4.0f))
		{
			throw JtagExceptionWrapper(
				"Response has bad length",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Sanity check data
		if(0 != memcmp(msg.data, send_data_2, strlen(send_data_2)))
		{
			throw JtagExceptionWrapper(
				"Bad data received",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		printf("OK\n");
		
		//Done
		printf("Cleaning up...\n");
		iface.RPCFunctionCall(uaddr, UART_RX_DONE, 0, 0, 0, rmsg);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
