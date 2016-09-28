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
	@brief C++ wrapper for SLURM jobs
 */
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <vector>
#include <map>
#include <fcntl.h>
#include <stdio.h>
#include <stdarg.h>
#include <string>
#include <string.h>
#include <time.h>

using namespace std;

void PrintHeading(const char* format, ...);
void FatalError(const char* format, ...);
string ShellCommand(string cmd, bool trimNewline = true);
string GetDirOfFile(string fname);
string CanonicalizePath(string fname);

pid_t StartProcess(string outbase, unsigned int jobid, const char** args);
int WaitForProcess(pid_t pid, unsigned int timeout);
void PrintOutput(string outbase, unsigned int jobid);

vector<pid_t> g_children;

unsigned int g_maxwidth		= 120;

int main(int argc, char* argv[])
{	
	//Get some SLURM job info
	unsigned int num_nodes		= atoi(getenv("SLURM_NNODES"));
	unsigned int job_id			= atoi(getenv("SLURM_JOB_ID"));
	string nodename				= getenv("SLURM_NODELIST");
	
	//TODO: Use SSH to launch the LA etc on the node the job was submitted from
	//This will support having the actual SLURM daemons living on ariia / another cluster front-end node
	//rather than on mars
	//SLURM_LAUNCH_NODE_IPADDR is that IP, default to display :0
	
	//Sanity check that we're only running on one node
	if(num_nodes != 1)
		FatalError("slurmwrapper only supports single-node jobs for now\n");
		
	//Print header
	PrintHeading("SLURM job %u starting up on node %s\n", job_id, nodename.c_str());
	
	//Get current working directory and print for debugging
	char pwd[1024];
	if(NULL == getcwd(pwd, sizeof(pwd)))
		FatalError("working directory is invalid or too long\n");
	printf("Job working directory is %s\n", pwd);
	
	//Get the architecture triplet so we know where to find stuff
	string arch_triplet = ShellCommand("dpkg-architecture -qDEB_HOST_MULTIARCH");
	printf("Host architecture is %s\n", arch_triplet.c_str());
	
	//Parse arguments
	string bitstream;
	string buildroot;
	unsigned int maxtime 		= 90;
	unsigned int maxprogtime	= 90;
	bool nocswitch				= false;
	bool cosimbridge			= false;
	vector<string> scopenames;
	vector<string> sniffnames;
	string testcase;
	string nocgenfile;
	for(int i=1; i<argc; i++)
	{
		string arg = argv[i];
		if(arg == "--bitstream")
			bitstream = argv[++i];
		else if(arg == "--buildroot")
			buildroot = argv[++i];
		else if(arg == "--maxtime")
			maxtime = atoi(argv[++i]);
		else if(arg == "--maxprog")
			maxprogtime = atoi(argv[++i]);
		else if(arg == "--nocswitch")
			nocswitch = true;
		else if(arg == "--cosimbridge")
			cosimbridge = true;
		else if(arg == "--la")
			scopenames.push_back(argv[++i]);
		else if(arg == "--sniffer")
			sniffnames.push_back(argv[++i]);
		else if(arg == "--testcase")
			testcase = argv[++i];
		else if(arg == "--nocgen")
			nocgenfile = argv[++i];
		else
			FatalError("Unrecognized argument \"%s\" to SlurmJobWrapper\n", arg.c_str());
	}
		
	//Sanity check: buildroot is a must
	if(buildroot == "")
		FatalError("buildroot is a mandatory argument\n");
	
	//Sanity check: testcase is a must
	if(testcase == "")
		FatalError("testcase is a mandatory argument\n");
	
	//This is where we expect to find binaries like nocswitch
	string binpath = buildroot + "/" + arch_triplet;
	
	//Read config file
	//Leave ports as strings since we pass them to jtagclient etc as strings
	string cfgpath = buildroot + "/nodes.txt";
	char node[256];
	char host[256];
	char jtagdport[32];
	char uartport[32];
	FILE* fp = fopen(cfgpath.c_str(), "r");
	if(!fp)
		FatalError("node config file doesn't exist\n");
	bool hit = false;
	while(!feof(fp))
	{
		if(4 != fscanf(fp, "%255s %255s %31s %31s", node, host, jtagdport, uartport))
			continue;
		if(nodename == node)
		{
			hit = true;
			break;
		}
	}
	fclose(fp);
	if(!hit)
		FatalError("Node %s is not in the config file\n", nodename.c_str());
		
	//Delete the port file if it already exists
	unlink("nocswitch-port.txt");
	
	//Load the bitstream if requested
	string jtagclient_fname = binpath + "/jtagclient";
	if(bitstream != "")
	{
		printf("Loading bitstream \"%s\" onto target device...\n", bitstream.c_str());
		
		//Run jtagclient
		const char* jtagclient_args[]=
		{
			jtagclient_fname.c_str(),
			"--server", host,
			"--port",	jtagdport,
			"--program", "0", bitstream.c_str(),
			NULL
		};
		pid_t pid = StartProcess("program", job_id, jtagclient_args);
		
		//Wait for the programming to finish
		if(0 != WaitForProcess(pid, maxprogtime))
		{
			PrintOutput("program", job_id);
			FatalError("jtagclient failed, aborting\n");
		}
	}
	
	//Bitstream was loaded if necessary
	//See if we need to start nocswitch
	pid_t nocswitch_pid = -1;
	char nocswitch_port[128];
	if(nocswitch)
	{
		printf("Starting nocswitch...\n");
		
		//Run nocswitch
		string nocswitch_fname = binpath + "/nocswitch";
		const char* nocswitch_args[]=
		{
			nocswitch_fname.c_str(),
			"--server", host,
			"--port",	jtagdport,
			NULL
		};
		nocswitch_pid = StartProcess("nocswitch", job_id, nocswitch_args);
		
		//Wait for it to write the portfile, then get the port number
		for(int i=0; i<50; i++)
		{
			FILE* fp = fopen("nocswitch-port.txt", "r");
			if(!fp)
			{
				if(i == 49)
				{
					PrintOutput("nocswitch", job_id);
					FatalError("nocswitch port file was not written");
				}
					
				usleep(100 * 1000);
				continue;
			}
			fscanf(fp, "%127s", nocswitch_port);
			fclose(fp);
		}
		
		printf("nocswitch is now running on port %s\n", nocswitch_port);
	}
	
	//Get the test directory
	string testdir = GetDirOfFile(CanonicalizePath(testcase));
	
	//Start cosimbridge if requested
	char readpipe_fname[256] = "";
	char writepipe_fname[256] = "";
	pid_t cosimbridge_pid = -1;
	if(cosimbridge)
	{
		if(!nocswitch)
			FatalError("cosimbridge cannot be used without nocswitch\n");

		//Make the pipes
		printf("Making cosimulation pipes\n");
		snprintf(readpipe_fname, sizeof(readpipe_fname), "%s/readpipe", testdir.c_str());
		snprintf(writepipe_fname, sizeof(writepipe_fname), "%s/writepipe", testdir.c_str());
		unlink(readpipe_fname);
		unlink(writepipe_fname);
		if(0 != mkfifo(readpipe_fname, 0600))
			FatalError("read pipe creation failed\n");
		if(0 != mkfifo(writepipe_fname, 0600))
			FatalError("write pipe creation failed\n");
			
		//Spawn the cosimbridge
		//Need to do this from within the test directory since ISim executables are derpy
		//and must run from the directory they were compiled in
		string cosimbridge_fname = binpath + "/cosimbridge";
		const char* cosimbridge_args[]=
		{
			cosimbridge_fname.c_str(),
			"--server", "localhost",
			"--port",	nocswitch_port,
			NULL
		};
		chdir(testdir.c_str());
		cosimbridge_pid = StartProcess("cosimbridge", job_id, cosimbridge_args);
		chdir(pwd);
	}
	
	//Pick the appropriate server for the test case to connect to
	string testcase_host = host;
	string testcase_port = jtagdport;
	if(nocswitch)
	{
		testcase_host = "localhost";
		testcase_port = nocswitch_port;
	}
	
	//If we're running a packet sniffer, spawn it now
	map<string, FILE*> sniff_pipes;
	map<string, string> sniff_outputs;
	for(auto sniffname : sniffnames)
	{
		//Format the command
		char tmp[1024];
		snprintf(tmp, sizeof(tmp), "%s/nocsniff --server %s --port %s --scripted --sniffname %s --nocgen %s",
			binpath.c_str(),
			"localhost",		//TODO: Support running sniffer over X forward
			nocswitch_port,
			sniffname.c_str(),
			nocgenfile.c_str());
			
		//Open the pipe
		FILE* fp = NULL;
		if(NULL == (fp = popen(tmp, "r")))
			FatalError("Failed to spawn packet sniffer");
		sniff_pipes[sniffname] = fp;
	}
	
	//If we're running a logic analyzer, spawn it now
	map<string, FILE*> la_pipes;
	map<string, string> la_outputs;
	bool skip_test = false;
	for(auto scopename : scopenames)
	{
		//Format the command
		char tmp[1024];
		snprintf(tmp, sizeof(tmp), "%s/scopeclient --server %s --port %s --scripted --scopename %s",
			binpath.c_str(),
			"localhost",		//TODO: Support running LA over X forward
			nocswitch_port,
			scopename.c_str());
			
		//Open the pipe
		FILE* fp = NULL;
		if(NULL == (fp = popen(tmp, "r")))
			FatalError("Failed to spawn logic analyzer");
		la_pipes[scopename] = fp;
	}
	for(auto x : la_pipes)
	{
		string scopename = x.first;
		FILE* fp = x.second;
		
		//Wait for the scope to be ready (trigger conditions entered, etc)
		char tmp[1024];
		while(true)
		{
			if(NULL == fgets(tmp, sizeof(tmp), fp))
			{
				printf("LA was closed before trigger conditions were input, aborting\n");
				skip_test = true;
				break;
			}
			la_outputs[scopename] += tmp;
			if(NULL != strstr(tmp, "Ready\n"))
				break;
		}
		
		if(skip_test)
			break;
	}
	
	bool fail = false;
	if(!skip_test)
	{
		//Launch the test case
		printf("Starting test case...\n");
		char testcase_outfile[1024];
		snprintf(testcase_outfile, sizeof(testcase_outfile), "/tmp/slurm_%u_output.txt", job_id);
		char tty[1024];
		snprintf(tty, sizeof(tty), "%s:%s", host, uartport);

		//Run the test case
		//cosim test cases are shell scripts and need special treatment
		pid_t tcpid = -1;
		if(cosimbridge)
		{
			const char* testcase_args[]=
			{
				"/bin/bash",
				"-c",
				testcase.c_str(),
				NULL
			};
			tcpid = StartProcess("testcase", job_id, testcase_args);
		}
		else
		{
			const char* testcase_args[]=
			{
				testcase.c_str(),
					"--server", testcase_host.c_str(),
					"--port",	testcase_port.c_str(),
					"--tty", tty,
				NULL
			};
			tcpid = StartProcess("testcase", job_id, testcase_args);
		}
			
		//Wait for the test case to finish
		if(0 != WaitForProcess(tcpid, maxtime))
		{
			printf("Test case failed\n");
			fail = true;
		}
		else
			printf("Normal termination of test case\n");
	}
		
	//Wait for the logic analyzer (if any) to close
	for(auto x : la_pipes)
	{
		string scopename = x.first;
		FILE* fp = x.second;
		
		char tmp[1024];
		while(true)
		{
			if(NULL == fgets(tmp, sizeof(tmp), fp))
				break;
			la_outputs[scopename] += tmp;
		}
		pclose(fp);
		printf("LA \"%s\" closed\n", scopename.c_str());
	}
	
	//Wait for the packet sniffer (if any) to close
	for(auto x : sniff_pipes)
	{
		string scopename = x.first;
		FILE* fp = x.second;
		
		char tmp[1024];
		while(true)
		{
			if(NULL == fgets(tmp, sizeof(tmp), fp))
				break;
			sniff_outputs[scopename] += tmp;
		}
		pclose(fp);
		printf("Packet sniffer \"%s\" closed\n", scopename.c_str());
	}	
	
	//Need to kill these or fpga blanking will block
	if(cosimbridge && (cosimbridge_pid > 0))
		kill(cosimbridge_pid, SIGINT);
	if(nocswitch && (nocswitch_pid > 0))
		kill(nocswitch_pid, SIGINT);
	
	//Blank the FPGA
	printf("Blanking FPGA for next test...\n");
		const char* jtagclient_wipe_args[]=
	{
		jtagclient_fname.c_str(),
		"--server", host,
		"--port",	jtagdport,
		"--erase", "0",
		NULL
	};
	pid_t wpid = StartProcess("reset", job_id, jtagclient_wipe_args);
	WaitForProcess(wpid, 10);
	
	//Print the stdout of helper programs in order that they were started
	if(bitstream != "")
		PrintOutput("program", job_id);
	if(nocswitch)
		PrintOutput("nocswitch", job_id);
	if(cosimbridge)
	{
		unlink(readpipe_fname);
		unlink(writepipe_fname);
		PrintOutput("cosimbridge", job_id);
	}
	for(auto x : la_outputs)
	{
		string scopename = x.first;
		string output = x.second;
		
		printf("\n");
		PrintHeading("LA \"%s\" output\n", scopename.c_str());
		printf("%s", output.c_str());
	}
	for(auto x : sniff_outputs)
	{
		string scopename = x.first;
		string output = x.second;
		
		printf("\n");
		PrintHeading("Packet sniffer \"%s\" output\n", scopename.c_str());
		printf("%s", output.c_str());
	}
	PrintOutput("reset", job_id);
	
	//Print test case last for easier reading
	PrintOutput("testcase", job_id);
	
	if(fail)
		return -1;
	else
		return 0;
}

