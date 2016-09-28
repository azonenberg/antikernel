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
	@brief Implementation of PacketView
 */

#include "nocsniff.h"
#include "PacketView.h"
#include "MainWindow.h"
#include <RPCv2Router_type_constants.h>

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

PacketView::PacketView(MainWindow* parent)
	: m_parent(parent)
{
	//Add column headings
	m_model = Gtk::TreeStore::create(m_columns);
	set_model(m_model);
	
//	append_column("No.", m_columns.index);
	append_column("Time", m_columns.time);
	append_column("Source", m_columns.src);
	append_column("Destination", m_columns.dst);
	append_column("Type", m_columns.type);
	append_column("Length", m_columns.len);
	append_column("Info", m_columns.info);
	append_column("Summary", m_columns.summary);
	
	//Set background color
	for(int i=0; i<7; i++)
	{
		Gtk::CellRenderer* render = get_column_cell_renderer(i);
		get_column(i)->add_attribute(*render, "background-gdk", m_columns.color);
	}
	
	//Sort by time
	m_model->set_sort_column(m_columns.time_raw, Gtk::SORT_ASCENDING);
	
	set_headers_visible(true);
	
	//Load protocol info
	FILE* fp = fopen(
		"/nfs4/home/azonenberg/code/antikernel/trunk/splashbuild/generic/modinfo.txt",
		"r");
	if(!fp)
	{
		printf("Couldn't load modinfo.txt\n");
		return;
	}
	char line[1024];
	vector<string> lines;
	while(fgets(line, sizeof(line), fp))
		lines.push_back(line);
	fclose(fp);
	
	//Parse protocol info
	for(unsigned int i=0; i<lines.size(); i++)
	{
		char keyword[32];
		if(1 != sscanf(lines[i].c_str(), "%31s", keyword))
			continue;
		string skeyword(keyword);
		if(skeyword == "module")
		{
			char modname[128];
			if(1 != sscanf(lines[i].c_str(), "module %127s", modname))
				continue;
			m_modinfo[modname] = new AntikernelModuleInfo(lines, i);
		}
	}
}

