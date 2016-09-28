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
	@brief Implementation of PDUController
 */

#include "pductrl.h"
#include <netdb.h>
#include <sys/socket.h>
#include <sys/types.h>
#include "../asn1/BER.h"

using namespace std;

//from colorbrewer2.org
const char* g_colorTable[10]=
{
	"#A6CEE3",
	"#1F78B4",
	"#B2DF8A",
	"#33A02C",
	"#FB9A99",
	"#E31A1C",
	"#FDBF6F",
	"#FF7F00",
	"#CAB2D6",
	"#6A3D9A"
};

PDUController::PDUController(string hostname, string readCommunity, string writeCommunity, Gdk::Color color)
	: Graphable(hostname)
	, m_hostname(hostname)
	, m_readCommunity(readCommunity)
	, m_writeCommunity(writeCommunity)
	, m_requestID(1)
{
	m_color = color;
	
	for(int i=0; i<10; i++)
		m_channelstatus[i] = 0;
		
	//Per-channel current graphs
	m_tabvbox.pack_start(m_curframe, Gtk::PACK_SHRINK);
		m_curframe.set_label_widget(m_curframelabel);
		m_curframelabel.set_markup("<b>Load Current</b>");
		m_curframe.set_shadow_type(Gtk::SHADOW_NONE);
		m_curframe.add(m_curgraph);
			m_curgraph.set_size_request(100, 250);
			m_curgraph.m_seriesName = "current";
			m_curgraph.m_units = "A";
			m_curgraph.m_unitScale = 0.001;
			m_curgraph.m_minScale = 0;
			m_curgraph.m_maxScale = 4000;
			m_curgraph.m_scaleBump = 500;
			m_curgraph.m_minRedline = -1;
			m_curgraph.m_maxRedline = 3950;
			for(int i=0; i<10; i++)
			{
				m_curgraph.m_series.push_back(&m_curgraphData[i]);
				char str[16];
				snprintf(str, sizeof(str), "CH%d", i);
				m_curgraphData[i].m_name = str;
				
				m_curgraphData[i].m_color.set(g_colorTable[i]);
			}
			
	//Rail voltage graphs
	m_tabvbox.pack_start(m_voltframe, Gtk::PACK_SHRINK);
		m_voltframe.set_label_widget(m_voltframelabel);
		m_voltframelabel.set_markup("<b>Line Voltage</b>");
		m_voltframe.set_shadow_type(Gtk::SHADOW_NONE);
		m_voltframe.add(m_voltgraph);
			m_voltgraph.set_size_request(100, 150);
			m_voltgraph.m_seriesName = "voltage";
			m_voltgraph.m_units = "V";
			m_voltgraph.m_unitScale = 0.001;
			int vnom = 5000;						//TODO: Center around 5 or 12V depending on board voltage
			m_voltgraph.m_minScale = vnom - 500;
			m_voltgraph.m_maxScale = vnom + 500;
			m_voltgraph.m_minRedline = vnom - 250;
			m_voltgraph.m_maxRedline = vnom + 250;
			m_voltgraph.m_scaleBump = 250;
			for(int i=0; i<2; i++)
			{
				m_voltgraph.m_series.push_back(&m_voltgraphData[i]);
				char str[16];
				snprintf(str, sizeof(str), "V%d", i);
				m_voltgraphData[i].m_name = str;
				
				m_voltgraphData[i].m_color.set(g_colorTable[i]);
			}
			
	//Chassis temperature graphs
	m_tabvbox.pack_start(m_tempframe, Gtk::PACK_SHRINK);
		m_tempframe.set_label_widget(m_tempframelabel);
		m_tempframelabel.set_markup("<b>Chassis Temperature</b>");
		m_tempframe.set_shadow_type(Gtk::SHADOW_NONE);
		m_tempframe.add(m_tempgraph);
			m_tempgraph.set_size_request(100, 150);
			m_tempgraph.m_seriesName = "temp";
			m_tempgraph.m_units = "°C";
			m_tempgraph.m_minScale = 0;
			m_tempgraph.m_maxScale = 80;
			m_tempgraph.m_scaleBump = 20;
			m_tempgraph.m_minRedline = 5;
			m_tempgraph.m_maxRedline = 60;
			for(int i=0; i<2; i++)
			{
				m_tempgraph.m_series.push_back(&m_tempgraphData[i]);
				char str[16];
				snprintf(str, sizeof(str), "T%d", i);
				m_tempgraphData[i].m_name = str;
				m_tempgraphData[i].m_color.set(g_colorTable[i]);
			}
			
	//Breaker controls
	m_tabvbox.pack_start(m_breakerframe, Gtk::PACK_SHRINK);
		m_breakerframe.set_label_widget(m_breakerframelabel);
		m_breakerframelabel.set_markup("<b>Breaker Control</b>");
		m_breakerframe.set_shadow_type(Gtk::SHADOW_NONE);
			m_breakerframe.add(m_breakerbox);
			for(int i=0; i<10; i++)
			{
				m_breakerbox.pack_start(m_breakerframes[i], Gtk::PACK_EXPAND_PADDING);
				
				char str[256];
				snprintf(str, sizeof(str), "<span font='Sans Bold 14'>CH%d</span>\n(A | ms)", i);
				m_breakerframes[i].set_label_widget(m_breakerframelabels[i]);
				m_breakerframes[i].set_label_align(0.5, 0.5);
				m_breakerframelabels[i].set_markup(str);
				m_breakerframes[i].set_shadow_type(Gtk::SHADOW_NONE);
				
				m_breakerframes[i].add(m_breakerhboxes[i]);				
				m_breakerhboxes[i].pack_start(m_breakercurrentsliders[i], Gtk::PACK_SHRINK);
				m_breakerhboxes[i].pack_start(m_breakerspeedsliders[i], Gtk::PACK_SHRINK);
				
				//Configure current slider
				m_breakercurrentsliders[i].set_size_request(75, 175);
				m_breakercurrentsliders[i].set_range(0, 4);
				m_breakercurrentsliders[i].set_value(2);
				m_breakercurrentsliders[i].set_round_digits(2);
				m_breakercurrentsliders[i].set_inverted();
				m_breakercurrentsliders[i].set_draw_value();
				m_breakercurrentsliders[i].set_digits(2);
				m_breakercurrentsliders[i].set_show_fill_level();
				m_breakercurrentsliders[i].set_restrict_to_fill_level(false);
				m_breakercurrentsliders[i].signal_value_changed().connect(
					sigc::bind(sigc::mem_fun(*this, &PDUController::OnBreakerLimitChanged), i));

				//Configure speed slider
				m_breakerspeedsliders[i].set_size_request(75, 175);
				m_breakerspeedsliders[i].set_range(0, 500);
				m_breakerspeedsliders[i].set_value(50);
				m_breakerspeedsliders[i].set_inverted();
				m_breakerspeedsliders[i].set_draw_value();
				m_breakerspeedsliders[i].set_digits(0);
				m_breakerspeedsliders[i].signal_value_changed().connect(
					sigc::bind(sigc::mem_fun(*this, &PDUController::OnBreakerSpeedChanged), i));
			}
	
	//Summary button list
	m_hostframe.set_margin_left(5);
	m_hostframe.set_margin_right(5);
	m_hostframe.set_margin_top(5);
	m_hostframe.set_margin_bottom(5);
	m_summaryhbox.set_margin_left(5);
	m_summaryhbox.set_margin_right(5);
	m_summaryhbox.set_margin_top(5);
	m_summaryhbox.set_margin_bottom(5);
	m_hostframe.set_label(m_hostname);
	m_hostframe.add(m_summaryhbox);
		for(int i=0; i<10; i++)
		{
			m_summaryhbox.pack_start(m_buttonboxes[i], Gtk::PACK_SHRINK);
			m_buttonboxes[i].pack_start(m_channelimages[i], Gtk::PACK_SHRINK);
			m_buttonboxes[i].pack_start(m_channelbuttons[i], Gtk::PACK_SHRINK);

			//Set up label
			char str[16];
			snprintf(str, sizeof(str), "%d", i);
			m_channelbuttons[i].set_label(str);
			
			//Set up image
			m_channelimages[i].set_size_request(32, 32);
			
			//Set up notification handler
			m_channelbuttons[i].signal_clicked().connect(
				sigc::bind(sigc::mem_fun(*this, &PDUController::OnChannelToggled), i));
		}
	m_summaryhbox.pack_start(m_statusbox, Gtk::PACK_SHRINK);
	m_statusbox.pack_start(m_vlabel);
		m_vlabel.set_alignment(Gtk::ALIGN_START, Gtk::ALIGN_CENTER);
		m_vlabel.set_width_chars(20);
		m_vlabel.set_margin_left(5);
	m_statusbox.pack_start(m_ilabel);
		m_ilabel.set_alignment(Gtk::ALIGN_START, Gtk::ALIGN_CENTER);
		m_ilabel.set_width_chars(20);
		m_ilabel.set_margin_left(5);
	m_statusbox.pack_start(m_tlabel);
		m_tlabel.set_alignment(Gtk::ALIGN_START, Gtk::ALIGN_CENTER);
		m_tlabel.set_width_chars(20);
		m_tlabel.set_margin_left(5);
		
	m_hostframe.show_all();
	m_tabvbox.show_all();
	
	//Look up the hostname info
	addrinfo hints;
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;		//allow both v4 and v6
	hints.ai_socktype = SOCK_DGRAM;		//using UDP
	hints.ai_flags = AI_PASSIVE;		//use wildcard address
	addrinfo* addr;
	int code = 0;
	if(0 != (code = getaddrinfo(hostname.c_str(), "snmp", &hints, &addr)))
	{
		printf("getaddrinfo failed: %d (%s)\n", code, gai_strerror(code));
		exit(1);
	}
	
	//Try creating the socket and connecting to the host
	//Note connect() is legal on UDP sockets and saves us the trouble of keeping track of the address ourself
	m_socket = -1;
	for(addrinfo* p = addr; p != NULL; p=p->ai_next)
	{
		m_socket = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
		if(m_socket < 0)
			continue;		
		if(0 != connect(m_socket, p->ai_addr, p->ai_addrlen))
		{
			close(m_socket);
			m_socket = -1;
			continue;
		}
		break;
	}
	freeaddrinfo(addr);
	if(m_socket < 0)
	{
		printf("Couldn't create socket for %s\n", hostname.c_str());
		exit(1);
	}
	
	//Set 0.5 sec timeout on the socket
	timeval tm = {0, 0};
	tm.tv_usec = 500000;
	if(0 != setsockopt(m_socket, SOL_SOCKET, SO_RCVTIMEO, &tm, sizeof(tm)))
	{
		printf("Couldn't set timeout on socket for %s\n", hostname.c_str());
		exit(1);
	}
	
	//Read current limits
	for(int i=0; i<10; i++)
		m_breakercurrentlimits[i] = -1;
}

