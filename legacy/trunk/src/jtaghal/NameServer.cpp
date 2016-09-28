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
	@brief Implementation of NameServer
 */

#include "jtaghal.h"
#include "NameServer.h"
#include <memory.h>

//Only build Crypto++ on 64-bit Linux until we get multiarch sorted out (debian 8?)
#if (defined(__amd64__) && !defined(_WIN32) )
#include <cryptopp/sha.h>
#include <cryptopp/hmac.h>
#endif

#include <NOCNameServer_constants.h>
#include <RPCv2Router_type_constants.h>

using namespace std;

/**
	@brief Connects to the name server
	
	@throw JtagException if pif is null
	
	@param pif	Pointer to a valid RPC network interface
 */
NameServer::NameServer(RPCAndDMANetworkInterface* pif, std::string password)
: m_pif(pif)
{
	if(NULL == pif)
	{
		throw JtagExceptionWrapper(
			"Interface pointer is null",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	if(password == "")
		memset(m_hmacKey, 0, sizeof(m_hmacKey));
	else
	{
		#if (defined(__amd64__) && !defined(_WIN32) )
			CryptoPP::SHA512().CalculateDigest(m_hmacKey, (unsigned char*)password.c_str(), password.length());
		#else
			throw JtagExceptionWrapper(
				"Crypto++ support on platforms other than amd64 Linux isn't yet working",
				"",
				JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
		#endif
	}
}

/**
	@brief Dumps the entire name table from the device
	
	@throw JtagException if a scan operation fails
	
	@param bVerbose		Set to true for verbose debug output
 */
void NameServer::LoadHostnames(bool bVerbose)
{	
	//Loop over each entry in the address table and check
	for(int i=0; i<256; i++)
		LoadHostTableEntry(i, bVerbose);
}

/**
	@brief Dumps a single entry of the name table from the device.
	
	Must be called exactly 256 times with nstep in the range [0, 255] to load the whole table.
	
	@throw JtagException if a scan operation fails
	
	@param nstep		Step number (0 to 255)
	@param bVerbose		Set to true for verbose debug output
 */
void NameServer::LoadHostTableEntry(int nstep, bool bVerbose)
{
	RPCMessage msg;
	m_pif->RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_LIST, nstep, 0, 0, msg);
			
	if(msg.data[1] == 0)
	{
		//printf("    record %d is empty\n", nstep);
	}
	else
	{
		char hostname[9];
		memcpy(hostname, &msg.data[1], 8);
		FlipByteArray((unsigned char*)hostname, 4);
		FlipByteArray((unsigned char*)hostname+4, 4);
		hostname[8] = 0;
		
		int addr = msg.data[0] & 0xFFFF;
		
		string shost(hostname);
		m_forward_dns[shost] = addr;
		m_reverse_dns[addr] = shost;
		
		if(bVerbose)
			printf("    Address %04x = %s\n", addr, hostname);
	}
}

/**
	@brief Forward name lookup for NoC
	
	@throw JtagException if the hostname is not in the table
	
	@param name		Hostname of the desired core
	@return			The address of the core
 */
int NameServer::ForwardLookup(string name)
{
	//Return from cache if present
	//TODO: cache misses
	if(m_forward_dns.find(name) != m_forward_dns.end())
		return m_forward_dns[name];
	
	return ForwardLookupUncached(name);
}

/**
	@brief Forward name lookup for NoC, bypassing the cache
	
	@throw JtagException if the hostname is not in the table
	
	@param name		Hostname of the desired core
	@return			The address of the core
 */
int NameServer::ForwardLookupUncached(std::string name)
{
	//Generate the hostname string
	uint32_t hostname[2] = {0};
	unsigned char* chostname = reinterpret_cast<unsigned char*>(hostname);
	memcpy(chostname, name.c_str(), name.length());
	FlipByteArray(chostname, 4);
	FlipByteArray(chostname+4, 4);

	//Get the data
	RPCMessage msg;
	m_pif->RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_FQUERY, 0, hostname[0], hostname[1], msg);
	return msg.data[0] & 0xFFFF;
}

/**
	@brief Reverse name lookup for NoC
	
	@throw JtagException if the address is not in the table
	
	@param addr		Address of the desired core
	@return			The hostname of the core
 */
string NameServer::ReverseLookup(int addr)
{
	//Not in cache?
	if(m_reverse_dns.find(addr) == m_reverse_dns.end())
		return ReverseLookupUncached(addr);
		
	//Cached as a miss?
	if(m_reverse_dns[addr] == "")
	{
		throw JtagExceptionWrapper(
			"The requested address was not found",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Hit
	return m_reverse_dns[addr];
}

/**
	@brief Reverse name lookup for NoC
	
	Only queries the cache and does not talk to the real name server on a miss.
	
	@throw JtagException if the address is not in the table
	
	@param addr		Address of the desired core
	@return			The hostname of the core
 */
string NameServer::ReverseLookupCacheOnly(int addr)
{
	//Not in cache?
	if(m_reverse_dns.find(addr) == m_reverse_dns.end())
	{
		throw JtagExceptionWrapper(
			"The requested address was not found",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Hit
	return m_reverse_dns[addr];
}

/**
	@brief Adds a nameserver entry for a software-based host
	
	The current implementation stores the entry in the cache but does not propagate it to the device.
	
	@param name		The hostname to add
	@param addr		The address to add
 */
void NameServer::AddEntry(string name, int addr)
{
	m_forward_dns[name] = addr;
	m_reverse_dns[addr] = name;
}

/**
	@brief Reverse name lookup bypassing the cache
	
	@throw JtagException if the address is not in the table or a communication error occurs
	
	@param addr		Address of the desired core
	@return			The hostname of the core
 */
string NameServer::ReverseLookupUncached(int addr)
{	
	//Get the data
	RPCMessage msg;
	m_pif->RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_RQUERY, addr, 0, 0, msg);
		
	//Found it, return the hostname
	char hostname[9];
	memcpy(hostname, &msg.data[1], 8);
	FlipByteArray((unsigned char*)hostname, 4);
	FlipByteArray((unsigned char*)hostname+4, 4);
	hostname[8] = 0;
	return string(hostname);
}

/**
	@brief Registers a name in the name table
	
	@throw JtagException if the address is not in the table or a communication error occurs
	
	@param name		Hostname to register
 */
void NameServer::Register(std::string name)
{
	#if (defined(__amd64__) && !defined(_WIN32) )
	
		//Generate the hostname string
		uint32_t hostname[2] = {0};
		unsigned char* chostname = reinterpret_cast<unsigned char*>(hostname);
		memcpy(chostname, name.c_str(), name.length());
		FlipByteArray(chostname, 4);
		FlipByteArray(chostname+4, 4);
			
		//Get the lock
		bool locked = false;
		RPCMessage msg;
		for(int i=0; i<10; i++)
		{
			try
			{
				//Try to get the lock
				m_pif->RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_LOCK, 0, 0, 0, msg);
							
				//If no exception thrown, and it looks good, we got it
				locked = true;
				break;
			}
			catch(const JtagException& ex)
			{
				//wait 50ms and try again
				usleep(50 * 1000);
			}
		}
		
		if(!locked)
		{
			throw JtagExceptionWrapper(
				"Failed to get nameserver write mutex (tried 10 times)",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//We got the mutex!	
		
		//Generate the write message and sign it
		//Note that we can't rely on the interface adding our "from" address because we have to sign that
		RPCMessage write_msg;
		write_msg.from = msg.to;			//we now know our address
		write_msg.to = NAMESERVER_ADDR;
		write_msg.type = RPC_TYPE_CALL;
		write_msg.callnum = NAMESERVER_REGISTER;
		write_msg.data[0] = 0;
		write_msg.data[1] = hostname[0];
		write_msg.data[2] = hostname[1];
		
		//Pack it in network byte order
		unsigned char message[16];
		write_msg.Pack(message);
		
		//Calculate the HMAC signature
		unsigned char hmac[32];
		CryptoPP::HMAC<CryptoPP::SHA256> hasher(m_hmacKey, 64);
		hasher.CalculateDigest(hmac, message, 16);
		
		//Send the HMAC to the name server as four 64-bit chunks
		uint32_t hmac_hi = 0;
		uint32_t hmac_lo = 0;
		for(int i=0; i<4; i++)
		{
			hmac_hi = (hmac[i*8] << 24) | (hmac[i*8 + 1] << 16 ) | (hmac[i*8 + 2] << 8) | hmac[i*8 + 3];
			hmac_lo = (hmac[i*8 + 4] << 24) | (hmac[i*8 + 5] << 16 ) | (hmac[i*8 + 6] << 8) | hmac[i*8 + 7];
			m_pif->RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_HMAC, i, hmac_hi, hmac_lo, msg);
		}
		
		//Register our name with the server
		m_pif->RPCFunctionCall(NAMESERVER_ADDR, NAMESERVER_REGISTER, 0, hostname[0], hostname[1], msg);
		
	#else
		throw JtagExceptionWrapper(
			string("Crypto++ support on platforms other than amd64 Linux isn't yet working") + name,
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	#endif
}
