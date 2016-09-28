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
	@brief Signing tool for name-server entries
	
	\ingroup namesign
 */
 
/** 
	\defgroup namesign namesign: signing tool for ELF executables
	
	namesign is released under the same permissive 3-clause BSD license as the remainder of the project.	

	The signature is a HMAC-SHA256, with a fixed 512-bit key derived from the SHA-512 of the signing password.
 */
 
/**
	\page namesign_usage Usage
	\ingroup namesign
	
	TODO: Write stuff
	
	General arguments:
	
	\li --help<br/>
	Displays help and exits.
	
	\li --version<br/>
	Prints program version number and exits.
	
 */
 
#include "namesign.h"

#include <RPCv2Router_type_constants.h>
#include <NOCNameServer_constants.h>

using namespace std;

void ShowUsage();
void ShowVersion();

/**
	@brief Program entry point
	
	\ingroup namesign
 */
int main(int argc, char* argv[])
{
	int err_code = 0;

	bool nobanner = false;
	bool password_set = false;
	unsigned char hmac_key[64] = {0};
	string name = "";
	unsigned int addr = 0;
	
	//Parse command-line arguments
	for(int i=1; i<argc; i++)
	{
		string s(argv[i]);
		
		if(s == "--help")
		{
			ShowUsage();
			return 0;
		}
		else if(s == "--nobanner")
			nobanner = true;
		else if(s == "--password")
		{
			password_set = true;
			const char* password = argv[++i];
			CryptoPP::SHA512().CalculateDigest(hmac_key, (unsigned char*)password, strlen(password));
		}
		else if(s == "--version")
		{
			ShowVersion();
			return 0;
		}
		else if(s == "--addr")
			sscanf(argv[++i], "%4x", &addr);
		else if(s == "--hostname")
			name = argv[++i];
		else
		{
			printf("Unrecognized command-line argument \"%s\", use --help\n", s.c_str());
			return 1;
		}
	}
	
	//Print version number by default
	if(!nobanner)
		ShowVersion();
		
	//Sanity check
	if(!password_set)
	{
		printf("HMAC password not specified\n");
		return 1;
	}
	if(name == "")
	{
		printf("Hostname not specified\n");
		return 1;
	}
	if(addr == 0)
	{
		printf("Address not specified\n");
		return 1;
	}
	
	//Generate the hostname string
	uint32_t hostname[2] = {0};
	unsigned char* chostname = reinterpret_cast<unsigned char*>(hostname);
	memcpy(chostname, name.c_str(), name.length());
	FlipByteArray(chostname, 4);
	FlipByteArray(chostname+4, 4);
		
	//Generate the write message and sign it
	RPCMessage write_msg;
	write_msg.from = addr;
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
	CryptoPP::HMAC<CryptoPP::SHA256> hasher(hmac_key, 64);
	hasher.CalculateDigest(hmac, message, 16);
	
	//Format the generated code
	printf("uint32_t hostname[] = { 0x%08x, 0x%08x }; //\"%s\"\n", hostname[0], hostname[1], name.c_str());
	uint32_t hmac_hi = 0;
	uint32_t hmac_lo = 0;
	printf("uint32_t signature[] = \n{\n");
	for(int i=0; i<4; i++)
	{
		hmac_hi = (hmac[i*8] << 24) | (hmac[i*8 + 1] << 16 ) | (hmac[i*8 + 2] << 8) | hmac[i*8 + 3];
		hmac_lo = (hmac[i*8 + 4] << 24) | (hmac[i*8 + 5] << 16 ) | (hmac[i*8 + 6] << 8) | hmac[i*8 + 7];
		printf("\t0x%08x,\n\t0x%08x", hmac_hi, hmac_lo);
		if(i != 3)
			printf(",");
		printf("\n");
	}
	printf("};\n");
	
	//Print out the HMAC
	printf("\n\n");
	printf("HMAC = ");
	for(int i=0; i<32; i++)
		printf("%02x", hmac[i] & 0xff);
	printf("\n");
		
	return err_code;
}

/**
	@brief Prints program usage information
	
	\ingroup namesign
 */
void ShowUsage()
{
	/*
	printf(
		"Usage: namesign [args]\n"
		"\n"
		"General arguments:\n"
		"    --help                                           Displays this message and exits.\n"
		"    --nobanner                                       Do not print version number on startup.\n"
		"    --password [password]                            Specifies the signing key to use\n"
		"    --sign                                           Sign the file (and verify the previous signature, if any)\n"
		"    [filename]                                       Name of the file to sign\n"
		"    --version                                        Prints program version number and exits.\n"
		"\n"
		);
	*/
}

/**
	@brief Prints program version number
	
	\ingroup namesign
 */
void ShowVersion()
{
	printf(
		"Nameserver signing tool [SVN rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n"
		, SVNVERSION);
}
