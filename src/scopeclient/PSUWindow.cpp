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
	sigc::connection conn = Glib::signal_timeout().connect(slot, 500);
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
		m_vbox.pack_start(m_masterEnableHbox, Gtk::PACK_SHRINK);
			m_masterEnableHbox.pack_start(m_masterEnableLabel, Gtk::PACK_SHRINK);
				m_masterEnableLabel.set_label("Master");
				m_masterEnableLabel.set_halign(Gtk::ALIGN_START);
				m_masterEnableLabel.set_size_request(150, -1);
				m_masterEnableLabel.override_font(Pango::FontDescription("sans bold 24"));
			m_masterEnableHbox.pack_start(m_masterEnableButton, Gtk::PACK_SHRINK);
				m_masterEnableButton.override_font(Pango::FontDescription("sans bold 24"));
				m_masterEnableButton.set_active(m_psu->GetMasterPowerEnable());
				m_masterEnableButton.set_halign(Gtk::ALIGN_START);
			m_masterEnableHbox.pack_start(m_revertButton, Gtk::PACK_EXPAND_WIDGET);
				m_revertButton.override_font(Pango::FontDescription("sans bold 16"));
				m_revertButton.set_halign(Gtk::ALIGN_END);
				m_revertButton.set_label("Revert");
				m_revertButton.set_image_from_icon_name("gtk-clear");
			m_masterEnableHbox.pack_start(m_commitButton, Gtk::PACK_SHRINK);
				m_commitButton.override_font(Pango::FontDescription("sans bold 16"));
				m_commitButton.set_halign(Gtk::ALIGN_END);
				m_commitButton.set_label("Commit");
				m_commitButton.set_image_from_icon_name("gtk-execute");
	for(int i=0; i<m_psu->GetPowerChannelCount(); i++)
	{
		//Create boxes
		m_hseps.push_back(Gtk::HSeparator());
		m_vhboxes.push_back(Gtk::HBox());
		m_channelLabelHboxes.push_back(Gtk::HBox());
		m_vmhboxes.push_back(Gtk::HBox());
		m_chanhboxes.push_back(Gtk::HBox());
		m_voltboxes.push_back(Gtk::VBox());
		m_currboxes.push_back(Gtk::VBox());
		m_ihboxes.push_back(Gtk::HBox());
		m_imhboxes.push_back(Gtk::HBox());

		//Create and set up labels and controls
		m_channelLabels.push_back(Gtk::Label());
			m_channelLabels[i].set_text(m_psu->GetPowerChannelName(i));
			m_channelLabels[i].set_halign(Gtk::ALIGN_START);
			m_channelLabels[i].override_font(Pango::FontDescription("sans bold 24"));
			m_channelLabels[i].set_size_request(150, -1);
		m_channelEnableButtons.push_back(Gtk::Switch());
			m_channelEnableButtons[i].override_font(Pango::FontDescription("sans bold 16"));
			m_channelEnableButtons[i].set_halign(Gtk::ALIGN_START);
		m_voltageLabels.push_back(Gtk::Label());
			m_voltageLabels[i].set_text("Voltage (nominal)");
			m_voltageLabels[i].set_size_request(150, -1);
		m_voltageEntries.push_back(Gtk::Entry());
			m_voltageEntries[i].set_width_chars(6);
			m_voltageEntries[i].override_font(Pango::FontDescription("monospace bold 32"));
		m_mvoltageLabels.push_back(Gtk::Label());
			m_mvoltageLabels[i].set_text("Voltage (measured)");
			m_mvoltageLabels[i].set_size_request(150, -1);
		m_voltageValueLabels.push_back(Gtk::Label());
			m_voltageValueLabels[i].set_alignment(0, 0.5);
			m_voltageValueLabels[i].override_font(Pango::FontDescription("monospace bold 32"));
			m_voltageValueLabels[i].set_text("---");
		m_currentLabels.push_back(Gtk::Label());
			m_currentLabels[i].set_text("Current (nominal)");
			m_currentLabels[i].set_size_request(150, -1);
		m_currentEntries.push_back(Gtk::Entry());
			m_currentEntries[i].set_width_chars(6);
			m_currentEntries[i].override_font(Pango::FontDescription("monospace bold 32"));
		m_mcurrentLabels.push_back(Gtk::Label());
			m_mcurrentLabels[i].set_text("Current (measured)");
			m_mcurrentLabels[i].set_size_request(150, -1);
		m_currentValueLabels.push_back(Gtk::Label());
			m_currentValueLabels[i].set_alignment(0, 0.5);
			m_currentValueLabels[i].override_font(Pango::FontDescription("monospace bold 32"));
			m_currentValueLabels[i].set_text("---");
		m_channelStatusLabels.push_back(Gtk::Label());
			m_channelStatusLabels[i].set_halign(Gtk::ALIGN_END);
			m_channelStatusLabels[i].set_text("--");
			m_channelStatusLabels[i].override_font(Pango::FontDescription("sans bold 24"));

		m_voltboxes[i].set_size_request(500, -1);
		m_currboxes[i].set_size_request(500, -1);

		m_hseps[i].set_size_request(-1, 15);

		//Pack stuff
		m_vbox.pack_start(m_hseps[i], Gtk::PACK_EXPAND_WIDGET);
		m_vbox.pack_start(m_channelLabelHboxes[i], Gtk::PACK_SHRINK);
			m_channelLabelHboxes[i].pack_start(m_channelLabels[i], Gtk::PACK_SHRINK);
			m_channelLabelHboxes[i].pack_start(m_channelEnableButtons[i], Gtk::PACK_SHRINK);
			m_channelLabelHboxes[i].pack_start(m_channelStatusLabels[i], Gtk::PACK_EXPAND_WIDGET);
		m_vbox.pack_start(m_chanhboxes[i], Gtk::PACK_SHRINK);
			m_chanhboxes[i].pack_start(m_voltboxes[i]);
				m_voltboxes[i].pack_start(m_vhboxes[i], Gtk::PACK_SHRINK);
					m_vhboxes[i].pack_start(m_voltageLabels[i], Gtk::PACK_SHRINK);
					m_vhboxes[i].pack_start(m_voltageEntries[i]);
				m_voltboxes[i].pack_start(m_vmhboxes[i], Gtk::PACK_SHRINK);
					m_vmhboxes[i].pack_start(m_mvoltageLabels[i], Gtk::PACK_SHRINK);
					m_vmhboxes[i].pack_start(m_voltageValueLabels[i], Gtk::PACK_SHRINK);
			m_chanhboxes[i].pack_start(m_currboxes[i]);
				m_currboxes[i].pack_start(m_ihboxes[i], Gtk::PACK_SHRINK);
					m_ihboxes[i].pack_start(m_currentLabels[i], Gtk::PACK_SHRINK);
					m_ihboxes[i].pack_start(m_currentEntries[i]);
				m_currboxes[i].pack_start(m_imhboxes[i], Gtk::PACK_SHRINK);
					m_imhboxes[i].pack_start(m_mcurrentLabels[i], Gtk::PACK_SHRINK);
					m_imhboxes[i].pack_start(m_currentValueLabels[i], Gtk::PACK_SHRINK);

		//Event handlers
		m_channelEnableButtons[i].property_active().signal_changed().connect(
			sigc::bind<int>(sigc::mem_fun(*this, &PSUWindow::OnChannelEnableChanged), i));

		m_voltageEntries[i].signal_changed().connect(
			sigc::bind<int>(sigc::mem_fun(*this, &PSUWindow::OnChannelVoltageChanged), i));
		m_currentEntries[i].signal_changed().connect(
			sigc::bind<int>(sigc::mem_fun(*this, &PSUWindow::OnChannelCurrentChanged), i));
	}

	//Revert changes (clear background and load all "nominal" text boxes with the right values
	OnRevertChanges();

	//Event handlers
	m_masterEnableButton.property_active().signal_changed().connect(
		sigc::mem_fun(*this, &PSUWindow::OnMasterEnableChanged));
	m_commitButton.signal_clicked().connect(
		sigc::mem_fun(*this, &PSUWindow::OnCommitChanges));
	m_revertButton.signal_clicked().connect(
		sigc::mem_fun(*this, &PSUWindow::OnRevertChanges));

	show_all();
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers

void PSUWindow::OnMasterEnableChanged()
{
	m_psu->SetMasterPowerEnable(m_masterEnableButton.get_active());
}

void PSUWindow::OnCommitChanges()
{
	for(int i=0; i<m_psu->GetPowerChannelCount(); i++)
	{
		m_psu->SetPowerVoltage(i, atof(m_voltageEntries[i].get_text().c_str()));
		m_psu->SetPowerCurrent(i, atof(m_currentEntries[i].get_text().c_str()));
	}

	//reload text boxes with proper formatting
	OnRevertChanges();
}

void PSUWindow::OnRevertChanges()
{
	char tmp[128];
	for(int i=0; i<m_psu->GetPowerChannelCount(); i++)
	{
		snprintf(tmp, sizeof(tmp), "%7.3f", m_psu->GetPowerVoltageNominal(i));
		m_voltageEntries[i].set_text(tmp);

		snprintf(tmp, sizeof(tmp), "%6.3f", m_psu->GetPowerCurrentNominal(i));
		m_currentEntries[i].set_text(tmp);

		//clear to white
		m_voltageEntries[i].override_background_color(Gdk::RGBA("#ffffff"));
		m_currentEntries[i].override_background_color(Gdk::RGBA("#ffffff"));
	}
}

void PSUWindow::OnChannelVoltageChanged(int i)
{
	//make yellow to indicate uncommitted changes
	m_voltageEntries[i].override_background_color(Gdk::RGBA("#ffffa0"));
}