PDUController::~PDUController()
{
	
}

#define SNMP_VERSION_2C		1
#define DRAWERSTEAK_PEN 42453

void PDUController::OnTimer()
{
	//TODO: Multithread so network stuff runs in background
	
	const size_t max_size = 10000;
	
	double now = GetTime();
	unsigned int value = 0;
	
	//Get per-channel measurements
	unsigned int isum = 0;
	unsigned int icount = 0;
	for(int channel=0; channel<10; channel++)
	{
		//Ask for the power switch state
		if(BlockingSnmpGet(4, channel+1, value))
		{
			m_channelstatus[channel] = value;
			switch(value)
			{
			case 0:
				m_channelimages[channel].set(Gtk::Stock::MEDIA_STOP, Gtk::ICON_SIZE_SMALL_TOOLBAR);
				//m_channelimages[channel].set_sensitive(false);
				break;
			
			case 1:
				m_channelimages[channel].set(Gtk::Stock::YES, Gtk::ICON_SIZE_SMALL_TOOLBAR);
				//m_channelimages[channel].set_sensitive(true);
				break;
				
			case 2:
				m_channelimages[channel].set(Gtk::Stock::NO, Gtk::ICON_SIZE_SMALL_TOOLBAR);
				//m_channelimages[channel].set_sensitive(true);
				break;
				
			default:
				//unknown, do nothing
				break;
			}
		}
		
		//Read current
		if(BlockingSnmpGet(2, channel+1, value))
		{
			Series* pSeries = m_curgraphData[channel].GetSeries("current");
			
			isum += value;
			icount ++;
			pSeries->push_back(GraphPoint(now, value));
			
			m_breakercurrentsliders[channel].set_fill_level(value * 0.001f);
			
			while(pSeries->size() > max_size)
				pSeries->pop_front();
		}
		
		//Read current limits
		//Do not move the focused channel
		if(!m_breakercurrentsliders[channel].has_focus())
		{
			if(BlockingSnmpGet(5, channel+1, value))
				m_breakercurrentsliders[channel].set_value(value * 0.001f);
		}
		
		//Read inrush timer values
		if(!m_breakerspeedsliders[channel].has_focus())
		{
			if(BlockingSnmpGet(6, channel+1, value))
				m_breakerspeedsliders[channel].set_value(value);
		}
	}
	
	//Get voltage readings
	unsigned int vsum = 0;
	unsigned int vcount = 0;
	for(int volt=0; volt<2; volt++)
	{
		Series* pSeries = m_voltgraphData[volt].GetSeries("voltage");
		
		if(BlockingSnmpGet(3, volt+1, value))
		{
			vsum += value;
			vcount ++;
			pSeries->push_back(GraphPoint(now, value));
		}
		
		while(pSeries->size() > max_size)
			pSeries->pop_front();
	}
	
	//Get global temp readings
	unsigned int temps[2];
	unsigned int tcount = 0;
	for(int temp=0; temp<2; temp++)
	{
		Series* pSeries = m_tempgraphData[temp].GetSeries("temp");
		
		if(BlockingSnmpGet(1, temp+1, value))
		{
			temps[temp] = value;
			tcount ++;
			pSeries->push_back(GraphPoint(now, value));
		}
		
		while(pSeries->size() > max_size)
			pSeries->pop_front();
	}
	
	//Update global sum/average readings if we got a full set of readouts
	//TODO: Decide how to handle partial response sets... use last sensor reading?
	char buf[32];
	if( (icount == 10) && (vcount == 2) )
	{
		float vnom = 5;	//TODO: Read nominal voltage
		
		//Voltage
		float vavg_mv = vsum / 2;
		float volts = vavg_mv / 1000;
		float dv = volts - vnom;
		snprintf(buf, sizeof(buf), "Line: %.3f V (%.2f %%)",
			volts, (dv*100)/vnom);
		m_vlabel.set_label(buf);
		
		Series* pSeries = GetSeries("vavg");
		pSeries->push_back(GraphPoint(now, vavg_mv));
		while(pSeries->size() > max_size)
			pSeries->pop_front();
	
		//Current and power
		pSeries = GetSeries("isum");
		pSeries->push_back(GraphPoint(now, isum));
		while(pSeries->size() > max_size)
			pSeries->pop_front();
		float amps = isum * 0.001f;
		snprintf(buf, sizeof(buf), "Load: %.2f A (%.0f %%, %.2f W)",
			amps,
			(100*amps) / 20.0f,
			amps*volts
			);
		m_ilabel.set_label(buf);
	}
	if(tcount == 2)
	{
		int tmax = (temps[0] > temps[1]) ? temps[0] : temps[1];
		
		//Temperature label
		snprintf(buf, sizeof(buf), "Temp: %d °C", tmax);
		m_tlabel.set_label(buf);
		
		Series* pSeries = GetSeries("tmax");
		pSeries->push_back(GraphPoint(now, tmax));
		while(pSeries->size() > max_size)
			pSeries->pop_front();
	}

	//TODO: Trim series to sane sizes
}