PacketView::~PacketView()
{
	for(auto x : m_modinfo)
		delete x.second;
	m_modinfo.clear();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Update methods

void PacketView::AddSamples(std::list<RPCSniffSample>& samples, NameServer& namesrvr)
{
	int64_t sysclk_ps = m_parent->GetSysclkPeriod();
	
	for(auto i : samples)
	{
		Gtk::TreeStore::iterator it = m_model->append();
		
		//Raw time (used for sorting, not displayed)
		it->set_value(1, i.m_start);
		
		//Convert to ms + cycles
		int64_t cycles_per_ms = (1000 * 1000 * 1000) / sysclk_ps;
		int64_t ms = i.m_start / cycles_per_ms;
		int64_t offset = i.m_start % cycles_per_ms;
		
		float sec = ms * 0.001f;
		
		char tbuf[64];
		snprintf(tbuf, sizeof(tbuf), "%.3fs + %lu clocks", sec, offset);
		it->set_value(2, string(tbuf));
		
		//Hostname and type are simple, just string-ify
		string fromhost = FormatHostname(i.m_msg.from, namesrvr);
		string tohost = FormatHostname(i.m_msg.to, namesrvr);
		it->set_value(3, fromhost);
		it->set_value(4, tohost);
		
		//Decode the full function call etc
		//The hostname who defines the opcode is the recipient for calls, and sender for everything else
		string ophost = fromhost;
		if(i.m_msg.type == RPC_TYPE_CALL)
			ophost = tohost;
		pair<string, string> info = DecodeRPCPacket(m_parent->GetNodeType(ophost), i.m_msg, namesrvr);
		
		//Decode color based on type
		string scolor = "white";
		switch(i.m_msg.type)
		{
		case RPC_TYPE_CALL:
			it->set_value(5, string("RPC call"));
			break;
		case RPC_TYPE_RETURN_SUCCESS:
			it->set_value(5, string("RPC return: success"));
			scolor = "#e0ffe0";
			break;
		case RPC_TYPE_RETURN_FAIL:
			it->set_value(5, string("RPC return: fail"));
			scolor = "#ffe0e0";
			break;
		case RPC_TYPE_RETURN_RETRY:
			it->set_value(5, string("RPC return: retry"));
			scolor = "#ffffe0";
			break;
		case RPC_TYPE_INTERRUPT:
			it->set_value(5, string("RPC interrupt"));
			
			//If the interrupt is of type "fail" then show it as fail type
			if( (info.first.find("FAIL") != string::npos) || (info.first.find("DENIED") != string::npos) )
				scolor = "#ffe0e0";
				
			//If the interrupt is of type "done" then show it as success type
			if(info.first.find("DONE") != string::npos)
				scolor = "#e0ffe0";
			
			break;
		case RPC_TYPE_HOST_UNREACH:
			it->set_value(5, string("RPC host unreachable"));
			break;
		case RPC_TYPE_HOST_PROHIBITED:
			it->set_value(5, string("RPC host prohibited"));
			break;
		default:
			break;
		}
		
		//Length
		it->set_value(6, 16);
				
		//Dump out packet info
		it->set_value(7, info.first);
		it->set_value(8, info.second);
		
		//Set color
		it->set_value(9, Gdk::Color(scolor));
	}
}

void PacketView::AddSamples(std::list<DMASniffSample>& samples, NameServer& namesrvr)
{
	int64_t sysclk_ps = m_parent->GetSysclkPeriod();
	
	for(auto i : samples)
	{
		Gtk::TreeStore::iterator it = m_model->append();
		
		//Raw time (used for sorting, not displayed)
		it->set_value(1, i.m_start);
		
		//Convert to ms + cycles
		int64_t cycles_per_ms = (1000 * 1000 * 1000) / sysclk_ps;
		int64_t ms = i.m_start / cycles_per_ms;
		int64_t offset = i.m_start % cycles_per_ms;
		
		float sec = ms * 0.001f;
		
		char tbuf[64];
		snprintf(tbuf, sizeof(tbuf), "%.3fs + %lu clocks", sec, offset);
		it->set_value(2, string(tbuf));
		
		//Hostname and type are simple, just string-ify
		string fromhost = FormatHostname(i.m_msg.from, namesrvr);
		string tohost = FormatHostname(i.m_msg.to, namesrvr);
		it->set_value(3, fromhost);
		it->set_value(4, tohost);
		
		//No application layer decode for now
		
		//Decode color based on type
		string scolor = "white";
		
		switch(i.m_msg.opcode)
		{
		case DMA_OP_WRITE_REQUEST:
			it->set_value(5, string("DMA write request"));
			break;
		case DMA_OP_READ_REQUEST:
			it->set_value(5, string("DMA read request"));
			break;
		case DMA_OP_READ_DATA:
			it->set_value(5, string("DMA read data"));
			scolor = "#e0ffe0";
			break;
		default:
			break;
		}
		
		//Length (bytes)
		it->set_value(6, i.m_msg.len*4);
				
		//Dump out packet info
		char tmp[128];
		snprintf(tmp, sizeof(tmp), "addr=0x%08x", i.m_msg.address);
		it->set_value(7, string(tmp));
		it->set_value(8, string(""));
		
		//Set color
		it->set_value(9, Gdk::Color(scolor));
	}
}

string PacketView::FormatHostname(unsigned int host, NameServer& namesrvr, bool showboth)
{
	char buf[128];
	try
	{
		string addr = namesrvr.ReverseLookup(host);
		if(showboth)
		{
			snprintf(buf, sizeof(buf), "0x%04x/%s", host, addr.c_str());
			return buf;
		}
		else
			return addr;
	}
	catch(const JtagException& e)
	{
		snprintf(buf, sizeof(buf), "%04x", host);
		return buf;
	}
}

pair<string, string> PacketView::DecodeRPCPacket(string nodetype, RPCMessage msg, NameServer& namesrvr)
{
	//Look up the module and opcode. If unknown, do default decode (basically hex dump)
	if(m_modinfo.find(nodetype) == m_modinfo.end())
		return DefaultDecodeRPCPacket(msg);
	AntikernelModuleInfo* modinfo = m_modinfo[nodetype];
	if(modinfo->m_opcodeInfo.find(msg.callnum) == modinfo->m_opcodeInfo.end())
		return DefaultDecodeRPCPacket(msg);
	AntikernelOpcodeInfo& opinfo = modinfo->m_opcodeInfo[msg.callnum];
	if(opinfo.m_packetInfo.find(msg.type) == opinfo.m_packetInfo.end())
		return DefaultDecodeRPCPacket(msg);
	AntikernelPacketInfo& packinfo = opinfo.m_packetInfo[msg.type];
	
	//We now know the opcode
	//packinfo.m_opname
	
	string ret = packinfo.m_opname + "(";
	for(size_t i=0; i<packinfo.m_varinfo.size(); i++)
	{
		auto var = packinfo.m_varinfo[i];
		
		if(i != 0)
			ret += ", ";
		ret += var.m_displayName + "=";
		
		//Decode the variable
		ret += DecodeVariable(var, msg, namesrvr);
	}
	ret += ")";
	return pair<string, string>(ret, packinfo.m_desc);
}

string PacketView::DecodeVariable(AntikernelPacketVariableInfo& var, RPCMessage& msg, NameServer& namesrvr)
{
	//First, extract the data
	//Support a max of 64 bits for now
	uint64_t data = 0;
	unsigned int tbitcount = 0;
	for(auto x : var.m_bitfields)
	{
		//Shift right to trim off low bits
		uint64_t word = msg.data[x.m_word];
		word >>= x.m_bitlo;
	
		//Number of bits we are trying to extract
		unsigned int bitcount = (x.m_bithi + 1) - x.m_bitlo;
		tbitcount += bitcount;
		
		//AND mask for data we're keeping
		uint64_t mask = 0xffffffff;
		mask <<= bitcount;
		mask = ~mask;
		mask &= 0xffffffff;
		
		//Merge everything back		
		data = (data << bitcount) | (word & mask);
	}
	
	//Format the output	
	char retval[128] = {0};
	switch(var.m_displayType)
	{
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_DEC:
		snprintf(retval, sizeof(retval), "%ld", data);
		return retval;
		
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_HEX:
		if(tbitcount > 56)
			snprintf(retval, sizeof(retval), "0x%016lx", data);
		else if(tbitcount > 48)
			snprintf(retval, sizeof(retval), "0x%014lx", data);
		else if(tbitcount > 40)
			snprintf(retval, sizeof(retval), "0x%012lx", data);
		else if(tbitcount > 32)
			snprintf(retval, sizeof(retval), "0x%010lx", data);
		else if(tbitcount > 24)
			snprintf(retval, sizeof(retval), "0x%08lx", data);
		else if(tbitcount > 16)
			snprintf(retval, sizeof(retval), "0x%06lx", data);
		else if(tbitcount > 8)
			snprintf(retval, sizeof(retval), "0x%04lx", data);
		else
			snprintf(retval, sizeof(retval), "0x%02lx", data);
		return retval;
		
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_NOCADDR:
		return FormatHostname(data, namesrvr, true);
		
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_PHYADDR:
		snprintf(retval, sizeof(retval), "%s:%08x",
			FormatHostname(data >> 32, namesrvr).c_str(),
			(uint32_t)data & 0xffffffff);
		return retval;
		
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_MACADDR:
		snprintf(retval, sizeof(retval), "%02x:%02x:%02x:%02x:%02x:%02x",
			(unsigned int)(data >> 40) & 0xff,
			(unsigned int)(data >> 32) & 0xff,
			(unsigned int)(data >> 24) & 0xff,
			(unsigned int)(data >> 16) & 0xff,
			(unsigned int)(data >> 8) & 0xff,
			(unsigned int)(data >> 0) & 0xff
			);
		return retval;
		
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_IPV6:
		//TODO: Arbitrary length rather than just /64
		snprintf(retval, sizeof(retval), "%x:%x:%x:%x",
			(unsigned int)(data >> 48) & 0xffff,
			(unsigned int)(data >> 32) & 0xffff,
			(unsigned int)(data >> 16) & 0xffff,
			(unsigned int)(data >> 0) & 0xffff
			);
		return retval;
		
	//Time is in picoseconds
	//Display as both ps and MHz
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_TIME:
		snprintf(retval, sizeof(retval), "%d ps / %.2f MHz",
			(int)data, 1000000.0f / data);
		return retval;
		
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_ASCIIZ:
		retval[0] = (data >> 56) & 0xff;
		retval[1] = (data >> 48) & 0xff;
		retval[2] = (data >> 40) & 0xff;
		retval[3] = (data >> 32) & 0xff;
		retval[4] = (data >> 24) & 0xff;
		retval[5] = (data >> 16) & 0xff;
		retval[6] = (data >> 8) & 0xff;
		retval[7] = (data >> 0) & 0xff;
		return string("\"") + retval + string("\"");
	
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_ENUM:
		if(var.m_enumvals.find(data) != var.m_enumvals.end())
			return var.m_enumvals[data];
		else
		{
			snprintf(retval, sizeof(retval), "Invalid enum value (0x%lx)", data);
			return retval;
		}
		break;
		
	case AntikernelPacketVariableInfo::DISPLAY_TYPE_FX8:
		snprintf(retval, sizeof(retval), "%.3f", static_cast<float>(data)/256.0f);
		return retval;
		
	default:
		return "foo";
	}
}

pair<string, string> PacketView::DefaultDecodeRPCPacket(RPCMessage msg)
{
	char buf[256];
	snprintf(buf, sizeof(buf), "Call %02x, data %08x %08x %08x",
		msg.callnum, msg.data[0], msg.data[1], msg.data[2]);
	return pair<string, string>(buf, "");
}
