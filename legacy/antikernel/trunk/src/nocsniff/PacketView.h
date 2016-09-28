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
	@brief Declaration of PacketView
 */

#ifndef NocsniffPacketView_h
#define NocsniffPacketView_h

#include "../jtaghal/NOCPacketSniffer.h"
#include "../../../splash-build-system/trunk/src/splash-antikernel/AntikernelModuleInfo.h"
#include <map>
#include <string>

class MainWindow;

class PacketColumns : public Gtk::TreeModel::ColumnRecord
{
public:
	Gtk::TreeModelColumn<int> index;
	Gtk::TreeModelColumn<int64_t> time_raw;
	Gtk::TreeModelColumn<Glib::ustring> time;
	Gtk::TreeModelColumn<Glib::ustring> src;
	Gtk::TreeModelColumn<Glib::ustring> dst;
	Gtk::TreeModelColumn<Glib::ustring> type;
	Gtk::TreeModelColumn<int> len;
	Gtk::TreeModelColumn<Glib::ustring> info;
	Gtk::TreeModelColumn<Glib::ustring> summary;
	Gtk::TreeModelColumn<Gdk::Color> color;
	
	PacketColumns()
	{
		add(index);
		add(time_raw);
		add(time);
		add(src);
		add(dst);
		add(type);
		add(len);
		add(info);
		add(summary);
		add(color);
	}
};

/**
	@brief Sidebar on the left side of the main window displaying the list of channels
 */
class PacketView : public Gtk::TreeView
{
public:
	PacketView(MainWindow* parent);
	~PacketView();

	void AddSamples(std::list<RPCSniffSample>& samples, NameServer& namesrvr);
	void AddSamples(std::list<DMASniffSample>& samples, NameServer& namesrvr);

protected:
	
	std::string FormatHostname(unsigned int host, NameServer& namesrvr, bool showboth=false);
	std::pair<std::string, std::string> DecodeRPCPacket(std::string nodetype, RPCMessage msg, NameServer& namesrvr);
	std::pair<std::string, std::string> DefaultDecodeRPCPacket(RPCMessage msg);

	MainWindow* m_parent;
	
	Glib::RefPtr<Gtk::TreeStore> m_model;
	PacketColumns m_columns;
	
	std::map<std::string, AntikernelModuleInfo*> m_modinfo;
	
	void OnEnabledToggled(const Glib::ustring& path);
	
	std::string DecodeVariable(AntikernelPacketVariableInfo& var, RPCMessage& msg, NameServer& namesrvr);
};

#endif

