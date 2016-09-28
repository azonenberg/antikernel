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

#include "pductrl.h"
#include "MainWindow.h"

using namespace std;

extern const char* g_colorTable[];

////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Initializes the main window
 */
MainWindow::MainWindow()
{
	//Set title
	set_title("PDU Control");
	
	//Initial setup
	set_reallocate_redraws(true);
	set_default_size(1280, 800);

	//Add widgets
	CreateWidgets();
	
	//Done adding widgets
	show_all();

	//Set the update timer
	sigc::slot<bool> slot = sigc::bind(sigc::mem_fun(*this, &MainWindow::OnTimer), 1);
	sigc::connection conn = Glib::signal_timeout().connect(slot, 500);
}

/**
	@brief Application cleanup
 */
MainWindow::~MainWindow()
{
	//Delete per-host stuff
	for(size_t i=0; i<m_controllers.size(); i++)
	{
		m_tabs.remove_page(m_controllers[i]->GetTabVbox());
		m_summarybox.remove(m_controllers[i]->GetHostFrame());
		delete m_controllers[i];
	}
	m_controllers.clear();
}

/**
	@brief Helper function for creating widgets and setting up signal handlers
 */
void MainWindow::CreateWidgets()
{	
	//Set up window hierarchy
	add(m_vbox);
		m_vbox.pack_start(m_indicatorframe, Gtk::PACK_SHRINK);
			m_indicatorframe.set_label_widget(m_indicatorframelabel);
			m_indicatorframelabel.set_markup("<b>Channel Control</b>");
			m_indicatorframe.set_shadow_type(Gtk::SHADOW_NONE);
			m_indicatorframe.add(m_summarybox);
		m_vbox.pack_start(m_tabs, Gtk::PACK_SHRINK);
			m_tabs.append_page(m_overviewtab, "Overview");
				m_overviewtab.pack_start(m_curframe, Gtk::PACK_SHRINK);
					m_curframe.set_label_widget(m_curframelabel);
					m_curframelabel.set_markup("<b>Load Current</b>");
					m_curframe.set_shadow_type(Gtk::SHADOW_NONE);
					m_curframe.add(m_curgraph);
						m_curgraph.set_size_request(100, 200);
						m_curgraph.m_seriesName = "isum";
						m_curgraph.m_units = "A";
						m_curgraph.m_unitScale = 0.001;
						m_curgraph.m_minScale = 0;
						m_curgraph.m_maxScale = 20000;
						m_curgraph.m_scaleBump = 5000;
						m_curgraph.m_minRedline = -1;
						m_curgraph.m_maxRedline = 19500;
				m_overviewtab.pack_start(m_voltframe, Gtk::PACK_SHRINK);
					m_voltframe.set_label_widget(m_voltframelabel);
					m_voltframelabel.set_markup("<b>Average Line Voltage</b>");
					m_voltframe.set_shadow_type(Gtk::SHADOW_NONE);
					m_voltframe.add(m_voltgraph);
						m_voltgraph.set_size_request(100, 200);
						m_voltgraph.m_seriesName = "vavg";
						m_voltgraph.m_units = "V";
						m_voltgraph.m_unitScale = 0.001;
						m_voltgraph.m_minScale = 0;
						m_voltgraph.m_maxScale = 14000;
						m_voltgraph.m_scaleBump = 2000;
						//No redlines on global voltage graph
						m_voltgraph.m_minRedline = -1;
						m_voltgraph.m_maxRedline = 15000;
				m_overviewtab.pack_start(m_tempframe, Gtk::PACK_SHRINK);
					m_tempframe.set_label_widget(m_tempframelabel);
					m_tempframelabel.set_markup("<b>Chassis Temperature</b>");
					m_tempframe.set_shadow_type(Gtk::SHADOW_NONE);
					m_tempframe.add(m_tempgraph);
						m_tempgraph.set_size_request(100, 200);
						m_tempgraph.m_seriesName = "tmax";
						m_tempgraph.m_units = "°C";
						m_tempgraph.m_minScale = 0;
						m_tempgraph.m_maxScale = 80;
						m_tempgraph.m_scaleBump = 20;
						m_tempgraph.m_minRedline = 5;
						m_tempgraph.m_maxRedline = 60;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Channel creation

void MainWindow::AddPDU(std::string hostname, std::string read_community, std::string write_community)
{
	Gdk::Color color;
	color.set(g_colorTable[m_controllers.size() % 10]);
	
	//Create the controller
	PDUController* ctl = new PDUController(hostname, read_community, write_community, color);
	m_controllers.push_back(ctl);
	
	//Add the dedicated tab
	m_tabs.append_page(ctl->GetTabVbox(), hostname);
	ctl->GetTabVbox().show_all();
	
	//Add the summary box
	m_summarybox.pack_start(ctl->GetHostFrame(), Gtk::PACK_SHRINK);
	ctl->GetHostFrame().show_all();
	
	m_tempgraph.m_series.push_back(ctl);
	m_voltgraph.m_series.push_back(ctl);
	m_curgraph.m_series.push_back(ctl);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers

bool MainWindow::OnTimer(int /*timer*/)
{
	for(size_t i=0; i<m_controllers.size(); i++)
		m_controllers[i]->OnTimer();
			
	//false to stop timer
	return true;
}

