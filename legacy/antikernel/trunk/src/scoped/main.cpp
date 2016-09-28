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
	@brief Entry point and main connection loop for scope daemon
 */

#include "scoped.h"
#include "ScopedProtocol.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>

using namespace std;

void sig_handler(int sig);

bool g_quit = false;
int g_socket = -1;

void ShowUsage();
void ShowVersion();
void ListScopes();

void ProcessConnection(int client_socket, Oscilloscope* pScope);

int main(int argc, char* argv[])
{	
	//Command-line flag data
	string scope_serial = "";
	unsigned short port = 50125;		//random default port
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
		else if(s == "--list")
		{
			ListScopes();
			return 0;
		}
		else if(s == "--port")
			port = atoi(argv[++i]);
		else if(s == "--nobanner")
			nobanner = true;
		else if(s == "--serial")
			scope_serial = argv[++i];
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
		
	Oscilloscope* pScope = NULL;
	int exit_code = 0;
	try
	{	
		//Find the requested scope
		int devcount = Oscilloscope::GetDeviceCount();
		if(devcount <= 0)
		{
			printf("No scopes found, giving up\n");
			return 0;
		}
		
		//Loop over the scopes until we find this one
		for(int i=0; i<devcount; i++)
		{
			pScope = Oscilloscope::CreateDevice(i);
			if(pScope->GetSerial() == scope_serial)
				break;
			delete pScope;
		}
		
		//TODO: adjustable verbosity levels
		printf("Connected to device \"%s %s\" (serial number \"%s\")\n",
			pScope->GetVendor().c_str(), pScope->GetName().c_str(), pScope->GetSerial().c_str());
				
		//Install signal handler
		signal(SIGINT, sig_handler);
		signal(SIGPIPE, sig_handler);
		
		//Create the socket server
		g_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
		if(0 == g_socket)
		{
			throw JtagExceptionWrapper(
				"Failed to create socket",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		sockaddr_in pname;
		memset(&pname,0,sizeof(pname));
		pname.sin_family=AF_INET;
		pname.sin_port=htons(port);
		if(0 != bind(g_socket,reinterpret_cast<sockaddr*>(&pname),sizeof(pname)) )
		{
			throw JtagExceptionWrapper(
				"Failed to bind socket",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		
		//Set no-delay flag
		int flag = 1;
		if(0 != setsockopt(g_socket, IPPROTO_TCP, TCP_NODELAY, (char *)&flag, sizeof(flag) ))
		{
			throw JtagExceptionWrapper(
				"Failed to set TCP_NODELAY",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		
		//Wait for connections
		//No threading - only one client allowed at a time
		if(0 != listen(g_socket,SOMAXCONN))
		{
			throw JtagExceptionWrapper(
				"Failed to listen to socket",
				"",
				JtagException::EXCEPTION_TYPE_NETWORK);
		}
		sockaddr_in client_addr;
		socklen_t socklen = sizeof(client_addr);
		int client_socket;
		while( (client_socket = accept(g_socket,reinterpret_cast<sockaddr*>(&client_addr),&socklen)) > 0)
		{
			ProcessConnection(client_socket, pScope);
			socklen = sizeof(client_addr);
		}
				
		//Clean up
		if(g_socket > 0)
			close(g_socket);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		exit_code = 1;
	}
	
	//Clean up
	delete pScope;
	return exit_code;
}

void sig_handler(int sig)
{
	switch(sig)
	{
		case SIGINT:
			g_quit = true;
			close(g_socket);
			g_socket = -1;
			printf("Quitting...\n");
			break;
			
		case SIGPIPE:
			//ignore
			break;
	}
}

/**
	@brief Prints usage information
 */
void ShowUsage()
{
	printf(
		"Usage: scoped [OPTION]\n"
		"\n"
		"Arguments:\n"
		"    --help                                           Displays this message and exits.\n"
		"    --list                                           Prints a listing of connected adapters and exits.\n"
		"    --nobanner                                       Do not print version number on startup.\n"
		"    --port PORT                                      Specifies the port number the daemon should listen on.\n"
		"    --serial SERIAL_NUM                              Specifies the serial number of the oscilloscope to connect to.\n"
		"                                                     This argument is mandatory except for --list and --help mode.\n"
		);
}

/**
	@brief Prints program version number
 */
void ShowVersion()
{
	printf(
		"Oscilloscope server daemon [SVN rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n"
		, SVNVERSION);
}

/**
	@brief Lists the connected oscilloscopes
 */
void ListScopes()
{
	try
	{
		ShowVersion();
		
		int devcount = Oscilloscope::GetDeviceCount();
		if(devcount <= 0)
		{
			printf("No scopes found, giving up\n");
			return;
		}
		
		//Loop over the scopes
		printf("USBTMC:\n");
		for(int i=0; i<devcount; i++)
		{
			Oscilloscope* pScope = Oscilloscope::CreateDevice(i);			
			printf("    Device %d: %s %s\n", i, pScope->GetVendor().c_str(), pScope->GetName().c_str());
			printf("        Serial number:  %s\n", pScope->GetSerial().c_str());
			delete pScope;
		}
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		exit(1);
	}
}

void ProcessConnection(int socket, Oscilloscope* pScope)
{
	try
	{
		//Sit around and wait for messages
		uint16_t opcode;
		while(2 == NetworkedJtagInterface::read_looped(socket, (unsigned char*)&opcode, 2))
		{
			bool quit = false;
			
			switch(opcode)
			{
				//Device properties
				case SCOPED_OP_GET_NAME:
					NetworkedJtagInterface::SendString(socket, pScope->GetName());
					break;
				case SCOPED_OP_GET_VENDOR:
					NetworkedJtagInterface::SendString(socket, pScope->GetVendor());
					break;
				case SCOPED_OP_GET_SERIAL:
					NetworkedJtagInterface::SendString(socket, pScope->GetSerial());
					break;
					
				//Channel properties
				case SCOPED_OP_GET_CHANNELS:
					{
						uint16_t count = pScope->GetChannelCount();
						NetworkedJtagInterface::write_looped(socket, (unsigned char*)&count, sizeof(count));
					}
					break;
				case SCOPED_OP_GET_HWNAME:
					{
						uint16_t channel_num;
						NetworkedJtagInterface::read_looped(socket, (unsigned char*)&channel_num, sizeof(channel_num));
						OscilloscopeChannel* chan = pScope->GetChannel(channel_num);
						NetworkedJtagInterface::SendString(socket, chan->m_displayname);
					}
					break;
				case SCOPED_OP_GET_DISPLAYCOLOR:
					{
						uint16_t channel_num;
						NetworkedJtagInterface::read_looped(socket, (unsigned char*)&channel_num, sizeof(channel_num));
						OscilloscopeChannel* chan = pScope->GetChannel(channel_num);
						NetworkedJtagInterface::SendString(socket, chan->m_displaycolor);
					}
					break;
				case SCOPED_OP_GET_CHANNEL_TYPE:
					{
						uint16_t channel_num;
						NetworkedJtagInterface::read_looped(socket, (unsigned char*)&channel_num, sizeof(channel_num));
						OscilloscopeChannel* chan = pScope->GetChannel(channel_num);
						uint16_t type = chan->GetType();
						NetworkedJtagInterface::write_looped(socket, (unsigned char*)&type, sizeof(type));
					}
					break;
					
				//Trigger properties
				case SCOPED_OP_GET_TRIGGER_MODE:
					{
						uint16_t mode = pScope->PollTrigger();
						NetworkedJtagInterface::write_looped(socket, (unsigned char*)&mode, sizeof(mode));
					}
					break;
				case SCOPED_OP_ACQUIRE:
					{
						sigc::slot1<int, float> empty_callback;
						pScope->AcquireData(empty_callback);
					}
					break;
				case SCOPED_OP_START:
					pScope->Start();
					break;
				case SCOPED_OP_START_SINGLE:
					pScope->StartSingleTrigger();
					break;
				case SCOPED_OP_STOP:
					pScope->Stop();
					break;
					
				//Capture data
				case SCOPED_OP_CAPTURE_DEPTH:
					{
						uint16_t channel_num;
						NetworkedJtagInterface::read_looped(socket, (unsigned char*)&channel_num, sizeof(channel_num));
						uint32_t depth = 0;
						OscilloscopeChannel* chan = pScope->GetChannel(channel_num);
						if(chan->GetData() != NULL)
							depth = chan->GetData()->GetDepth();
						NetworkedJtagInterface::write_looped(socket, (unsigned char*)&depth, 4);
					}				
					break;
				case SCOPED_OP_CAPTURE_DATA:
					{						
						//Get the channel info
						uint16_t channel_num;
						NetworkedJtagInterface::read_looped(socket, (unsigned char*)&channel_num, sizeof(channel_num));
						OscilloscopeChannel* chan = pScope->GetChannel(channel_num);
						CaptureChannelBase* data = chan->GetData();
						
						//Sanity check
						if(data == NULL)
						{
							throw JtagExceptionWrapper(
								"Capture data is NULL, can't dump it",
								"",
								JtagException::EXCEPTION_TYPE_GIGO);
						}
						
						switch(chan->GetType())
						{
							case OscilloscopeChannel::CHANNEL_TYPE_ANALOG:
								{
									AnalogCapture* capture = dynamic_cast<AnalogCapture*>(data);
									for(size_t i=0; i<capture->m_samples.size(); i++)
									{
										NetworkedJtagInterface::write_looped(
											socket,
											(const unsigned char*)&(capture->m_samples[i]),
											sizeof(AnalogSample));
									}
								}
								break;
							case OscilloscopeChannel::CHANNEL_TYPE_DIGITAL:
								{
									DigitalCapture* capture = dynamic_cast<DigitalCapture*>(data);								
									for(size_t i=0; i<capture->m_samples.size(); i++)
									{
										NetworkedJtagInterface::write_looped(
											socket,
											(const unsigned char*)&(capture->m_samples[i]),
											sizeof(DigitalSample));
									}
								}
								break;
							default:
								throw JtagExceptionWrapper(
									"Server-side protocol decoding not supported",
									"",
									JtagException::EXCEPTION_TYPE_GIGO);
								break;
						}
					}
					break;
				case SCOPED_OP_CAPTURE_TIMESCALE:
					{
						uint16_t channel_num;
						NetworkedJtagInterface::read_looped(socket, (unsigned char*)&channel_num, sizeof(channel_num));
						OscilloscopeChannel* chan = pScope->GetChannel(channel_num);
						if(chan->GetData() == NULL)
						{
							throw JtagExceptionWrapper(
								"Cannot get timescale for empty capture",
								"",
								JtagException::EXCEPTION_TYPE_GIGO);
						}
						int64_t scale = chan->GetData()->m_timescale;
						NetworkedJtagInterface::write_looped(socket, (unsigned char*)&scale, 8);
					}
					break;
				
				default:
					{
						throw JtagExceptionWrapper(
							"Unrecognized opcode received from client",
							"",
							JtagException::EXCEPTION_TYPE_GIGO);
					}
			}
			
			if(quit)
				break;
		}
	}
	
	catch(const JtagException& ex)
	{
		//Don't print network errors
		if(ex.GetType() != JtagException::EXCEPTION_TYPE_NETWORK)
			printf("%s\n", ex.GetDescription().c_str());
	}
	
	close(socket);
}
