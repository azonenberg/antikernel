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

#include "tdrview.h"
#include "MainWindow.h"

#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>
#include <NOCSysinfo_constants.h>

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Initializes the main window
 */
MainWindow::MainWindow(std::string host, int port, std::string devname)
	: m_iface(host, port)
	, m_view(this)
{
	//Look up the device
	NameServer nsvr(&m_iface);
	m_addr = nsvr.ForwardLookup(devname);
	
	//Find the sampling frequency
	uint16_t saddr = nsvr.ForwardLookup("sysinfo");
	RPCMessage rmsg;
	m_iface.RPCFunctionCall(saddr, SYSINFO_QUERY_FREQ, 0, 0, 0, rmsg);
	uint32_t sysclk_period = rmsg.data[1];
	m_samplePeriod = sysclk_period / 8;		//8x SERDES ratio
	
	//Set title
	char title[256];
	snprintf(title, sizeof(title), "%s:%d (%s)",
		host.c_str(),
		port,
		devname.c_str()
		);
	set_title(title);
	
	//Initial setup
	set_reallocate_redraws(true);
	set_default_size(1280, 900);

	//Add widgets
	CreateWidgets();
	
	//Done adding widgets
	show_all();

	//Set the update timer
	sigc::slot<bool> slot = sigc::bind(sigc::mem_fun(*this, &MainWindow::OnTimer), 1);
	sigc::connection conn = Glib::signal_timeout().connect(slot, 250);
	
	m_clearbutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnClear));
	
	//Allocate the sample array
	for(int i=0; i<NUM_SAMPLES; i++)
	{
		m_normsamples[i] = new float[DAC_BINS];
		
		m_samples[i] = new unsigned int[DAC_BINS];
		for(int j=0; j<DAC_BINS; j++)
			m_samples[i][j] = 0;
	}
	
	m_terminating = false;
	m_sampleThread = thread(bind(&MainWindow::SampleThread, this));
}

/**
	@brief Application cleanup
 */
MainWindow::~MainWindow()
{
	m_terminating = true;
	m_sampleThread.join();
	
	for(int i=0; i<NUM_SAMPLES; i++)
		delete[] m_samples[i];
	for(int i=0; i<NUM_SAMPLES; i++)
		delete[] m_normsamples[i];
}

/**
	@brief Helper function for creating widgets and setting up signal handlers
 */
void MainWindow::CreateWidgets()
{	
	//Set up window hierarchy
	add(m_vbox);
		m_vbox.pack_start(m_viewscroller);
			m_viewscroller.add(m_view);
		m_vbox.pack_start(m_statusbar, Gtk::PACK_SHRINK);
			//m_statusbar.set_size_request(-1,16);
			m_statusbar.set_size_request(-1,32);
				m_statusbar.pack_start(m_clearbutton, Gtk::PACK_SHRINK);
					m_clearbutton.set_label("clear");
			/*
			m_statusbar.pack_start(m_statprogress, Gtk::PACK_SHRINK);
			m_statprogress.set_size_request(200, -1);
			m_statprogress.set_fraction(0);
			m_statprogress.set_show_text();
			*/
			
	m_viewscroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers

bool MainWindow::OnTimer(int /*timer*/)
{
	try
	{
		m_view.queue_draw();
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
	}
	
	//false to stop timer
	return true;
}

//TODO: run this in a background thread
void MainWindow::AcquireData()
{
	unsigned int samples[NUM_SAMPLES] = {0};
	for(int i=0; i<NUM_SAMPLES; i++)
		samples[i] = 0;
	
	//Send the startup message
	RPCMessage msg;
	msg.to = m_addr;
	msg.type = RPC_TYPE_INTERRUPT;
	msg.from = 0;
	msg.callnum = 0;
	msg.data[0] = 0;
	msg.data[1] = 0;
	msg.data[2] = 0;
	m_iface.SendRPCMessage(msg);
	
	//for(int i=0; i<dacmax; i += 16)
	//Do narrow range around the center to get better resolution
	//TODO: Higher preamp gain?
	for(unsigned int i=1664; i<2432; i++)
	{		
		//Get the DMA data
		DMAMessage rxm;
		if(!m_iface.RecvDMAMessageBlockingWithTimeout(rxm, 0.5))
		{
			printf("Timeout on ping %u - expected response within 500ms but nothing arrived\n", i);
			throw JtagExceptionWrapper(
				"Message timeout",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);					
		}
		
		if(rxm.address != i)
		{
			printf("bad message (%u, expected %u)\n", i, rxm.address);
			exit(-1);
		}
		
		//Endianness swap
		FlipEndian32Array((unsigned char*)&rxm.data[0], 256);
		
		//If we're true, use this value (search low-high so no need to do a >= check)
		for(int w=0; w<(NUM_SAMPLES/32); w++)
		{
			for(int b=0; b<32; b++)
			{
				if( (rxm.data[w] >> (31-b)) & 1 )
					samples[w*32 + b] = i;
			}
		}
	}
	
	for(int i=0; i<NUM_SAMPLES; i++)
		m_samples[i][samples[i]] ++;
		
	//Create a normalized copy of the sample array
	m_bufmutex.lock();
	
		//First pass: find max value
		unsigned int nmax = 0;
		for(int i=0; i<NUM_SAMPLES; i++)
		{
			for(int j=0; j<DAC_BINS; j++)
			{
				if(m_samples[i][j] > nmax)
					nmax = m_samples[i][j];
			}
		}
	
		//Second pass: normalize
		float inmax = 1.0f / nmax;
		#pragma omp parallel for
		for(int i=0; i<NUM_SAMPLES; i++)
		{
			for(int j=0; j<DAC_BINS; j++)
				m_normsamples[i][j] = m_samples[i][j] * inmax;
		}
	m_bufmutex.unlock();
}

void MainWindow::SampleThread()
{
	while(!m_terminating)
	{
		AcquireData();
	}
}

void MainWindow::OnClear()
{
	m_bufmutex.lock();
	
		#pragma omp parallel for
		for(int i=0; i<NUM_SAMPLES; i++)
		{
			for(int j=0; j<DAC_BINS; j++)
				m_samples[i][j] = 0;
		}

	m_bufmutex.unlock();
}