void PrintHeading(const char* format, ...)
{
	for(unsigned int i=0; i<g_maxwidth; i++)
		printf("-");
	printf("\n");
	
	va_list args;
	va_start(args, format);
	vprintf(format, args);
	va_end(args);
	
	for(unsigned int i=0; i<g_maxwidth; i++)
		printf("-");
	printf("\n");
	printf("\n");
}

void FatalError(const char* format, ...)
{
	//Kill all children unconditionally to prevent hangs
	for(auto child : g_children)
		kill(child, SIGKILL);
	
	fflush(stdout);
	fflush(stderr);
	
	fprintf(stderr, "\033[0mERROR: ");
	
	va_list args;
	va_start(args, format);
	vfprintf(stderr, format, args);
	va_end(args);
		
	exit(1);
}

string ShellCommand(string cmd, bool trimNewline)
{
	FILE* fp = popen(cmd.c_str(), "r");
	if(fp == NULL)
		FatalError("popen(%s) failed\n", cmd.c_str());
	string retval;
	char line[1024];
	while(NULL != fgets(line, sizeof(line), fp))
		retval += line;
	pclose(fp);
	
	if(trimNewline)
		retval.erase(retval.find_last_not_of(" \n\r\t")+1);
	return retval;
}

string GetDirOfFile(string fname)
{
	size_t pos = fname.rfind("/");
	return fname.substr(0, pos);
}

