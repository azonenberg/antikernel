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
#include "PSUWindow.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Initializes the main window
 */
PSUWindow::PSUWindow(PowerSupply* psu, std::string host, int port)
	: m_psu(psu)
{
	//Set title
	char title[256];
	snprintf(title, sizeof(title), "Power supply: %s:%d (%s %s, serial %s)",
		host.c_str(),
		port,
		psu->GetVendor().c_str(),
		psu->GetName().c_str(),
		psu->GetSerial().c_str()
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
	sigc::slot<bool> slot = sigc::bind(sigc::mem_fun(*this, &PSUWindow::OnTimer), 1);
	sigc::connection conn = Glib::signal_timeout().connect(slot, 250);
}

/**
	@brief Application cleanup
 */
PSUWindow::~PSUWindow()
{
}

/**
	@brief Helper function for creating widgets and setting up signal handlers
 */
void PSUWindow::CreateWidgets()
{
	//Set up window hierarchy
	add(m_vbox);
	for(int i=0; i<m_psu->GetPowerChannelCount(); i++)
	{
		//Create boxes
		m_hseps.push_back(Gtk::HSeparator());
		m_vhboxes.push_back(Gtk::HBox());
		m_vmhboxes.push_back(Gtk::HBox());
		m_chanhboxes.push_back(Gtk::HBox());
		m_voltboxes.push_back(Gtk::VBox());
		m_currboxes.push_back(Gtk::VBox());
		m_ihboxes.push_back(Gtk::HBox());
		m_imhboxes.push_back(Gtk::HBox());

		//Create and set up labels and controls
		m_channelLabels.push_back(Gtk::Label());
			m_channelLabels[i].set_text(m_psu->GetPowerChannelName(i));
			m_channelLabels[i].set_alignment(0, 0.5);
			m_channelLabels[i].override_font(Pango::FontDescription("sans bold 24"));
		m_voltageLabels.push_back(Gtk::Label());
			m_voltageLabels[i].set_text("Voltage (nominal)");
		m_mvoltageLabels.push_back(Gtk::Label());
			m_mvoltageLabels[i].set_text("Voltage (measured)");
		m_voltageValueLabels.push_back(Gtk::Label());
			m_voltageValueLabels[i].set_alignment(0, 0.5);
			m_voltageValueLabels[i].override_font(Pango::FontDescription("monospace bold 32"));
			m_voltageValueLabels[i].set_text("---");
		m_currentLabels.push_back(Gtk::Label());
			m_currentLabels[i].set_text("Current (nominal)");
		m_mcurrentLabels.push_back(Gtk::Label());
			m_mcurrentLabels[i].set_text("Current (measured)");
		m_mcurrentLabels.push_back(Gtk::Label());
			m_mcurrentLabels[i].set_text("Current (measured)");
		m_currentValueLabels.push_back(Gtk::Label());
			m_currentValueLabels[i].set_alignment(0, 0.5);
			m_currentValueLabels[i].override_font(Pango::FontDescription("monospace bold 32"));
			m_currentValueLabels[i].set_text("---");

		m_voltboxes[i].set_size_request(500, -1);
		m_currboxes[i].set_size_request(500, -1);

		//Pack stuff
		m_vbox.pack_start(m_hseps[i], Gtk::PACK_SHRINK);
		m_vbox.pack_start(m_channelLabels[i], Gtk::PACK_SHRINK);
		m_vbox.pack_start(m_chanhboxes[i], Gtk::PACK_SHRINK);
			m_chanhboxes[i].pack_start(m_voltboxes[i]);
				m_voltboxes[i].pack_start(m_vhboxes[i], Gtk::PACK_SHRINK);
					m_vhboxes[i].pack_start(m_voltageLabels[i], Gtk::PACK_SHRINK);
				m_voltboxes[i].pack_start(m_vmhboxes[i], Gtk::PACK_SHRINK);
					m_vmhboxes[i].pack_start(m_mvoltageLabels[i], Gtk::PACK_SHRINK);
					m_vmhboxes[i].pack_start(m_voltageValueLabels[i], Gtk::PACK_SHRINK);
			m_chanhboxes[i].pack_start(m_currboxes[i]);
				m_currboxes[i].pack_start(m_ihboxes[i], Gtk::PACK_SHRINK);
					m_ihboxes[i].pack_start(m_currentLabels[i], Gtk::PACK_SHRINK);
				m_currboxes[i].pack_start(m_imhboxes[i], Gtk::PACK_SHRINK);
					m_imhboxes[i].pack_start(m_mcurrentLabels[i], Gtk::PACK_SHRINK);
					m_imhboxes[i].pack_start(m_currentValueLabels[i], Gtk::PACK_SHRINK);

	}
	/*	m_hbox.pack_start(m_vbox, Gtk::PACK_SHRINK);
			int labelWidth = 75;
			m_vbox.pack_start(m_signalSourceBox, Gtk::PACK_SHRINK);
				m_signalSourceBox.pack_start(m_signalSourceLabel, Gtk::PACK_SHRINK);
					m_signalSourceLabel.set_text("Input");
					m_signalSourceLabel.set_size_request(labelWidth, -1);
				m_signalSourceBox.pack_start(m_signalSourceSelector, Gtk::PACK_SHRINK);
					int count = m_psu->GetMeterChannelCount();
					for(int i=0; i<count; i++)
						m_signalSourceSelector.append(m_psu->GetMeterChannelName(i));
					int cur_chan = m_psu->GetCurrentMeterChannel();
					m_signalSourceSelector.set_active_text(m_psu->GetMeterChannelName(cur_chan));
			m_vbox.pack_start(m_measurementTypeBox, Gtk::PACK_SHRINK);
				m_measurementTypeBox.pack_start(m_measurementTypeLabel, Gtk::PACK_SHRINK);
					m_measurementTypeLabel.set_text("Mode");
					m_measurementTypeLabel.set_size_request(labelWidth, -1);
				m_measurementTypeBox.pack_start(m_measurementTypeSelector, Gtk::PACK_SHRINK);
					unsigned int type = m_psu->GetMeasurementTypes();
					if(type & Multipsu::DC_VOLTAGE)
						m_measurementTypeSelector.append("Voltage");
					if(type & Multipsu::DC_RMS_AMPLITUDE)
						m_measurementTypeSelector.append("RMS (DC couple)");
					if(type & Multipsu::AC_RMS_AMPLITUDE)
						m_measurementTypeSelector.append("RMS (AC couple)");
					if(type & Multipsu::FREQUENCY)
						m_measurementTypeSelector.append("Frequency");
					switch(m_psu->GetMeterMode())
					{
						case Multipsu::DC_VOLTAGE:
							m_measurementTypeSelector.set_active_text("Voltage");
							break;

						case Multipsu::DC_RMS_AMPLITUDE:
							m_measurementTypeSelector.set_active_text("RMS (DC couple)");
							break;

						case Multipsu::AC_RMS_AMPLITUDE:
							m_measurementTypeSelector.set_active_text("RMS (AC couple)");
							break;

						case Multipsu::FREQUENCY:
							m_measurementTypeSelector.set_active_text("Frequency");
							break;
					}
			m_vbox.pack_start(m_autoRangeBox, Gtk::PACK_SHRINK);
				m_autoRangeBox.pack_start(m_autoRangeLabel, Gtk::PACK_SHRINK);
					m_autoRangeLabel.set_text("Auto-range");
					m_autoRangeLabel.set_size_request(labelWidth, -1);
				m_autoRangeBox.pack_start(m_autoRangeSelector, Gtk::PACK_SHRINK);
					m_autoRangeSelector.set_active(m_psu->GetMeterAutoRange());
		m_hbox.pack_start(m_measurementBox, Gtk::PACK_EXPAND_WIDGET);
			m_measurementBox.pack_start(m_voltageLabel, Gtk::PACK_EXPAND_WIDGET);
				m_voltageLabel.override_font(Pango::FontDescription("monospace bold 32"));
				m_voltageLabel.set_alignment(0, 0.5);
				m_voltageLabel.set_size_request(500, -1);
			m_measurementBox.pack_start(m_vppLabel, Gtk::PACK_EXPAND_WIDGET);
				m_vppLabel.override_font(Pango::FontDescription("monospace bold 32"));
				m_vppLabel.set_alignment(0, 0.5);
				m_vppLabel.set_size_request(500, -1);
			m_measurementBox.pack_start(m_frequencyLabel, Gtk::PACK_EXPAND_WIDGET);
				m_frequencyLabel.override_font(Pango::FontDescription("monospace bold 32"));
				m_frequencyLabel.set_alignment(0, 0.5);
				m_frequencyLabel.set_size_request(500, -1);

	//Event handlers
	m_signalSourceSelector.signal_changed().connect(sigc::mem_fun(*this, &PSUWindow::OnSignalSourceChanged));
	m_measurementTypeSelector.signal_changed().connect(sigc::mem_fun(*this, &PSUWindow::OnMeasurementTypeChanged));
	m_autoRangeSelector.signal_toggled().connect(sigc::mem_fun(*this, &PSUWindow::OnAutoRangeChanged));

	//TODO: autorange checkbox
	*/

	show_all();
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers
/*
void PSUWindow::OnAutoRangeChanged()
{
	m_psu->SetMeterAutoRange(m_autoRangeSelector.get_active());
}
*/
void PSUWindow::on_show()
{
	Gtk::Window::on_show();
}

void PSUWindow::on_hide()
{
	Gtk::Window::on_hide();
}


bool PSUWindow::OnTimer(int /*timer*/)
{
	try
	{
		char tmp[128];
		for(int i=0; i<m_psu->GetPowerChannelCount(); i++)
		{
			double v = m_psu->GetPowerVoltageActual(i);
			if(fabs(v) < 1)
				snprintf(tmp, sizeof(tmp), "%5.1f   mV", v * 1000);
			else
				snprintf(tmp, sizeof(tmp), "%7.3f  V", v);
			m_voltageValueLabels[i].set_text(tmp);

			double c = m_psu->GetPowerCurrentActual(i);
			if(i == 0)//fabs(c) < 1)
				snprintf(tmp, sizeof(tmp), "%4.1f  mA", c * 1000);
			else
				snprintf(tmp, sizeof(tmp), "%6.3f A", c);
			m_currentValueLabels[i].set_text(tmp);
		}
	}

	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
	}

	//false to stop timer
	return true;
}
