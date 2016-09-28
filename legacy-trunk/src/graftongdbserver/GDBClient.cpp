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
	@brief Implementation of GDBClient class
 */

#include "graftongdbserver.h"
#include <GraftonCPURPCDebugOpcodes_constants.h>
#include <RPCv2Router_type_constants.h>

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

GDBClient::GDBClient(Socket& sock, uint16_t caddr, NOCSwitchInterface& iface)
	: m_socket(sock)
	, m_caddr(caddr)
	, m_iface(iface)
{
	//Halt the target immediately
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_caddr, DEBUG_HALT, 0, 0, 0, rxm);
	
	//Set a 500ms timeout on the socket
	timeval tm = {0, 0};
	tm.tv_usec = 500000;
	if(0 != setsockopt(m_socket, SOL_SOCKET, SO_RCVTIMEO, &tm, sizeof(tm)))
	{
		printf("Couldn't set timeout on socket\n");
		exit(1);
	}
}

GDBClient::~GDBClient()
{
	close(m_socket);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Main processing loop

void GDBClient::Run()
{
	while(MessageLoopCycle())
	{}
}

bool GDBClient::MessageLoopCycle()
{
	unsigned char ch;
	
	//Wait for the opening $ or %
	if(1 != recv(m_socket, &ch, 1, 0))
		return true;
	
	if(ch == '$')
	{
		if(!ProcessPacket())
			return false;
	}
	else if(ch == '%')
		ProcessNotification();
	else if(ch == 0x03)
		ProcessInterrupt();

	//ignore anything else
	
	return true;
}

bool GDBClient::ProcessPacket()
{
	//Read the entire body of the packet
	string body;
	unsigned char checksum = 0;
	while(true)
	{
		unsigned char c;
		m_socket.RecvLooped(&c, 1);
		if(c == '#')
			break;
		checksum += c;		
		body += (char)c;
	}
	
	//Read the checksum
	char csum_exp[3];
	m_socket.RecvLooped((unsigned char*)csum_exp, 2);
	unsigned int csum_val = 0;
	sscanf(csum_exp, "%2x", &csum_val);
	
	//If checksum was bad, send NAK
	if(csum_val != checksum)
	{
		unsigned char e = '-';
		m_socket.SendLooped(&e, 1);
		return true;
	}
	
	//printf("Got: %s\n", body.c_str());

	//Good checksum, process the message		
	char c = body[0];
	switch(c)
	{
	//Continue
	case 'c':
		Continue();
		break;
		
	case 'D':
		//exit
		SendResponse("OK");
		return false;
	
	//Read registers
	case 'g':
		ReadRegisters();
		break;
		
	//Set thread ID (not supported)
	case 'H':
		SendResponse("");
		break;
	
	//Read memory
	case 'm':
		ReadMemory(body);
		break;
	
	//Query
	case 'q':
		ProcessQueryPacket(body);
		break;
		
	//Single step
	case 's':
		SingleStep();
		break;
		
	//Vector (multi-letter ID) packet
	case 'v':
		ProcessVectorPacket(body);
		break;
		
	//Insert a breakpoint
	case 'Z':
		SetBreakpoint(body);
		break;
		
	//Remove a breakpoint
	case 'z':
		ClearBreakpoint(body);
		break;
		
	//Figure out why we halted
	case '?':
		GetHaltStatus();
		break;
		
	default:
		printf("Got unknown packet: %c (%s)\n", c, body.c_str());
		SendResponse("");
		break;
	}
	
	//keep going 
	return true;
}

void GDBClient::ProcessNotification()
{
	printf("Notifications not implemented\n");
	return;
}

void GDBClient::ProcessQueryPacket(string body)
{
	//Get the thing being queried
	string qobj;
	size_t pos = 1;
	for(; pos<body.length(); pos++)
	{
		if(body[pos] == ':')
			break;
		qobj += body[pos];
	}
	pos++;
	
	//Exchange supported feature lists
	if(qobj == "Supported")
	{
		//Read the list of features being asked for
		printf("Supported-feature query\n");
		vector<string> features_asked_for;
		string temp;
		for(; pos<body.length(); pos++)
		{
			if(body[pos] == ';')
			{
				printf("    asked for feature %s\n", temp.c_str());
				features_asked_for.push_back(temp);
				temp = "";
			}
			else
				temp += body[pos];
		}
		if(temp != "")
			features_asked_for.push_back(temp);
		
		//Generic features (we don't support much)
		string response = "PacketSize=2048;qXfer:memory-map:read+";
		
		//Respond to each query
		for(size_t i=0; i<features_asked_for.size(); i++)
		{
			string f = features_asked_for[i];
			if(f.find("qRelocInsn") == 0)
				response += ";qRelocInsn-";
			
			//ignore unsupported stuff
		}
		
		//Send the response
		SendResponse(response);
	}
	
	//Ask for the current thread ID
	else if(qobj == "C")
		SendResponse("QC 0");
		
	//Get thread info
	else if(qobj == "fThreadInfo")
		SendResponse("m 0");
	else if(qobj == "sThreadInfo")
		SendResponse("l");
	else if(qobj == "L")
		SendResponse("qM 01 1 00000000 0");
	
	//Ask if we're attached to an existing process
	else if(qobj == "Attached")
		SendResponse("1");
	
	//Ask for relocation offsets (not implemented) in hardware
	else if(qobj == "Offsets")
		SendResponse("");
		
	//Telling us that it can do symbol lookup (we don't care)
	else if(qobj == "Symbol")
		SendResponse("OK");
		
	//Ask if we have a trace running
	else if(qobj == "TStatus")
		SendResponse("");
		
	//Got a transfer flag
	else if(qobj == "Xfer")
	{
		printf("Got qXfer command: %s\n", body.c_str());
		
		//todo: get more docs on how this is supposed to work
		if(body == "qXfer:memory-map:read::0,fff")
		{
			//header
			string response = "m<?xml version=\"1.0\"?>";
			response += "<!DOCTYPE memory-map PUBLIC \"+//IDN gnu.org//DTD GDB Memory Map V1.0//EN\" ";
			response += "\"http://sourceware.org/gdb/gdb-memory-map.dtd\">";
			response += "<memory-map>";
			
			//For now, hard code default GRAFTON memory map
			response += "<memory type=\"rom\" start=\"0x40000000\" length=\"131072\"/>";
			response += "<memory type=\"ram\" start=\"0x40080000\" length=\"458752\"/>";
			response += "<memory type=\"ram\" start=\"0x400F0800\" length=\"57344\"/>";
			response += "<memory type=\"ram\" start=\"0x400FF800\" length=\"2048\"/>";
			
			//footer
			response += "</memory-map>";
			SendResponse(response);
		}
		else
			SendResponse("l");
	}
	
	else
	{
		printf("Unknown query packet: %s\n", body.c_str());
		SendResponse("");
	}
}

void GDBClient::SendResponse(string str)
{
	//Compute checksum
	unsigned char csum = 0;
	for(size_t i=0; i<str.length(); i++)
		csum += (unsigned char)str[i];
	char tmp[4];
	snprintf(tmp, sizeof(tmp), "%02x", csum);
			
	//Formulate the final response and send it
	str = string("+$") + str + "#" + tmp;
	while(true)
	{
		//printf("Sent: %s\n", str.c_str());
		m_socket.SendLooped((unsigned char*)str.c_str(), str.length());
		
		//Wait for the ack
		unsigned char ack;
		m_socket.RecvLooped(&ack, 1);
		if(ack == '+')
			break;
	}
}

void GDBClient::ProcessInterrupt()
{
	printf("Halt requested");
	
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_caddr, DEBUG_HALT, 0, 0, 0, rxm);
	
	GetHaltStatus();
}

