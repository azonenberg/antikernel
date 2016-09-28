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
	@brief Name-server helpers
 */

#include <rpc.h>
#include <NOCNameServer_constants.h>

/**
	@brief Looks up the address of a given host
	
	@param hostname The hostname to look up
	
	@return The address, or INVALID_HOST if not found
 */
unsigned int LookupHostByName(const char* hostname)
{
	//Pad hostname out to 8 characters with nulls
	char hostname_padded[8] = {0};
	for(int i=0; (i<8) && (hostname[i] != 0); i++)
		hostname_padded[i] = hostname[i];
	
	//Cast to unsigned and send
	const unsigned char* uhn = (const unsigned char*)hostname_padded;
	RPCMessage_t rmsg;
	if(0 != RPCFunctionCall(
		NAMESERVER_ADDR,
		NAMESERVER_FQUERY,
		0,
		(uhn[0] << 24) | (uhn[1] << 16) | (uhn[2] << 8) | (uhn[3]),
		(uhn[4] << 24) | (uhn[5] << 16) | (uhn[6] << 8) | (uhn[7]),
		&rmsg
		))
	{
		return INVALID_HOST;
	}
	
	return rmsg.data[0];
}

/**
	@brief Registers us with the name server
	
	@param hostname The hostname to register
	@param signature The signature of the signing message
	
	@return 0 if successful, nonzero if fail
 */
int RegisterHost(const unsigned int* hostname, const unsigned int* signature)
{
	//Get the mutex lock
	RPCMessage_t rmsg;
	if(0 != RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_LOCK, 0, 0, 0, &rmsg))
		return -1;
	
	//Send the signature to the name server
	for(int i=0; i<8; i+=2)
	{
		if(0 != RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_HMAC, i, signature[i], signature[i + 1], &rmsg))
			return -2;
	}
	
	//If all goes well, register us
	if(0 != RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_REGISTER, 0, hostname[0], hostname[1], &rmsg))
		return -3;
		
	//We're good to go
	return 0;
}