/**
	@brief Sends a single SNMP GetRequest and blocks until a response arrives or a timeout occurs
 */
bool PDUController::BlockingSnmpGet(unsigned short oid_table, unsigned short oid_index, unsigned int& value)
{
	unsigned int request_id = SendSnmpGetRequest(oid_table, oid_index);
		
	unsigned int response_id;
	unsigned short table;
	unsigned short index;
	
	if(!RecvSnmpGetResponse(response_id, table, index, value))
		return false;
	if( (response_id != request_id) || (table != oid_table) || (index != oid_index) )
		return false;
		
	return true;
}

bool PDUController::BlockingSnmpSet(unsigned short oid_table, unsigned short oid_index, unsigned int value)
{
	//TODO: Retransmits
	
	unsigned int request_id = SendSnmpSetRequest(oid_table, oid_index, value);
	
	unsigned int response_id;
	unsigned short table;
	unsigned short index;
	unsigned int rvalue;
	if(!RecvSnmpGetResponse(response_id, table, index, rvalue))
		return false;
	if( (response_id != request_id) || (table != oid_table) || (index != oid_index) )
		return false;
	if(value != rvalue)
		return false;
		
	return true;
}

/**
	@return request ID
 */
unsigned int PDUController::SendSnmpGetRequest(unsigned short oid_table, unsigned short oid_index)
{
	//Allocate request IDs, increasing modulo 32 and skipping zero
	unsigned int reqid = m_requestID++;
	if(reqid == 0)
		reqid = m_requestID++;
	
	//Create the get-request packet
	unsigned char body[2048] = {0};
	unsigned int packlen = 0;
	
	//Figure out the OID for this item
	unsigned short oid_entry[]=
	{
		6,	//length
		4, 1, DRAWERSTEAK_PEN, 2, oid_table, oid_index
	};
	
	//Sequence header
	unsigned int packet_len_ptr = 0;
	unsigned int body_len_ptr = 0;
	unsigned int varbind_list_len_ptr = 0;
	unsigned int varbind_len_ptr = 0;
	packlen = BEREncodeSequenceHeader(body, packlen, &packet_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Top-level sequence header
	packlen = BEREncodeInteger(body, packlen, SNMP_VERSION_2C);					//SNMP version 2c
	packlen = BEREncodeString(body, packlen, m_readCommunity.c_str());			//Community string
	packlen = BEREncodeSequenceHeader(body, packlen, &body_len_ptr,				//PDU packet header
		ASN1_TYPE_SNMP_GETREQUEST);
	packlen = BEREncodeInteger(body, packlen, reqid);					//Request ID
	packlen = BEREncodeInteger(body, packlen, 0);								//Error code and index (always zero)
	packlen = BEREncodeInteger(body, packlen, 0);
	packlen = BEREncodeSequenceHeader(body, packlen, &varbind_list_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Varbind list
	packlen = BEREncodeSequenceHeader(body, packlen, &varbind_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Single varbind
	packlen = BEREncodeOID(body, packlen, oid_entry);							//The OID of this value
	
	//Packet body is null
	body[packlen++] = ASN1_TYPE_NULL;
	body[packlen++] = 0;
	
	BEREndSequence(body, packlen, varbind_len_ptr);								//Patch up length fields
	BEREndSequence(body, packlen, varbind_list_len_ptr);
	BEREndSequence(body, packlen, body_len_ptr);
	BEREndSequence(body, packlen, packet_len_ptr);
	
	//Send the frame
	if(packlen != send(m_socket, body, packlen, 0))
	{
		perror("send failure\n");
		return 0;
	}
	
	return reqid;
}

/**
	@return true on valid packet
 */
bool PDUController::RecvSnmpGetResponse(
		unsigned int& request_id,
		unsigned short& oid_table,
		unsigned short& oid_index,
		unsigned int& value)
{
	//Receive it
	unsigned char body[2048] = {0};
	memset(body, 0, sizeof(body));
	int rlen = recv(m_socket, body, 2048, 0);
	if(rlen < 0)
	{
		perror("recv failure");
		return false;
	}
	
	//Process the packet
	unsigned int pos = 0;
	unsigned int type;
	unsigned int len;
	if(0 != BERDecodeChunkHeader(body, &pos,	&type, &len))
		return false;
	if(type != ASN1_TYPE_SEQUENCE_CONSTRUCTED)
		return false;
		unsigned int snmp_version;
	if(0 != BERDecodeExpectedInteger(body, &pos, &snmp_version))
		return false;
	if(snmp_version != SNMP_VERSION_2C)
		return false;
	if(0 != BERDecodeChunkHeader(body, &pos,	&type, &len))
		return false;
	if(type != ASN1_TYPE_OCTET_STRING)
		return false;
	char community[32];
	if(0 != BERDecodeString(body, &pos, len, sizeof(community), (unsigned char*)community))
		return false;
	//don't check community string
	if(0 != BERDecodeChunkHeader(body, &pos,	&type, &len))
		return false;
	if(type != ASN1_TYPE_SNMP_GETRESPONSE)
		return false;
	unsigned int error_id;
	unsigned int error_index;
	if(0 != BERDecodeExpectedInteger(body, &pos, &request_id))
		return false;
	if(0 != BERDecodeExpectedInteger(body, &pos, &error_id))
		return false;
	if(0 != BERDecodeExpectedInteger(body, &pos, &error_index))
		return false;
	if(0 != BERDecodeChunkHeader(body, &pos,	&type, &len))
		return false;
	if(type != ASN1_TYPE_SEQUENCE_CONSTRUCTED)
		return false;
	if(0 != BERDecodeChunkHeader(body, &pos,	&type, &len))
		return false;
	if(type != ASN1_TYPE_SEQUENCE_CONSTRUCTED)
		return false;
	if(0 != BERDecodeChunkHeader(body, &pos,	&type, &len))
		return false;
	if(type != ASN1_TYPE_OID)
		return false;
	unsigned int oidbuf[24];
	unsigned int oidlen = sizeof(oidbuf)/sizeof(oidbuf[0]);
	if(0 != BERDecodeOID(body, &pos, len, &oidlen, oidbuf) )
		return false;
	if(oidlen != 10)
		return false;
	oid_table = oidbuf[8];
	oid_index = oidbuf[9];
	if(0 != BERDecodeExpectedInteger(body, &pos, &value))
		return false;
	return true;
}

unsigned int PDUController::SendSnmpSetRequest(unsigned short oid_table, unsigned short oid_index, unsigned int value)
{
	//Allocate request IDs, increasing modulo 32 and skipping zero
	unsigned int reqid = m_requestID++;
	if(reqid == 0)
		reqid = m_requestID++;
	
	//Create the get-request packet
	unsigned char body[2048] = {0};
	unsigned int packlen = 0;
	
	//Figure out the OID for this item
	unsigned short oid_entry[]=
	{
		6,	//length
		4, 1, DRAWERSTEAK_PEN, 2, oid_table, oid_index
	};
	
	//Sequence header
	unsigned int packet_len_ptr = 0;
	unsigned int body_len_ptr = 0;
	unsigned int varbind_list_len_ptr = 0;
	unsigned int varbind_len_ptr = 0;
	packlen = BEREncodeSequenceHeader(body, packlen, &packet_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Top-level sequence header
	packlen = BEREncodeInteger(body, packlen, SNMP_VERSION_2C);					//SNMP version 2c
	packlen = BEREncodeString(body, packlen, m_readCommunity.c_str());			//Community string
	packlen = BEREncodeSequenceHeader(body, packlen, &body_len_ptr,				//PDU packet header
		ASN1_TYPE_SNMP_SETREQUEST);
	packlen = BEREncodeInteger(body, packlen, reqid);							//Request ID
	packlen = BEREncodeInteger(body, packlen, 0);								//Error code and index (always zero)
	packlen = BEREncodeInteger(body, packlen, 0);
	packlen = BEREncodeSequenceHeader(body, packlen, &varbind_list_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Varbind list
	packlen = BEREncodeSequenceHeader(body, packlen, &varbind_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Single varbind
	packlen = BEREncodeOID(body, packlen, oid_entry);							//The OID of this value
	
	packlen = BEREncodeInteger(body, packlen, value);
	
	BEREndSequence(body, packlen, varbind_len_ptr);								//Patch up length fields
	BEREndSequence(body, packlen, varbind_list_len_ptr);
	BEREndSequence(body, packlen, body_len_ptr);
	BEREndSequence(body, packlen, packet_len_ptr);
	
	//Send the frame
	if(packlen != send(m_socket, body, packlen, 0))
	{
		perror("send failure\n");
		return 0;
	}
	
	return reqid;
}

void PDUController::OnChannelToggled(int chan)
{
	//go off if error or on, otherwise on
	unsigned int newval = 0;
	if(m_channelstatus[chan] == 0)
		newval = 1;

	BlockingSnmpSet(4, chan+1, newval);
}

void PDUController::OnBreakerLimitChanged(int chan)
{
	int limit = 1000 * m_breakercurrentsliders[chan].get_value();
	if(!BlockingSnmpSet(5, chan+1, limit))
		printf("set failed\n");
}

void PDUController::OnBreakerSpeedChanged(int chan)
{
	BlockingSnmpSet(6, chan+1, m_breakerspeedsliders[chan].get_value());
}