void GDBClient::GetHaltStatus()
{
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_caddr, DEBUG_GET_STATUS, 0, 0, 0, rxm);
	
	bool freeze = rxm.data[0] & 1;
	bool bad_instruction = (rxm.data[0] >> 1) & 1;
	bool segfault = (rxm.data[0] >> 2) & 1;
	
	//Save program counter for single stepping
	m_pc = rxm.data[1];
	
	//Not frozen? Give a NAK reply
	if(!freeze)
		SendResponse("");
		
	//Frozen? Indicate why
	else
	{
		if(bad_instruction)
			SendResponse("S04");
		else if(segfault)
		{
			SendResponse("S0B");
			printf("Target is segfaulted\n");
			
			//Clear segfault condition so we can do memory reads
			m_iface.RPCFunctionCall(m_caddr, DEBUG_CLEAR_SEGFAULT, 0, 0, 0, rxm);
		}
		else
			SendResponse("S05");
	}
}

void GDBClient::ReadRegisters()
{
	//All registers are transferred as thirty-two bit quantities in the order:
	//32 general-purpose; sr; lo; hi; bad; cause; pc; 32 floating-point registers; fsr; fir; fp. 
	
	RPCMessage rxm;
	char buf[9];
	
	string response = "";
	
	//General purpose registers
	for(int i=0; i<32; i+=2)
	{
		m_iface.RPCFunctionCall(m_caddr, DEBUG_READ_REGISTERS, 0, i, i+1, rxm);
		
		snprintf(buf, sizeof(buf), "%08x", rxm.data[1]);
		response += buf;
		snprintf(buf, sizeof(buf), "%08x", rxm.data[2]);
		response += buf;
	}
		
	//sr not implemented
	response += "00000000";
	
	//lo, hi
	m_iface.RPCFunctionCall(m_caddr, DEBUG_GET_MDU, 0, 0, 0, rxm);
	snprintf(buf, sizeof(buf), "%08x", rxm.data[1]);
	response += buf;
	snprintf(buf, sizeof(buf), "%08x", rxm.data[2]);
	response += buf;
	
	//bad
	m_iface.RPCFunctionCall(m_caddr, DEBUG_GET_STATUS, 0, 0, 0, rxm);
	snprintf(buf, sizeof(buf), "%08x", rxm.data[2]);
	response += buf;
	
	//cause not implemented
	response += "cccccccc";
	
	//pc
	snprintf(buf, sizeof(buf), "%08x", rxm.data[1]);
	response += buf;
	
	//floating point registers not implemented in hardware, read as zero
	for(int i=0; i<35; i++)
		response += "00000000";
		
	SendResponse(response);
}

