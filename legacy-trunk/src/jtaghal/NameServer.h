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
	@brief Declaration of NameServer
 */

#ifndef NameServer_h
#define NameServer_h

#include <map>
#include <string>

class RPCAndDMANetworkInterface;

/**
	@brief Connection to the on-chip name server
	
	The name server allows NoC addresses to be mapped to 8-character hostnames and vice versa for ease of debugging,
	board bring-up, and system integration.
	
	By default names are cached by the object once looked up once to avoid duplicate lookups.
	
	\ingroup libjtaghal
 */
class NameServer
{
public:
	NameServer(RPCAndDMANetworkInterface* pif, std::string password = "");
	
	void LoadHostnames(bool bVerbose);
	void LoadHostTableEntry(int nstep, bool bVerbose);
	
	void Register(std::string name);
	
	int ForwardLookup(std::string name);
	int ForwardLookupUncached(std::string name);
	std::string ReverseLookup(int addr);
	std::string ReverseLookupCacheOnly(int addr);
	std::string ReverseLookupUncached(int addr);
	
	void AddEntry(std::string name, int addr);
	
	typedef std::map<std::string, int> ForwardMapType;
	
	ForwardMapType::const_iterator cbegin()
	{ return m_forward_dns.cbegin(); }
	ForwardMapType::const_iterator cend()
	{ return m_forward_dns.cend(); }

protected:
	///Forward (string to address) name lookup cache
	ForwardMapType m_forward_dns;
	
	///Reverse (address to string) name lookup cache
	std::map<int, std::string> m_reverse_dns;
	
	///RPC network connection
	RPCAndDMANetworkInterface* m_pif;
	
	///HMAC key used for authenticating writes
	unsigned char m_hmacKey[64];
};

#endif
