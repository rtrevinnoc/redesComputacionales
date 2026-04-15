#include <iostream>
#include <iomanip>
#include "verilated.h"
#include "Vcircuit.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
#endif

int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);

    Vcircuit *dut = new Vcircuit;

#if VM_TRACE
    VerilatedVcdC* tfp = NULL;
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");
#endif

    int sim_time = 0;
    bool transmission_started = false;
    int tx_count = 0;

    // Initial state
    dut->clk = 0;
    dut->rst = 1;
    dut->send_btn = 0;
    dut->eval();

    std::cout << "Starting Ethernet MAC TX Simulation..." << std::endl;

    while (!Verilated::gotFinish() && sim_time < 10000) {
        
        // 1. Handle Reset (Active High)
        if (sim_time < 40) {
            dut->rst = 1;
        } else {
            dut->rst = 0;
        }

        // 2. Trigger Send Button after reset is released
        if (sim_time == 100) {
            dut->send_btn = 1;
            std::cout << "[SIM] Pressing Send Button..." << std::endl;
        } else if (sim_time == 200) {
            dut->send_btn = 0;
        }

        // 3. Toggle Clock (simulate 25MHz ETH clock period)
        if (sim_time % 5 == 0) {
            dut->clk ^= 1;
        }

        // 4. Evaluate the model
        dut->eval();

        // 5. Monitor Outputs on the Rising Edge
        if (sim_time % 10 == 0 && dut->clk == 1) {
            if (dut->eth_tx_en) {
                transmission_started = true;
                tx_count++;
                
                std::cout << "t=" << std::setw(5) << sim_time 
                          << " [TX] nibble: 0x" << std::hex << (int)dut->eth_txd 
                          << " | count: " << std::dec << tx_count;

                // Annotate the output for students
                if (tx_count <= 14) std::cout << " (Preamble)";
                else if (tx_count <= 16) std::cout << " (SFD)";
                else if (tx_count > 16 && tx_count <= 136) std::cout << " (Data)";
                else std::cout << " (CRC/FCS)";

                std::cout << std::endl;
            } else if (transmission_started) {
                std::cout << "[SIM] TX_EN dropped. Transmission Complete." << std::endl;
                break; 
            }
        }

#if VM_TRACE
        if (tfp) tfp->dump(sim_time);
#endif
        sim_time++;
    }

    dut->final();

#if VM_TRACE
    if (tfp) {
        tfp->close();
        delete tfp;
    }
#endif

    delete dut;
    return 0;
}