void GDBClient::ReadMemory(string str)
{
	//Verify format
	unsigned int addr;
	unsigned int len;
	if(2 != sscanf(str.c_str(), "m%08x,%8u", &addr, &len))
	{
		SendResponse("E00");
		return;
	}
	
	//printf("Reading %d bytes of memory starting at %08x\n", len, addr);
	
	//Round the address down to the nearest word
	unsigned int saddr = addr & 0xFFFFFFFC;
	unsigned int eaddr = addr + len;
	
	//Fail in case of wraparound
	if( (eaddr < saddr) || (saddr == 0) )
	{
		SendResponse("E00");
		return;
	}
	
	//printf("Rounded to [%08x, %08x]\n", saddr, eaddr);
	
	//Read the bytes
	vector<unsigned char> bytes;
	RPCMessage rxm;
	for(unsigned int add=saddr; add<eaddr; add+=4)
	{
		try
		{
			//printf("Reading address: %08x\n", add);
			m_iface.RPCFunctionCall(m_caddr, DEBUG_READ_MEMORY, 0, add, 0, rxm);
			//printf("Word: %08x\n", rxm.data[1]);
			bytes.push_back( (rxm.data[1] >> 24) & 0xff);
			bytes.push_back( (rxm.data[1] >> 16) & 0xff);
			bytes.push_back( (rxm.data[1] >> 8 ) & 0xff);
			bytes.push_back( (rxm.data[1]      ) & 0xff);
		}
		catch(const JtagException& ex)
		{
			//printf("%s\n", ex.GetDescription().c_str());
			printf("Read of target virtual address %08x failed\n", add);
			SendResponse("E00");
			return;
		}
	}
	
	//Format output
	unsigned int offset = addr-saddr;
	string rval;
	char buf[3];
	for(unsigned int i=0; i<len; i++)
	{
		snprintf(buf, sizeof(buf), "%02x", bytes[i+offset]);
		rval += buf;
	}
	SendResponse(rval);
}

