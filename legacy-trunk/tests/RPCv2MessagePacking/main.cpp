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
	@brief RPCv2 message packing test
	
	Makes sure messages pack and unpack according to spec.
 */
#include <string>
#include "../../src/jtaghal/jtaghal.h"
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>

using namespace std;
 
int main()
{
	int err_code = 0;
	try
	{	
		//Generate a test message
		printf("Packing...\n");
		RPCMessage tx_msg;
		tx_msg.from = 0xabcd;
		tx_msg.to = 0xef01;
		tx_msg.callnum = 0xcc;
		tx_msg.type = RPC_TYPE_RETURN_FAIL;	//0x02
		tx_msg.data[0] = 0x123456;
		tx_msg.data[1] = 0x42414039;
		tx_msg.data[2] = 0x9090cd80;
		unsigned char temp_buf[16];
		tx_msg.Pack(temp_buf);
		for(int i=0; i<16; i++)
		{
			if( (i&3) == 0)
				printf("    ");
			printf("%02x ", temp_buf[i]);
			if( (i&3) == 3)
				printf("\n");
		}
		
		//Sanity check the packing
		if(
			(temp_buf[0] != 0xab) ||
			(temp_buf[1] != 0xcd) ||
			(temp_buf[2] != 0xef) ||
			(temp_buf[3] != 0x01) ||
			(temp_buf[4] != 0xcc) ||
			(temp_buf[5] != 0x52) ||
			(temp_buf[6] != 0x34) ||
			(temp_buf[7] != 0x56) ||
			(temp_buf[8] != 0x42) ||
			(temp_buf[9] != 0x41) ||
			(temp_buf[10] != 0x40) ||
			(temp_buf[11] != 0x39) ||
			(temp_buf[12] != 0x90) ||
			(temp_buf[13] != 0x90) ||
			(temp_buf[14] != 0xcd) ||
			(temp_buf[15] != 0x80)
			)
		{
			throw JtagExceptionWrapper(
				"Packed data mismatch",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Repack it
		printf("Unpacking...\n");
		RPCMessage rx_msg;
		rx_msg.Unpack(temp_buf);
		
		if(
			(rx_msg.from != tx_msg.from) || 
			(rx_msg.to != tx_msg.to) || 
			(rx_msg.callnum != tx_msg.callnum) || 
			(rx_msg.type != tx_msg.type) || 
			(rx_msg.data[0] != tx_msg.data[0]) || 
			(rx_msg.data[1] != tx_msg.data[1]) || 
			(rx_msg.data[2] != tx_msg.data[2])
			)
		{
			throw JtagExceptionWrapper(
				"Unpacked data mismatch",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		printf("OK\n");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	return err_code;
}
