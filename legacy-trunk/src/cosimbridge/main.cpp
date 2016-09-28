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
	@brief Bridge for hardware cosimulation
	
	\ingroup cosimbridge
 */
 
/** 
	\defgroup cosimbridge cosimbridge: bridge for hardware cosimulation
	
	cosimbridge is released under the same permissive 3-clause BSD license as the remainder of the project.	
 */
 
/**
	\page cosimbridge_usage Usage
	\ingroup cosimbridge
	
	cosimbridge is used, along with the Verilog CosimBridge module, to route packets between a nocswitch instance and a 
	simulation running in ISim. The communication takes place over two named pipes "readpipe" and "writepipe" which 
	both the cosimbridge application and the CosimBridge module expect to find in the current working directory.
	
	General arguments:
	
	\li --port NNN<br/>
	Specifies the TCP port that jtagclient should connect to (default 50124).
	
	\li --server HOST<br/>
	Specifies the hostname of the nocswitch server that jtagclient should connect to (default localhost)
	
	\li --nobanner<br/>
	Run the requested operation without printing the program version/license banner.
	
	\li --help<br/>
	Displays help and exits.
	
	\li --version<br/>
	Prints program version number and exits.
	
 */
 
#include "cosimbridge.h"

using namespace std;

void ShowUsage();
void ShowVersion();

/**
	@brief Program entry point
	
	\ingroup cosimbridge
 */
int main(int argc, char* argv[])
{
	JtagInterface* iface = NULL;
	int err_code = 0;
	try
	{
		string server="localhost";
		int port=50124;
		
		bool nobanner = false;
		
		//Parse command-line arguments
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);
			
			if(s == "--help")
			{
				ShowUsage();
				return 0;
			}
			else if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
			else if(s == "--nobanner")
				nobanner = true;
			else if(s == "--version")
			{
				ShowVersion();
				return 0;
			}
			else
			{
				printf("Unrecognized command-line argument \"%s\", use --help\n", s.c_str());
				return 1;
			}
		}
		
		//Print version number by default
		if(!nobanner)
			ShowVersion();
		
		printf("Connecting to nocswitch server at %s:%d...\n", server.c_str(), port);
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		printf("Connected\n");
		
		//Open both pipes
		FILE* fpRead = fopen("writepipe", "r");
		if(!fpRead)
		{
			throw JtagExceptionWrapper(
				"Couldn't open write pipe",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		FILE* fpWrite = fopen("readpipe", "w");
		if(!fpWrite)
		{
			fclose(fpRead);
			throw JtagExceptionWrapper(
				"Couldn't open read pipe",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		
		//Listen for commands (synchronized with simulation clock)
		char opcode[4] = {0};
		while(1 == fscanf(fpRead, "%3s", opcode))
		{
			if(!strcmp(opcode, "RPC"))
			{
				//Read ALL the things!
				//Do it in ints and then length-shuffle later.
				RPCMessage message;
				bool ok = true;
				int from;
				int to;
				int callnum;
				int type;
				ok &= (1 == fscanf(fpRead, "%04x", &from));
				ok &= (1 == fscanf(fpRead, "%04x", &to));
				ok &= (1 == fscanf(fpRead, "%02x", &callnum));
				ok &= (1 == fscanf(fpRead, "%02x", &type));
				ok &= (1 == fscanf(fpRead, "%08x", &message.data[0]));
				ok &= (1 == fscanf(fpRead, "%08x", &message.data[1]));
				ok &= (1 == fscanf(fpRead, "%08x", &message.data[2]));
				if(!ok)
				{
					throw JtagExceptionWrapper(
						"Failed to read RPC header from pipe",
						"",
						JtagException::EXCEPTION_TYPE_NETWORK);
				}
				message.from = from;
				message.to = to;
				message.callnum = callnum;
				message.type = type;
			
				//Message received! Format it
				unsigned char msg_buf[16];
				message.Pack(msg_buf);
				
				//and send it to the switch
				//printf("Sending: %s\n", message.Format().c_str());
				iface.SendRPCMessage(message);
			}
			
			//If nobody is talking we should get a POL every clock cycle, polling for new data
			//This is a hack to get around the apparent lack of nonblocking file I/O in verilog
			else if(!strcmp(opcode, "POL"))
			{
				//Poll the switch for data and forward if necessary
				RPCMessage msg;
				if(iface.RecvRPCMessage(msg))
				{
					//printf("Got: %s\n", msg.Format().c_str());
					
					fprintf(fpWrite, "RPC\n");
					fprintf(fpWrite, "%04x\n", msg.from);
					fprintf(fpWrite, "%04x\n", msg.to);
					fprintf(fpWrite, "%02x\n", msg.callnum);
					fprintf(fpWrite, "%02x\n", msg.type);
					fprintf(fpWrite, "%08x\n", msg.data[0]);
					fprintf(fpWrite, "%08x\n", msg.data[1]);
					fprintf(fpWrite, "%08x\n", msg.data[2]);
				}
				else
					fprintf(fpWrite, "NAK\n");
				fflush(fpWrite);
			}
			
			else
			{
				throw JtagExceptionWrapper(
					string("Unknown opcode ") + opcode + string(" received from pipe"),
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}

		}	
		fclose(fpWrite);
		fclose(fpRead);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	delete iface;
	iface = NULL;
	return err_code;
}

/**
	@brief Prints program usage information
	
	\ingroup cosimbridge
 */
void ShowUsage()
{
	printf(
		"Usage: cosimbridge [args]\n"
		"\n"
		"General arguments:\n"
		"    --help                                           Displays this message and exits.\n"
		"    --nobanner                                       Do not print version number on startup.\n"
		"    --port PORT                                      Specifies the nocswitch port number to connect to (defaults to 50124)\n"
		"    --server [hostname]                              Specifies the hostname of the nocswitch server to connect to (defaults to localhost).\n"
		"    --version                                        Prints program version number and exits.\n"
		"\n"
		);
}

/**
	@brief Prints program version number
	
	\ingroup cosimbridge
 */
void ShowVersion()
{
	printf(
		"Hardware cosimulation bridge [SVN rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n"
		, SVNVERSION);
}