void GDBClient::Continue()
{
	//Restart the process
	RPCMessage rxm;
	m_iface.RPCFunctionCall(m_caddr, DEBUG_RESUME, 0, 0, 0, rxm);
	
	//Wait for it to halt
	while(true)
	{
		MessageLoopCycle();
		
		try
		{
			//TODO: Wait for ^C interrupts from gdb
			
			m_iface.WaitForInterruptFrom(m_caddr, rxm, 0.5);
			if(rxm.type != RPC_TYPE_INTERRUPT)
				continue;
			
			if(rxm.callnum == DEBUG_SEGFAULT)
				break;
			if(rxm.callnum == DEBUG_BREAKPOINT)
				break;
				
			if(rxm.callnum == DEBUG_LOG)
			{
				printf("Log message: %s\n", rxm.Format().c_str());
				continue;
			}
				
			printf("Got interrupt 0x%02x\n", rxm.callnum);
		}
		catch(const JtagException& ex)
		{
			//ignore timeouts
		}
	}
	
	//We got the stop alert, stop the target
	GetHaltStatus();
}

void GDBClient::SetBreakpoint(std::string str)
{
	//Not quite working!
	//SendResponse("");
	//return;
	
	//Parse it
	//Conditionals and actions are not implemented yet
	int bptype;
	unsigned int addr;
	int bpsubtype;
	if(3 != sscanf(str.c_str(), "Z%8d,%08x,%8d", &bptype, &addr, &bpsubtype))
	{
		printf("Unrecognized breakpoint command %s\n", str.c_str());
		SendResponse("");
		return;
	}
	
	//Ignore breakpoint type, we only implement hardware breaks
	if(bpsubtype != 4)
	{
		printf("Only 32-bit MIPS breakpoints supported\n");
		SendResponse("");
		return;
	}
	
	//Insert the breakpoint
	try
	{
		printf("Setting breakpoint at 0x%08x\n", addr);
		
		RPCMessage rxm;
		m_iface.RPCFunctionCall(m_caddr, DEBUG_SET_HWBREAK, 0, addr, 0, rxm);
		SendResponse("OK");
		return;
	}
	catch(const JtagException& ex)
	{
		SendResponse("E00");
	}
}

void GDBClient::ClearBreakpoint(std::string str)
{
	//Not quite working!
	//SendResponse("");
	//return;
	
	//Parse it
	int bptype;
	unsigned int addr;
	int bpsubtype;
	if(3 != sscanf(str.c_str(), "z%8d,%08x,%8d", &bptype, &addr, &bpsubtype))
	{
		printf("Unrecognized breakpoint command %s\n", str.c_str());
		SendResponse("");
		return;
	}
	
	//Ignore breakpoint type, we only implement hardware breaks
	if(bpsubtype != 4)
	{
		printf("Only 32-bit MIPS breakpoints supported\n");
		SendResponse("");
		return;
	}
	
	//Remove the breakpoint
	try
	{
		printf("Deleting breakpoint at 0x%08x\n", addr);
		
		RPCMessage rxm;
		m_iface.RPCFunctionCall(m_caddr, DEBUG_CLEAR_HWBREAK, 0, addr, 0, rxm);
		SendResponse("OK");
		return;
	}
	catch(const JtagException& ex)
	{
		SendResponse("E00");
	}
}

void GDBClient::ProcessVectorPacket(std::string body)
{
	//Query packet
	if(body == "vCont?")
	{
		SendResponse("vCont;c;s");
		return;
	}
	
	char idcode[128];
	if(1 != sscanf(body.c_str(), "%127[^;?]", idcode))
	{
		printf("malformed vector packet\n");
		SendResponse("");
		return;
	}
	string sid(idcode);
	
	//Continue a thread
	if(sid == "vCont")
	{
		char action;
		if(1 == sscanf(body.c_str(), "vCont;%c", &action))
		{
			switch(action)
			{
				//Continue running
				case 'c':
					Continue();
					break;
					
				default:
					printf("Unknown vCont packet %s\n", body.c_str());
					SendResponse("");
					break;
			}			
		}
		else
			Continue();
	}
	
	else
	{
		printf("Unrecognized vector command %s\n", body.c_str());
		SendResponse("");
	}
}

void GDBClient::SingleStep()
{
	printf("Single step\n");
	try
	{
		RPCMessage rxm;
		m_iface.RPCFunctionCallWithTimeout(m_caddr, DEBUG_SINGLE_STEP, 0, 0, 0, rxm, 10);
	}
	catch(const JtagException& ex)
	{
		printf("Single step timed out\n");
		Continue();
		return;
	}
	
	GetHaltStatus();
}
