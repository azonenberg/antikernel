#!/bin/sh

# clean out old data so we have a fresh start for testing
cd /nfs4/home/azonenberg/code/antikernel/trunk
rm -rf splashbuild/*
cd splashbuild
cp ../nodes.txt .

# initialize new build tree
/nfs4/home/azonenberg/code/splash-build-system/trunk/build/bin/splash -v -v -v -v -v init .. || exit 1

