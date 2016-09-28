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

/**
	@brief Main application window class
 */
class MainWindow	: public Gtk::Window
{
public:
	MainWindow();
	~MainWindow();
	
	void AddPDU(std::string hostname, std::string read_community, std::string write_community);
	
protected:

	//Initialization
	void CreateWidgets();
		
	//Widgets
	Gtk::VBox m_vbox;
		Gtk::Frame m_indicatorframe;
			Gtk::Label m_indicatorframelabel;
			Gtk::HBox m_summarybox;
		Gtk::Notebook m_tabs;
			Gtk::VBox m_overviewtab;
				Gtk::Frame m_tempframe;
					Gtk::Label m_tempframelabel;
					Graph m_tempgraph;
				Gtk::Frame m_voltframe;
					Gtk::Label m_voltframelabel;
					Graph m_voltgraph;
				Gtk::Frame m_curframe;
					Gtk::Label m_curframelabel;
					Graph m_curgraph;
		
	//The actual control modules
	std::vector<PDUController*> m_controllers;
			
	//Status polling
	bool OnTimer(int timer);
};

#endif
