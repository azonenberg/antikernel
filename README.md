# Antikernel

This is the new development repository for the Antikernel OS.

## Project Roadmap:

In no particular order...

Eventually some of these TODOs will be broken down into tickets on the issue tracker. Need to work out some finer 
details on design first.

* The legacy Splash build system is being completely rewritten and replaced.
* We'd love to write some developer documentation and formally specify the APIs for various existing components, as 
well as writing specifications for not-yet-implemented peripherals/drivers/services
* Fix the SARATOGA L1 cache so the miss servicing latency isn't so bad.
* Reduce hazards between SARATOGA execution units so we can dual-issue a higher fraction of instructions.
* Experiment with porting Antikernel to a Xilinx Zynq SoC using both the Cortex-A9s and the FPGA.
* We should probably have a filesystem at some point.

## Stuff you might be interested in:

* Project IRC channel: #antikernel on Freenode
* Original PhD thesis: http://gradworks.umi.com/37/05/3705663.html
* CHES 2016 paper: https://eprint.iacr.org/2016/550
* CHES 2016 slides: http://www.chesworkshop.org/ches2016/presentations/0918%20Session%205/CHES2016_Session5_2.pdf
* CHES 2016 video: https://www.iacr.org/cryptodb/data/paper.php?pubkey=27850
* TODO: S4x17 slides and video once posted
* Build system: https://github.com/azonenberg/splash-build-system/

## NOTES

The "legacy-*" directories contain a raw export of the old Subversion repository. This will all get moved elsewhere,
possibly to separate repositories, during the upcoming restructuring.
