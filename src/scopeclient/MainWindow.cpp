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

#include "scopeclient.h"
#include "MainWindow.h"
#include "../scopehal/AnalogRenderer.h"
#include "ProtocolDecoderDialog.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Initializes the main window
 */
MainWindow::MainWindow(Oscilloscope* scope, std::string host, int port, NameServer* namesrvr)
	: m_btnZoomOut(Gtk::Stock::ZOOM_OUT)
	, m_btnZoomIn(Gtk::Stock::ZOOM_IN)
	, m_btnZoomFit(Gtk::Stock::ZOOM_FIT)
	, m_btnStart(Gtk::Stock::YES)
	, m_btnDecode(Gtk::Stock::CONVERT)
	, m_channelview(this)
	, m_view(scope, this)
	, m_scope(scope)
	, m_namesrvr(namesrvr)
{
	//Set title
	char title[256];
	snprintf(title, sizeof(title), "%s:%d (%s %s, serial %s)",
		host.c_str(),
		port,
		scope->GetVendor().c_str(),
		scope->GetName().c_str(),
		scope->GetSerial().c_str()
		);
	set_title(title);
	
	//Initial setup
	set_reallocate_redraws(true);
	set_default_size(1280, 800);

	//Add widgets
	CreateWidgets();
	
	//Done adding widgets
	show_all();
	
	//if(m_namesrvr != NULL)
	//	m_namesrvr->LoadHostnames(false);
	
	//Set the update timer
	sigc::slot<bool> slot = sigc::bind(sigc::mem_fun(*this, &MainWindow::OnTimer), 1);
	sigc::connection conn = Glib::signal_timeout().connect(slot, 250);
	
	//Set up display time scale
	m_timescale = 0;
	m_waiting = false;
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
			m_toolbar.append(m_btnZoomOut, sigc::mem_fun(*this, &MainWindow::OnZoomOut));
				m_btnZoomOut.set_tooltip_text("Zoom out");
			m_toolbar.append(m_btnZoomIn, sigc::mem_fun(*this, &MainWindow::OnZoomIn));
				m_btnZoomIn.set_tooltip_text("Zoom in");
			m_toolbar.append(m_btnZoomFit, sigc::mem_fun(*this, &MainWindow::OnZoomFit));
				m_btnZoomFit.set_tooltip_text("Zoom fit");
			m_toolbar.append(m_sep1);
			m_toolbar.append(m_btnStart, sigc::mem_fun(*this, &MainWindow::OnStart));
				m_btnStart.set_tooltip_text("Start capture");
			m_toolbar.append(m_sep2);
			m_toolbar.append(m_btnDecode, sigc::mem_fun(*this, &MainWindow::OnDecode));
				m_btnDecode.set_tooltip_text("Protocol decode");
		m_vbox.pack_start(m_vscroller);
			m_vscroller.add(m_splitter);
				m_splitter.pack1(m_channelview);
				m_splitter.pack2(m_viewscroller);
					m_viewscroller.add(m_view);
				m_splitter.set_position(200);
		m_vbox.pack_start(m_statusbar, Gtk::PACK_SHRINK);
			m_statusbar.set_size_request(-1,16);
			m_statusbar.pack_start(m_statprogress, Gtk::PACK_SHRINK);
			m_statprogress.set_size_request(200, -1);
			m_statprogress.set_fraction(0);
			m_statprogress.set_show_text();
					
	//Set dimensions
	m_vscroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
	m_viewscroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_NEVER);
	
	//Set up message handlers
	m_viewscroller.get_hadjustment()->signal_value_changed().connect(sigc::mem_fun(*this, &MainWindow::OnScopeScroll));
	m_viewscroller.get_vadjustment()->signal_value_changed().connect(sigc::mem_fun(*this, &MainWindow::OnScopeScroll));
	m_viewscroller.get_hadjustment()->set_step_increment(50);
	
	//Refresh the views
	//Need to refresh main view first so we have renderers to reference in the channel list
	m_view.Refresh();
	m_channelview.Refresh();
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers

bool MainWindow::OnTimer(int /*timer*/)
{
	try
	{
		m_statprogress.set_fraction(0);
		
		static int i = 0;
		i ++;
		i %= 10;
		
		if(m_waiting)
		{
			//m_statprogress.set_text("Ready");
			string str = "Ready";
			for(int j=0; j<i; j++)
				str += ".";
			m_statprogress.set_text(str);
			
			//Poll the trigger status of the scope
			Oscilloscope::TriggerMode status = m_scope->PollTrigger();
			if(status > Oscilloscope::TRIGGER_MODE_COUNT)
			{
				//Invalid value, skip it
				return true;
			}
			
			//If not TRIGGERED, do nothing
			if(status != Oscilloscope::TRIGGER_MODE_TRIGGERED)
				return true;
				
			m_statprogress.set_text("Triggered");
			
			//Triggered - get the data from each channel
			m_scope->AcquireData(sigc::mem_fun(*this, &MainWindow::OnCaptureProgressUpdate));
			
			//Set to a sane zoom if this is our first capture
			//otherwise keep time scale unchanged
			if(m_timescale == 0)
				OnZoomFit();
			
			//Refresh display
			m_view.SetSizeDirty();
			m_view.queue_draw();
			
			m_waiting = false;
		}
		else
			m_statprogress.set_text("Stopped");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
	}
		
	//false to stop timer
	return true;
}

void MainWindow::OnZoomOut()
{
	//Get center of current view
	float fract = m_viewscroller.get_hadjustment()->get_value() / m_viewscroller.get_hadjustment()->get_upper();
	
	//Change zoom
	m_timescale /= 1.5;
	OnZoomChanged();
	
	//Dispatch the draw events
	while(Gtk::Main::events_pending())
		Gtk::Main::iteration();
		
	//Re-scroll
	m_viewscroller.get_hadjustment()->set_value(fract * m_viewscroller.get_hadjustment()->get_upper());
}

void MainWindow::OnZoomIn()
{
	//Get center of current view
	float fract = m_viewscroller.get_hadjustment()->get_value() / m_viewscroller.get_hadjustment()->get_upper();
	
	//Change zoom	
	m_timescale *= 1.5;
	OnZoomChanged();
	
	//Dispatch the draw events
	while(Gtk::Main::events_pending())
		Gtk::Main::iteration();
		
	//Re-scroll
	m_viewscroller.get_hadjustment()->set_value(fract * m_viewscroller.get_hadjustment()->get_upper());
}

void MainWindow::OnZoomFit()
{
	if( (m_scope->GetChannelCount() != 0) && (m_scope->GetChannel(0) != NULL) && (m_scope->GetChannel(0)->GetData() != NULL))
	{
		CaptureChannelBase* capture = m_scope->GetChannel(0)->GetData();
		int64_t capture_len = capture->m_timescale * capture->GetEndTime();
		m_timescale = static_cast<float>(m_viewscroller.get_width()) / capture_len;
	}
	
	OnZoomChanged();	
}

void MainWindow::OnZoomChanged()
{
	for(size_t i=0; i<m_scope->GetChannelCount(); i++)
		m_scope->GetChannel(i)->m_timescale = m_timescale;
	
	m_view.SetSizeDirty();
	m_view.queue_draw();
}

void MainWindow::OnDecode()
{
	try
	{
		ProtocolDecoderDialog dlg(this, m_scope, *m_namesrvr);
		if(Gtk::RESPONSE_OK != dlg.run())
			return;
		
		//Get the decoder and add it
		ProtocolDecoder* decoder = dlg.Detach();
		if(decoder != NULL)
		{
			decoder->Refresh();
			m_scope->AddChannel(decoder);
		
			m_channelview.AddChannel(decoder);
			m_view.Refresh();
		}
	}
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		//exit(1);
	}
}

void MainWindow::OnScopeScroll()
{
	//TODO
	//printf("Scroll: Position = %.2lf\n", m_viewscroller.get_hadjustment()->get_value());
}

int MainWindow::OnCaptureProgressUpdate(float progress)
{
	m_statprogress.set_fraction(progress);
	
	//Dispatch pending gtk events (such as draw calls)
	while(Gtk::Main::events_pending())
		Gtk::Main::iteration();
	
	return 0;
}

void MainWindow::OnStart()
{
	try
	{
		//Load trigger conditions from sidebar
		m_channelview.UpdateTriggers();
		
		//Start the capture
		m_scope->StartSingleTrigger();
		m_waiting = true;
		
		//Print to stdout so scripts know we're ready
		printf("Ready\n");
		fflush(stdout);
	}
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
	}
}