void PSUWindow::OnChannelCurrentChanged(int i)
{
	//make yellow to indicate uncommitted changes
	m_currentEntries[i].override_background_color(Gdk::RGBA("#ffffa0"));
}

void PSUWindow::OnChannelEnableChanged(int i)
{
	m_psu->SetPowerChannelActive(i, m_channelEnableButtons[i].get_active());
}

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
		//Master enable
		m_masterEnableButton.set_active(m_psu->GetMasterPowerEnable());

		char tmp[128];
		for(int i=0; i<m_psu->GetPowerChannelCount(); i++)
		{
			//Channel voltage
			double v = m_psu->GetPowerVoltageActual(i);
			if(fabs(v) < 1)
				snprintf(tmp, sizeof(tmp), "%5.1f   mV", v * 1000);
			else
				snprintf(tmp, sizeof(tmp), "%7.3f  V", v);
			m_voltageValueLabels[i].set_text(tmp);

			//Channel current
			double c = m_psu->GetPowerCurrentActual(i);
			if(fabs(c) < 1)
				snprintf(tmp, sizeof(tmp), "%4.1f  mA", c * 1000);
			else
				snprintf(tmp, sizeof(tmp), "%6.3f A", c);
			m_currentValueLabels[i].set_text(tmp);

			//Channel enable
			bool enabled = m_psu->GetPowerChannelActive(i);
			m_channelEnableButtons[i].set_active(enabled);

			//Channel status
			if(!enabled)
			{
				m_channelStatusLabels[i].set_label("--");
				m_channelStatusLabels[i].override_color(Gdk::RGBA("#000000"));
			}

			else if(m_psu->IsPowerConstantCurrent(i))
			{
				m_channelStatusLabels[i].set_label("CC");
				m_channelStatusLabels[i].override_color(Gdk::RGBA("#ff0000"));
			}

			else
			{
				m_channelStatusLabels[i].set_label("CV");
				m_channelStatusLabels[i].override_color(Gdk::RGBA("#00a000"));
			}
		}
	}

	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
	}

	//false to stop timer
	return true;
}
