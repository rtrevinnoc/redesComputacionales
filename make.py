#!/usr/bin/env python3
# Copyright 2025 Silicon Compiler Authors. All Rights Reserved.

import sys
import os
from siliconcompiler import Design, FPGADevice
from siliconcompiler import FPGA
from siliconcompiler.flows.fpgaflow import FPGAXilinxFlow

class UDPDesign(Design):
    def __init__(self):
        super().__init__()
        # Set the design's name.
        self.set_name("udp_hello_tx")

        # Set the data root to the current directory
        # This ensures add_file can find files in subdirectories correctly
        self.set_dataroot("project_root", os.path.dirname(os.path.abspath(__file__)))

        # Configure filesets
        with self.active_dataroot("project_root"):
            # RTL sources
            with self.active_fileset("rtl"):
                self.set_topmodule("udp_hello_tx")
                # Using relative paths from the dataroot
                self.add_file("udp_hello_tx/udp_hello_tx.v")
                self.add_file("udp_hello_tx/crc32_nibble.v")

            # FPGA timing and pin constraints
            with self.active_fileset("fpga.XC7A100TCSG324-1"):
                self.add_file("udp_hello_tx/constraints.xdc")

def fpga(remote=False):
    """Runs the FPGA implementation flow for the UDP design."""
    # Create a project instance for an FPGA flow.
    project = FPGA()

    # Instantiate and configure the design.
    design = UDPDesign()
    project.set_design(design)

    # Add the RTL and FPGA constraint filesets.
    project.add_fileset("rtl")
    project.add_fileset("fpga.XC7A100TCSG324-1")
    
    # Specify the Xilinx implementation flow.
    project.set_flow(FPGAXilinxFlow())

    # Configure the specific FPGA part details (Arty A7-100T)
    fpga_dev = FPGADevice("XC7")
    fpga_dev.set_partname("xc7a100tcsg324-1")
    project.set_fpga(fpga_dev)

    # Set server-side tool path for Vivado for each task
    # This matches the schema: tool, <tool>, task, <task>, path
    vivado_path = '/opt/Xilinx/Vivado/2024.1/bin'
    for task in ['syn_fpga', 'place', 'route', 'bitstream']:
        project.set('tool', 'vivado', 'task', task, 'path', vivado_path)

    if remote:
        project.set('option', 'remote', True)

    # Run the FPGA flow (synthesis, place, route, bitstream generation).
    project.run()
    project.summary()

if __name__ == "__main__":
    use_remote = "--remote" in sys.argv
    fpga(remote=use_remote)
