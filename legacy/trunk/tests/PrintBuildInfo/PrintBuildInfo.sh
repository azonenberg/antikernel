#!/bin/bash
########################################################################################################################
#                                                                                                                      #
# ANTIKERNEL v0.1                                                                                                      #
#                                                                                                                      #
# Copyright (c) 2012-2016 Andrew D. Zonenberg                                                                          #
# All rights reserved.                                                                                                 #
#                                                                                                                      #
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the     #
# following conditions are met:                                                                                        #
#                                                                                                                      #
#    * Redistributions of source code must retain the above copyright notice, this list of conditions, and the         #
#      following disclaimer.                                                                                           #
#                                                                                                                      #
#    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the       #
#      following disclaimer in the documentation and/or other materials provided with the distribution.                #
#                                                                                                                      #
#    * Neither the name of the author nor the names of any contributors may be used to endorse or promote products     #
#      derived from this software without specific prior written permission.                                           #
#                                                                                                                      #
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   #
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL #
# THE AUTHORS BE HELD LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES        #
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR       #
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT #
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE       #
# POSSIBILITY OF SUCH DAMAGE.                                                                                          #
#                                                                                                                      #
########################################################################################################################

cd ../../x86_64-linux-gnu;
echo "---------------------------------- jtagd ----------------------------------";
./jtagd --version || (echo "jtagd version failed"; exit -1;);
./jtagd --help || (echo "jtagd help failed"; exit -1;);
./jtagd --list || (echo "jtagd list failed"; exit -1;);
echo;
echo "---------------------------------- jtagclient ----------------------------------";
./jtagclient --version || (echo "jtagclient version failed"; exit -1;);
./jtagclient --help || (echo "jtagclient help failed"; exit -1;);
echo;
echo "---------------------------------- nocswitch ----------------------------------";
./nocswitch --version || (echo "nocswitch version failed"; exit -1;);
./nocswitch --help || (echo "nocswitch help failed"; exit -1;);
echo;
echo "---------------------------------- cosimbridge ----------------------------------";
./cosimbridge --version || (echo "cosimbridge version failed"; exit -1;);
./cosimbridge --help || (echo "cosimbridge help failed"; exit -1;);
echo;
echo "All good";
exit 0;
