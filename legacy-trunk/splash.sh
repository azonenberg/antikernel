#!/bin/sh

# Update Splash
cd /nfs4/home/azonenberg/code/splash-build-system/trunk/build
make || exit 1

# Run the build
cd /nfs4/home/azonenberg/code/antikernel/trunk
cd splashbuild
/nfs4/home/azonenberg/code/splash-build-system/trunk/build/bin/splash "$@"