pid_t StartProcess(string outbase, unsigned int jobid, const char** args)
{
	char fname[1024];
	snprintf(fname, sizeof(fname), "/tmp/slurm_%u_%s.txt", jobid, outbase.c_str());
	
	pid_t rpid = fork();
	if(rpid == 0)
	{
		int hfile = open(fname, O_WRONLY|O_CREAT, 0600);
		if(hfile < 0)
			FatalError("couldn't open output file");
		if(!dup2(hfile, STDOUT_FILENO))
			FatalError("stdout redir failed");
		if(!dup2(hfile, STDERR_FILENO))
			FatalError("stderr redir failed");		
	
		//casting away const-ness is fine in child process
		//since we never try to use them again
		execv(args[0], (char* const*)args);
		
		FatalError("exec failed");
	}
	else if(rpid < 0)
		FatalError("fork failed");
	
	//Add to list of children
	g_children.push_back(rpid);
	
	return rpid;
}

int WaitForProcess(pid_t pid, unsigned int timeout)
{
	//Wait for the operation to finish
	time_t end = time(NULL) + timeout;
	while(true)
	{
		if(time(NULL) > end)
		{
			kill(pid, SIGKILL);
			printf("Timeout waiting for pid %u\n", pid);
			return -1;
		}
			
		//See if it's done
		int status;
		pid_t tpid = waitpid(pid, &status, WNOHANG);
		if(tpid < 0)
			FatalError("waitpid failed\n");
			
		//Done programming
		else if(tpid == pid)
			return status;
		
		//still running, wait 10ms and poll again
		else
			usleep(1000 * 10);
	}
}

void PrintOutput(string outbase, unsigned int jobid)
{
	printf("\n");
	PrintHeading("%s output\n", outbase.c_str());
	
	char fname[1024];
	snprintf(fname, sizeof(fname), "/tmp/slurm_%u_%s.txt", jobid, outbase.c_str());
	
	FILE* fp = fopen(fname, "r");
	if(!fp)
		FatalError("couldn't open output file %s\n", fname);
		
	char buf[1024];
	while(fgets(buf, sizeof(buf), fp))
		printf("%s", buf);
		
	fclose(fp);
	
	unlink(fname);
}

string CanonicalizePath(string fname)
{
	char* cpath = realpath(fname.c_str(), NULL);
	if(cpath == NULL)
	{
		FatalError("Could not canonicalize path %s\n", fname.c_str());
		return fname;
	}
	string str(cpath);
	free(cpath);
	return str;
}
