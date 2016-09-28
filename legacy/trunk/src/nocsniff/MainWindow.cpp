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
	@brief Implementation of main application window class
 */

#include "nocsniff.h"
#include "MainWindow.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Initializes the main window
 */
MainWindow::MainWindow(
	std::string hostname,
	int port,
	NOCPacketSniffer& sniff,
	NameServer& namesrvr,
	std::string sniffname,
	std::string nocgenfile)
	: m_sniffer(sniff)
	, m_namesrvr(namesrvr)
	, m_sniffname(sniffname)
	, m_btnStart(Gtk::Stock::YES)
	, m_btnClear(Gtk::Stock::REFRESH)
	, m_btnFilter(Gtk::Stock::PROPERTIES)
	, m_packetview(this)
{
	//Set title
	char title[256];
	snprintf(title, sizeof(title), "%s:%d (%s)",
		hostname.c_str(),
		port,
		sniffname.c_str()
		);
	set_title(title);
	
	//Initial setup
	set_reallocate_redraws(true);
	set_default_size(1600, 800);

	//Add widgets
	CreateWidgets();
	
	//Done adding widgets
	show_all();
	
	//if(m_namesrvr != NULL)
	//	m_namesrvr->LoadHostnames(false);
	
	LoadNocgenFile(nocgenfile);
	
	//Set the update timer
	sigc::slot<bool> slot = sigc::bind(sigc::mem_fun(*this, &MainWindow::OnTimer), 1);
	Glib::signal_timeout().connect(slot, 100);
}

/**
	@brief Application cleanup
 */
MainWindow::~MainWindow()
{
}

/**
	@brief Helper function for creating widgets and setting up signal handlers
 */
void MainWindow::CreateWidgets()
{
	//Set up window hierarchy
	add(m_vbox);
		m_vbox.pack_start(m_toolbar, Gtk::PACK_SHRINK);
			m_toolbar.append(m_btnStart, sigc::mem_fun(*this, &MainWindow::OnStartStop));
				m_btnStart.set_label("Start");
				m_btnStart.set_tooltip_text("Start");
			m_toolbar.append(m_sep1);
			m_toolbar.append(m_btnClear, sigc::mem_fun(*this, &MainWindow::OnClear));
				m_btnClear.set_label("Clear");
				m_btnClear.set_tooltip_text("Clear");
			m_toolbar.append(m_sep2);
			m_toolbar.append(m_btnFilter, sigc::mem_fun(*this, &MainWindow::OnFilter));
				m_btnFilter.set_label("Filter");
				m_btnFilter.set_tooltip_text("Filter");
			m_toolbar.set_toolbar_style(Gtk::TOOLBAR_BOTH);
		m_vbox.pack_start(m_packetscroller);
			m_packetscroller.add(m_packetview);
		m_vbox.pack_start(m_statusbar, Gtk::PACK_SHRINK);
			m_statusbar.set_size_request(-1,16);
			/*
			m_statusbar.pack_start(m_statprogress, Gtk::PACK_SHRINK);
			m_statprogress.set_size_request(200, -1);
			m_statprogress.set_fraction(0);
			m_statprogress.set_show_text();
			*/
		
	m_packetscroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers

bool MainWindow::OnTimer(int /*timer*/)
{
	try
	{
		list<RPCSniffSample> samples;
		list<DMASniffSample> dsamples;
		m_sniffer.PollStatus(samples, dsamples);
		m_packetview.AddSamples(samples, m_namesrvr);
		m_packetview.AddSamples(dsamples, m_namesrvr);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
	}
		
	//false to stop timer
	return true;
}

void MainWindow::OnStartStop()
{
}

void MainWindow::OnClear()
{
}

void MainWindow::OnFilter()
{
}

void MainWindow::LoadNocgenFile(std::string nocgenfile)
{
	printf("Loading nocgen file %s\n", nocgenfile.c_str());
	m_nodetypes["sysinfo"] = "NOCSysinfo";
	m_nodetypes["namesrvr"] = "NOCNameServer";
	
	FILE* fp = fopen(nocgenfile.c_str(), "r");
	if(!fp)
	{
		printf("    Couldn't open file, skipping\n");
		return;
	}
	
	char line[2048];
	char nodename[128];
	char nodetype[128];
	while(fgets(line, sizeof(line), fp))
	{
		//Look for "node" commands
		if(strstr(line, "node") != line)
			continue;
		if(2 != sscanf(line, "node %127s %127s", nodename, nodetype))
			continue;
			
		m_nodetypes[nodename] = nodetype;
	}
	
	fclose(fp);
	
	printf("    nocgen script loaded\n");
}
