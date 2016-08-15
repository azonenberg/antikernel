# Antikernel

This is the new development repository for the Antikernel OS. Not much is here for yet, we're still working on 
migrating files over from the old internal repo.

## Project Roadmap:

In no particular order...

Eventually some of these TODOs will be broken down into tickets on the issue tracker. Need to work out some finer 
details on design first.

* We're presenting the first peer-reviewed paper on the project at CHES 2016 in late August.
* The legacy Splash build system is being completely rewritten over the summer of 2016.
* We'd love to write some developer documentation and formally specify the APIs for various existing components, as 
well as writing specifications for not-yet-implemented peripherals/drivers/services
* The NoC cores need to be rewritten to have parameterizable bus width - 32 bits is great for size optimizing but can't 
keep up with higher speed memories and CPUs.
* Fix the SARATOGA L1 cache so the miss servicing latency isn't so bad.
* Reduce hazards between SARATOGA execution units so we can dual-issue a higher fraction of instructions.
* Experiment with porting Antikernel to a Xilinx Zynq SoC using both the Cortex-A9s and the FPGA.
* We should probably have a filesystem at some point.

## Stuff you might be interested in:

* Project IRC channel: #antikernel on Freenode
* Original PhD thesis: http://gradworks.umi.com/37/05/3705663.html
* CHES 2016 paper: https://eprint.iacr.org/2016/550
* CHES 2016 slides: _will be posted after the conference_
* The old SVN project on my private server: http://redmine.drawersteak.com/projects/achd-soc/
* The new build system repository: https://github.com/azonenberg/splash-build-system/
* The old build system repository: http://redmine.drawersteak.com/projects/splash-build-system/
