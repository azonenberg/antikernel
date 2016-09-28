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
	@brief Main application window class
 */

#ifndef MainWindow_h
#define MainWindow_h

#include "PacketView.h"
#include "../jtaghal/NOCPacketSniffer.h"

/**
	@brief Main application window class
 */
class MainWindow	: public Gtk::Window
{
public:

	MainWindow(
		std::string hostname,
		int port,
		NOCPacketSniffer& sniff,
		NameServer& namesrvr,
		std::string sniffname,
		std::string nocgenfile);
	~MainWindow();
	
	std::string GetNodeType(std::string name)
	{
		return m_nodetypes[name];
	}
	
	unsigned int GetSysclkPeriod()
	{ return m_sniffer.GetSysclkPeriod(); }
	
protected:
	
	void LoadNocgenFile(std::string nocgenfile);

	NOCPacketSniffer& m_sniffer;
	NameServer& m_namesrvr;
	std::string m_sniffname;

	//Initialization
	void CreateWidgets();
		
	//Widgets
	Gtk::VBox m_vbox;
		Gtk::Toolbar m_toolbar;
			Gtk::ToolButton m_btnStart;
			Gtk::SeparatorToolItem m_sep1;
			Gtk::ToolButton m_btnClear;
			Gtk::SeparatorToolItem m_sep2;
			Gtk::ToolButton m_btnFilter;
		Gtk::ScrolledWindow m_packetscroller;
			PacketView m_packetview;
		Gtk::Statusbar m_statusbar;
	
	//Status polling
	bool OnTimer(int timer);
	
	//Message handlers
	void OnStartStop();
	void OnClear();
	void OnFilter();
	
	std::map<std::string, std::string> m_nodetypes;
};

#endif
