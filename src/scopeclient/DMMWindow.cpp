/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
#include "DMMWindow.h"
//#include "../scopehal/AnalogRenderer.h"
#include "ProtocolDecoderDialog.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Initializes the main window
 */
DMMWindow::DMMWindow(Multimeter* meter, std::string host, int port)
	: m_meter(meter)
{
	//Set title
	char title[256];
	snprintf(title, sizeof(title), "Multimeter: %s:%d (%s %s, serial %s)",
		host.c_str(),
		port,
		meter->GetVendor().c_str(),
		meter->GetName().c_str(),
		meter->GetSerial().c_str()
		);
	set_title(title);

	//Initial setup
	set_reallocate_redraws(true);
	set_default_size(640, 240);

	//Add widgets
	CreateWidgets();

	//Done adding widgets
	show_all();

	//Set the update timer
	sigc::slot<bool> slot = sigc::bind(sigc::mem_fun(*this, &DMMWindow::OnTimer), 1);
	sigc::connection conn = Glib::signal_timeout().connect(slot, 1000);
}

/**
	@brief Application cleanup
 */
DMMWindow::~DMMWindow()
{
}

/**
	@brief Helper function for creating widgets and setting up signal handlers
 */
void DMMWindow::CreateWidgets()
{
	//Set up window hierarchy
	add(m_hbox);
		m_hbox.pack_start(m_vbox, Gtk::PACK_SHRINK);
			m_vbox.pack_start(m_signalSourceBox, Gtk::PACK_SHRINK);
				m_signalSourceBox.pack_start(m_signalSourceLabel, Gtk::PACK_SHRINK);
					m_signalSourceLabel.set_text("Input");
					m_signalSourceLabel.set_size_request(50, -1);
				m_signalSourceBox.pack_start(m_signalSourceSelector, Gtk::PACK_SHRINK);
					m_signalSourceSelector.append("FIXME");
			m_vbox.pack_start(m_measurementTypeBox, Gtk::PACK_SHRINK);
				m_measurementTypeBox.pack_start(m_measurementTypeLabel, Gtk::PACK_SHRINK);
					m_measurementTypeLabel.set_text("Mode");
					m_measurementTypeLabel.set_size_request(50, -1);
				m_measurementTypeBox.pack_start(m_measurementTypeSelector, Gtk::PACK_SHRINK);
					unsigned int type = m_meter->GetMeasurementTypes();
					if(type & Multimeter::DC_VOLTAGE)
						m_measurementTypeSelector.append("Voltage");
					if(type & Multimeter::DC_RMS_AMPLITUDE)
						m_measurementTypeSelector.append("RMS (DC couple)");
					if(type & Multimeter::AC_RMS_AMPLITUDE)
						m_measurementTypeSelector.append("RMS (AC couple)");
					if(type & Multimeter::FREQUENCY)
						m_measurementTypeSelector.append("Frequency");
		m_hbox.pack_start(m_voltageLabel, Gtk::PACK_EXPAND_WIDGET);
			m_voltageLabel.override_font(Pango::FontDescription("sans bold 32"));

	//TODO: populate signal source box
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers

bool DMMWindow::OnTimer(int /*timer*/)
{
	try
	{
		double v = m_meter->GetDCVoltage();
		//LogDebug("%f\n", v);

		char tmp[128];
		if(fabs(v) < 1)
			snprintf(tmp, sizeof(tmp), "%.5f mV", v * 1000);
		else
			snprintf(tmp, sizeof(tmp), "%.5f V", v);

		m_voltageLabel.set_text(tmp);
	}

	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
	}

	//false to stop timer
	return true;
}
