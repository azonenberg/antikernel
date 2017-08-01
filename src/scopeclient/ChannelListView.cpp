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
	@brief Implementation of ChannelListView
 */

#include "scopeclient.h"
#include "ChannelListView.h"
#include "MainWindow.h"
//#include "../scopehal/ProtocolDecoder.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

ChannelListView::ChannelListView(MainWindow* parent)
	: m_parent(parent)
{
	//Add column headings
	m_model = Gtk::TreeStore::create(m_columns);
	set_model(m_model);
	//append_column_editable("Enabled", m_columns.enabled);
	append_column_editable("Name", m_columns.name);
	append_column_editable("Trigger on", m_columns.value);

	//Set background color
	Gtk::CellRenderer* render = get_column_cell_renderer(0);
	get_column(0)->add_attribute(*render, "background-gdk", m_columns.color);
	get_column(0)->add_attribute(*render, "height", m_columns.height);
	get_column(0)->add_attribute(*render, "ypad", m_columns.padding);

	//Set up message handlers
	/*static_cast<Gtk::CellRendererToggle*>(get_column_cell_renderer(0))->signal_toggled().connect(
		sigc::mem_fun(*this, &ChannelListView::OnEnabledToggled));*/

	set_headers_visible(true);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Update methods

void ChannelListView::Refresh()
{
	//Get the oscilloscope
	Oscilloscope* pScope = m_parent->GetScope();

	//TODO: figure out how to do protocol decoding as a tree

	//Clean out old stuff
	m_model->clear();

	//Generate channel list
	for(size_t i=0; i<pScope->GetChannelCount(); i++)
	{
		OscilloscopeChannel* chan = pScope->GetChannel(i);
		if(!chan->m_visible)
			continue;
		ChannelRenderer* render = m_parent->GetScopeView().m_renderers[chan];
		if(render == NULL)
			continue;

		Gtk::TreeStore::iterator it = m_model->append();
		it->set_value(0, Gdk::Color(chan->m_displaycolor));
		it->set_value(1, true);		//TODO: is channel enabled?
		it->set_value(2, chan->m_displayname);
		it->set_value(3, chan);
		it->set_value(4, render->m_height + 4);
		it->set_value(5, 6);
		if(i == 0)					//leave extra space for (timescale height - header height)
		{
			it->set_value(4, 37);
			it->set_value(5, 18);
		}
		it->set_value(6, std::string(""));
	}
}

void ChannelListView::AddChannel(OscilloscopeChannel* chan)
{
	Gtk::TreeStore::iterator it = m_model->append();
	it->set_value(0, Gdk::Color(chan->m_displaycolor));
	it->set_value(1, true);		//TODO: is channel enabled?
	it->set_value(2, chan->m_displayname);
	it->set_value(3, chan);
	it->set_value(4, 33);		//TODO: get height + padding
	it->set_value(5, 6);
	it->set_value(6, std::string(""));
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers for editing

void ChannelListView::OnEnabledToggled(const Glib::ustring& path)
{
	//Look up the item
	OscilloscopeChannel* chan;
	m_model->get_iter(path)->get_value(3, chan);
	chan->m_visible = !chan->m_visible;

	//Refresh the scope viewy
	m_parent->GetScopeView().Refresh();
}

void ChannelListView::UpdateTriggers()
{
	//Clear out old triggers
	m_parent->GetScope()->ResetTriggerConditions();

	//Loop over our child nodes
	Gtk::TreeNodeChildren children = m_model->children();
	for(Gtk::TreeNodeChildren::iterator it=children.begin(); it != children.end(); ++it)
	{
		//std::string name = it->get_value(m_columns.name);
		OscilloscopeChannel* chan = it->get_value(m_columns.chan);
		std::string val = it->get_value(m_columns.value);

		//Protocol decoders don't trigger - skip them
		//if(dynamic_cast<ProtocolDecoder*>(chan) != NULL)
		//	continue;

		//Should be a digital channel (analog stuff not supported yet)
		if(chan->GetType() == OscilloscopeChannel::CHANNEL_TYPE_DIGITAL)
		{
			//Initialize trigger vector

			//If string is empty, mark as don't care
			std::vector<Oscilloscope::TriggerType> triggerbits;
			if(val == "")
			{
				for(int i=0; i<chan->GetWidth(); i++)
					triggerbits.push_back(Oscilloscope::TRIGGER_TYPE_DONTCARE);
			}

			//otherwise parse Verilog-format values
			else
			{
				//Default high bits to low
				for(int i=0; i<chan->GetWidth(); i++)
					triggerbits.push_back(Oscilloscope::TRIGGER_TYPE_LOW);

				const char* vstr = val.c_str();
				const char* quote = strstr(vstr, "'");
				char valbuf[64] = {0};

				int base = 10;

				//Ignore the length, just use the base
				if(quote != NULL)
				{
					//Parse it
					char cbase;
					sscanf(quote, "'%c%63s", &cbase, valbuf);
					vstr = valbuf;

					if(cbase == 'h')
						base = 16;
					else if(cbase == 'b')
						base = 2;
					//default to decimal
				}

				//Parse it
				switch(base)
				{
					//decimal
					case 10:
					{
						if(chan->GetWidth() > 32)
						{
							throw JtagExceptionWrapper(
								"Decimal values for channels >32 bits not supported",
								"");
						}

						unsigned int val = atoi(vstr);
						for(int i=0; i<chan->GetWidth(); i++)
						{
							triggerbits[chan->GetWidth() - 1 - i] =
								(val & 1) ? Oscilloscope::TRIGGER_TYPE_HIGH : Oscilloscope::TRIGGER_TYPE_LOW;
							val >>= 1;
						}
					}
					break;

					//hex
					case 16:
					{
						//Go right to left
						int w = chan->GetWidth();
						int nbit = w-1;
						for(int i=strlen(vstr)-1; i>=0; i--, nbit -= 4)
						{
							if(nbit <= 0)
								break;

							//Is it an X? Don't care
							if(tolower(vstr[i]) == 'x')
							{
								if(nbit > 2)
									triggerbits[nbit-3] = Oscilloscope::TRIGGER_TYPE_DONTCARE;
								if(nbit > 1)
									triggerbits[nbit-2] = Oscilloscope::TRIGGER_TYPE_DONTCARE;
								if(nbit > 0)
									triggerbits[nbit-1] = Oscilloscope::TRIGGER_TYPE_DONTCARE;
								triggerbits[nbit] = Oscilloscope::TRIGGER_TYPE_DONTCARE;
							}

							//No, hex - convert this character to binary
							else
							{
								int x;
								char cbuf[2] = {vstr[i], 0};
								sscanf(cbuf, "%1x", &x);
								if(nbit > 2)
									triggerbits[nbit - 3] = (x & 8) ? Oscilloscope::TRIGGER_TYPE_HIGH : Oscilloscope::TRIGGER_TYPE_LOW;
								if(nbit > 1)
									triggerbits[nbit - 2] = (x & 4) ? Oscilloscope::TRIGGER_TYPE_HIGH : Oscilloscope::TRIGGER_TYPE_LOW;
								if(nbit > 0)
									triggerbits[nbit - 1] = (x & 2) ? Oscilloscope::TRIGGER_TYPE_HIGH : Oscilloscope::TRIGGER_TYPE_LOW;
								triggerbits[nbit] = (x & 1) ? Oscilloscope::TRIGGER_TYPE_HIGH : Oscilloscope::TRIGGER_TYPE_LOW;
							}
						}
					}
					break;

					//binary
					case 2:
					{
						//Right to left, one bit at a time
						int w = chan->GetWidth();
						int nbit = w-1;
						for(int i=strlen(vstr)-1; i>=0; i--, nbit --)
						{
							if(nbit <= 0)
								break;

							if(tolower(vstr[i]) == 'x')
								triggerbits[nbit] = Oscilloscope::TRIGGER_TYPE_DONTCARE;
							else if(vstr[i] == '1')
								triggerbits[nbit] = Oscilloscope::TRIGGER_TYPE_HIGH;
							else
								triggerbits[nbit] = Oscilloscope::TRIGGER_TYPE_LOW;
						}
					}
					break;
				}
			}

			//Feed to the scope
			m_parent->GetScope()->SetTriggerForChannel(chan, triggerbits);
		}

		//Unknown channel type
		else
		{
			LogError("Unknown channel type - maybe analog? Not supported\n");
		}
	}
}
