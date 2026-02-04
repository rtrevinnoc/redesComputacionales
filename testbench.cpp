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

    // Initial state
    dut->clk = 0;
    dut->rst = 1;
    dut->send_btn = 0;
    dut->eval();

    // Run simulation
    // We run until we see the transmission finish (TX_EN goes low after being high)
    while (!Verilated::gotFinish() && sim_time < 5000) {
        
        // 1. Handle Reset
        if (sim_time < 20) {
            dut->rst = 1;
        } else {
            dut->rst = 0;
        }

        // 2. Trigger Send Button after reset
        if (sim_time == 50) {
            dut->send_btn = 1;
        } else if (sim_time == 100) {
            dut->send_btn = 0;
        }

        // 3. Toggle Clock (simulate 25MHz ETH clock)
        if (sim_time % 5 == 0) {
            dut->clk ^= 1;
        }

        // 4. Evaluate the model
        dut->eval();

        // 5. Monitor and Print Outputs
        // Only print on rising edge to see stable data
        if (sim_time % 10 == 0 && sim_time > 40) {
            if (dut->eth_tx_en) {
                transmission_started = true;
                std::cout << "t=" << std::setw(4) << sim_time 
                          << " [TXING] nibble=0x" << std::hex << (int)dut->eth_txd 
                          << " en=" << (int)dut->eth_tx_en << std::dec << std::endl;
            } else if (transmission_started) {
                std::cout << "t=" << sim_time << " Transmission Complete." << std::endl;
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