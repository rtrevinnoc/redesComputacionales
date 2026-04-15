#!/usr/bin/env python3
# Copyright 2025 Silicon Compiler Authors. All Rights Reserved.

from siliconcompiler import Design, FPGADevice
from siliconcompiler import Lint, Sim
from siliconcompiler import ASIC, FPGA

from siliconcompiler.flows.dvflow import DVFlow
from siliconcompiler.flows.fpgaflow import FPGAXilinxFlow

from siliconcompiler.tools.verilator.compile import CompileTask


class CircuitDesign(Design):
    """Circuit design schema setup.

    This class defines the project structure for the 'circuit' design,
    configuring source files, parameters, and constraints for various

    tool flows and technology targets. By encapsulating the design setup,
    it allows for easy reuse across different flows (lint, sim, asic, fpga).
    """
    def __init__(self):
        """Initializes the HeartbeatDesign object.

        This method sets up all the necessary filesets for RTL,
        simulation testbenches (Icarus and Verilator), and technology-specific
        constraint files (SDC for ASIC, XDC for FPGA).
        """
        super().__init__()
        # Set the design's name.
        self.set_name("circuit")

        # Establish the root directory for all design-related files.
        self.set_dataroot("circuit", __file__)

        # Configure filesets within the established data root.
        with self.active_dataroot("circuit"):
            # RTL sources
            with self.active_fileset("rtl"):
                self.set_topmodule("circuit")
                self.add_file("circuit.v")

            # C++ Testbench for Verilator
            with self.active_fileset("testbench.verilator"):
                self.set_topmodule("circuit")
                self.add_file("testbench.cpp")

            # FPGA timing and pin constraints for a Xilinx Artix-7 device.
            with self.active_fileset("fpga.XC7A100TCSG324-1"):
                self.add_file("constraints.xdc")


def sim(tool: str = "verilator"):
    """Runs a simulation of the Circuit design.

    After the simulation completes, it attempts to open the generated
    waveform file (VCD) for viewing.

    Args:
        tool (str, optional): The simulation tool to use ('verilator' or
            'icarus'). Defaults to "verilator".
    """
    # Create a project instance tailored for simulation.
    project = Sim()

    # Instantiate and configure the design.
    hb = CircuitDesign()
    project.set_design(hb)

    # Add the tool-specific testbench and the RTL design files.
    project.add_fileset(f"testbench.{tool}")
    project.add_fileset("rtl")
    # Set the appropriate design verification flow.
    project.set_flow(DVFlow(tool=tool))
    # project.set('option', 'remote', True)
    project.set('tool', 'verilator', 'task', 'compile', 'var', 'trace', True)
    project.set('tool', 'verilator', 'task', 'compile', 'var', 'trace_type', 'vcd')

    if tool == "verilator":
        # Add trace to verilator
        CompileTask.find_task(project).set_verilator_trace(True)

    # Run the simulation.
    project.run()
    project.summary()

    vcd = None
    if tool == "icarus":
        # Find the VCD (Value Change Dump) waveform file from the results.
        vcd = project.find_result(step='simulate', index='0',
                                  directory="inputs",
                                  filename="waveform.vcd")
    else:
        # Find the VCD (Value Change Dump) waveform file from the results.
        vcd = project.find_result(step='simulate', index='0',
                                  directory="inputs",
                                  filename="waveform.vcd")
    # If a VCD file is found, open it with the default waveform viewer.
    if vcd:
        project.show(vcd)


def fpga():
    """Runs the FPGA implementation flow for the Circuit design.

    This flow targets a Xilinx Artix-7 FPGA (xc7a100tcsg324) and generates
    a bitstream that can be programmed onto the device.
    """
    # Create a project instance for an FPGA flow.
    project = FPGA()

    # Instantiate and configure the design.
    hb = CircuitDesign()
    project.set_design(hb)

    # Add the RTL and FPGA constraint filesets.
    project.add_fileset("rtl")
    project.add_fileset("fpga.XC7A100TCSG324-1")
    # Specify the Xilinx implementation flow.
    project.set_flow(FPGAXilinxFlow())

    # Configure the specific FPGA part details.
    fpga = FPGADevice("XC7")
    fpga.set_partname("XC7A100TCSG324-1")
    project.set_fpga(fpga)

    # Run the FPGA flow (synthesis, place, route, bitstream generation).
    project.run()
    project.summary()


if __name__ == "__main__":
    # When the script is executed directly from the command line,
    # run the synthesis flow by default.
    sim()