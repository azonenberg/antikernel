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
	@brief NoC topology simulator
 */
#include "nocsim.h"

using namespace std;

unsigned int g_hostCount = 256;
unsigned int g_time = 0;

set<SimNode*> g_simNodes;

void CreateQuadtreeNetwork();
void CreateGridNetwork(bool randomize);
void RunSimulation();
void PrintStats();
void RenderOutput();

int main(int argc, char* argv[])
{
	Severity console_verbosity = Severity::NOTICE;

	enum Topologies
	{
		TOPO_QUADTREE,
		TOPO_XYGRID,
		TOPO_RANDOMGRID
	} topo = TOPO_QUADTREE;

	//Parse command-line arguments
	for(int i=1; i<argc; i++)
	{
		string s(argv[i]);

		//Let the logger eat its args first
		if(ParseLoggerArguments(i, argc, argv, console_verbosity))
			continue;

		if(s == "--topo")
		{
			string t = argv[++i];
			if(t == "quadtree")
				topo = TOPO_QUADTREE;
			else if(t == "xygrid")
				topo = TOPO_XYGRID;
			else if(t == "randomgrid")
				topo = TOPO_RANDOMGRID;
			else
			{
				printf("Invalid topology, (must be one of: quadtree)\n");
				return 0;
			}
		}
		else
		{
			printf("Unrecognized command-line argument \"%s\"\n", s.c_str());
			return 1;
		}
	}

	//Reset RNG
	srand(0);

	//Set up logging
	g_log_sinks.emplace(g_log_sinks.begin(), new ColoredSTDLogSink(console_verbosity));

	//Fun stuff here!
	switch(topo)
	{
		case TOPO_QUADTREE:
			CreateQuadtreeNetwork();
			break;

		case TOPO_XYGRID:
			CreateGridNetwork(false);
			break;

		case TOPO_RANDOMGRID:
			CreateGridNetwork(true);
			break;

		default:
			LogError("Invalid topology, can't run sim\n");
			return 0;
	}
	RunSimulation();
	PrintStats();
	RenderOutput();

	//Clean up
	for(auto p : g_simNodes)
		delete p;
	g_simNodes.clear();

	//All good
	return 0;
}

/**
	@brief Create a network using the grid topology, with either X-then-Y or pseudorandom routing
 */
void CreateGridNetwork(bool randomize)
{
	/*
		256 hosts in the network

		Have a 4x4 grid of routers with 16 addresses under each one

		Address mapping:
		a[15:8] = unused
		a[7:6] = Y
		a[5:4] = X
		a[3:0] = port
	 */
	unsigned int nodesize = 10;
	unsigned int nodepitch = 25;
	unsigned int routerpitch = 450;
	for(int y=0; y<4; y++)
	{
		for(int x=0; x<4; x++)
		{
			//Create the router
			uint16_t addr = (y << 6) | (x << 4);
			unsigned int xbase = x*routerpitch + nodesize + 7*nodepitch;
			unsigned int ypos = y*routerpitch + nodesize;
			auto router = new GridRouter(addr, addr+15, xypos(xbase, ypos) );
			g_simNodes.emplace(router);

			//move children down half a row
			ypos += routerpitch/2;

			//Create child nodes
			for(int i=0; i<16; i++)
			{
				uint16_t cbase = addr | i;

				unsigned int xpos = xbase + i*nodepitch - 7*nodepitch;

				//Create special hosts at a few addresses, then random stuff after that
				NOCHost* child = NULL;
				if(cbase == RAM_ADDR)
					child = new NOCRamHost(cbase, router, xypos(xpos, ypos) );
				else if(cbase == CPU_ADDR)
					child = new NOCCpuHost(cbase, router, xypos(xpos, ypos) );
				else if(cbase == NIC_ADDR)
					child = new NOCNicHost(cbase, router, xypos(xpos, ypos) );
				else
					child = new NOCHost(cbase, router, xypos(xpos, ypos) );

				//Done
				g_simNodes.emplace(child);
				//nhosts ++;
			}
		}
	}

	//TODO: connect the routers
}

/**
	@brief Create a network using the quadtree topology
 */
