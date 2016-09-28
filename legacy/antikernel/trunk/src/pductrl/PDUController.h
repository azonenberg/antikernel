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
	@brief Controller for a single PDU
 */

#ifndef PDUController_h
#define PDUController_h

#include "Graph.h"

/**
	@brief Controller for a single PDU
 */
class PDUController : public Graphable
{
public:
	PDUController(std::string hostname, std::string readCommunity, std::string writeCommunity, Gdk::Color color);
	virtual ~PDUController();

	Gtk::VBox& GetTabVbox()
	{ return m_tabvbox; }
	
	Gtk::Frame& GetHostFrame()
	{ return m_hostframe; }
	
	void OnTimer();
	
protected:

	//Main vertical box for the dedicated tab
	Gtk::VBox m_tabvbox;
		Gtk::Frame m_curframe;
			Gtk::Label m_curframelabel;
			Graph m_curgraph;
			Graphable m_curgraphData[10];
		Gtk::Frame m_voltframe;
			Gtk::Label m_voltframelabel;
			Graph m_voltgraph;
			Graphable m_voltgraphData[2];
		Gtk::Frame m_tempframe;
			Gtk::Label m_tempframelabel;
			Graph m_tempgraph;
			Graphable m_tempgraphData[2];
		Gtk::Frame m_breakerframe;
			Gtk::Label m_breakerframelabel;
			Gtk::HBox m_breakerbox;
				Gtk::Frame m_breakerframes[10];
					Gtk::Label m_breakerframelabels[10];
					Gtk::HBox m_breakerhboxes[10];
						Gtk::VScale m_breakercurrentsliders[10];
						int m_breakercurrentlimits[10];
						Gtk::VScale m_breakerspeedsliders[10];
	
	//Button box for the summary view
	Gtk::Frame m_hostframe;
		Gtk::HBox m_summaryhbox;
			Gtk::VBox m_buttonboxes[10];
				Gtk::Image m_channelimages[10];
				Gtk::Button m_channelbuttons[10];
			Gtk::VBox m_statusbox;
				Gtk::Label m_vlabel;
				Gtk::Label m_ilabel;
				Gtk::Label m_tlabel;
		
	//SNMP info
	std::string m_hostname;
	std::string m_readCommunity;
	std::string m_writeCommunity;
	
	//Socket settings
	int m_socket;
	unsigned int m_requestID;
	
	//SNMP read/write operations
	unsigned int SendSnmpGetRequest(unsigned short oid_table, unsigned short oid_index);
	bool RecvSnmpGetResponse(
		unsigned int& request_id,
		unsigned short& oid_table,
		unsigned short& oid_index,
		unsigned int& value);		
	unsigned int SendSnmpSetRequest(unsigned short oid_table, unsigned short oid_index, unsigned int value);
	bool BlockingSnmpGet(unsigned short oid_table, unsigned short oid_index, unsigned int& value);
	bool BlockingSnmpSet(unsigned short oid_table, unsigned short oid_index, unsigned int value);
	
	//Message handlers
	void OnChannelToggled(int chan);
	void OnBreakerLimitChanged(int chan);
	void OnBreakerSpeedChanged(int chan);
	
	//Cached data
	int m_channelstatus[10];
};

#endif