void CreateQuadtreeNetwork()
{
	set<QuadtreeRouter*> routers;
	set<QuadtreeRouter*> new_routers;

	//Column pitch of the nodes at the bottom level of the tree, also row pitch
	unsigned int pitch = 30;
	unsigned int nodesize = 10;

	//X center position of the leftmost host
	unsigned int left = nodesize/2;

	//X center position of the rightmost host
	unsigned int right = left + (g_hostCount - 1)*pitch;

	//Y center position of the topmost router
	unsigned int top = nodesize/2;

	//Seed things by creating a root router
	unsigned int size = g_hostCount;
	unsigned int mask = 0xffff & ~(size - 1);
	unsigned int base = 0;
	auto root = new QuadtreeRouter(NULL, base, base + size - 1, mask, xypos( (left + right)/2, top) );
	g_simNodes.emplace(root);
	routers.emplace(root);

	LogNotice("Creating network (quadtree topology) with %d hosts\n", root->GetSubnetSize());
	LogIndenter li;

	//Create each row of the tree
	bool done = false;
	int nrouters = 0;
	int nhosts = 0;
	while(!done)
	{
		//Start a new row
		new_routers.clear();
		top += pitch;

		//For each parent router in our list, add four child nodes
		for(auto r : routers)
		{
			//Figure out the new subnet size and mask
			size = r->GetSubnetSize() / 4;
			mask = 0xffff & ~(size - 1);
			base = r->GetSubnetBase();

			//Create the new routers
			for(int i=0; i<4; i++)
			{
				unsigned int cbase = base + i*size;
				unsigned int rowpitch = pitch * size;
				unsigned int xpos = r->m_renderPosition.first + (i-1)*rowpitch - rowpitch/2;

				//If child subnet size is 1, create hosts instead
				if(size == 1)
				{
					//Create special hosts at a few addresses, then random stuff after that
					NOCHost* child = NULL;
					if(cbase == RAM_ADDR)
						child = new NOCRamHost(cbase, r, xypos(xpos, top) );
					else if(cbase == CPU_ADDR)
						child = new NOCCpuHost(cbase, r, xypos(xpos, top) );
					else if(cbase == NIC_ADDR)
						child = new NOCNicHost(cbase, r, xypos(xpos, top) );
					else
						child = new NOCHost(cbase, r, xypos(xpos, top) );

					//Done
					g_simNodes.emplace(child);
					nhosts ++;
				}

				else
				{
					auto child = new QuadtreeRouter(r, cbase, cbase + size - 1, mask, xypos(xpos, top) );
					//LogDebug("Creating router at %u (size %u)\n", cbase, size);
					g_simNodes.emplace(child);
					new_routers.emplace(child);
					nrouters ++;
				}
			}

			//Finish after this iteration if we're creating hosts
			if(size == 1)
				done = true;
		}

		routers = new_routers;
	}

	LogVerbose("Created %d routers\n", nrouters);
	LogVerbose("Created %d hosts\n", nhosts);
}

/**
	@brief Run the discrete event simulation
 */
void RunSimulation()
{
	LogNotice("Running simulation...\n");
	for(g_time = 0; g_time < 1000; g_time ++)
	{
		for(auto n : g_simNodes)
			n->Timestep();
	}
}

void PrintStats()
{
	LogNotice("\n\nCollecting statistics...\n");
	LogIndenter li;
	for(auto n : g_simNodes)
		n->PrintStats();
	NOCPacket::PrintStats();
}

void RenderOutput()
{
	LogDebug("Writing simulation results to /tmp/simrun.svg...\n");
	LogIndenter li;

	unsigned int width = 0;
	unsigned int height = 0;

	//Find bounding box of all nodes
	for(auto n : g_simNodes)
		n->ExpandBoundingBox(width, height);

	//Generate the final drawing
	FILE* fp = fopen("/tmp/simrun.svg", "w");
	fprintf(fp,
		"<svg width=\"%u\" height=\"%u\" xmlns=\"http://www.w3.org/2000/svg\" "
		"xmlns:xlink=\"http://www.w3.org/1999/xlink\">\n",
		width, height);
	fprintf(fp, "<rect width=\"%u\" height=\"%u\" fill=\"white\"/>\n", width, height);

	//Draw the stuff. Interconnect goes first so nodes overlay the links
	for(auto n : g_simNodes)
		n->RenderSVGLines(fp);
	for(auto n : g_simNodes)
		n->RenderSVGNodes(fp);

	fprintf(fp, "</svg>\n");
	LogDebug("Done\n");
}
