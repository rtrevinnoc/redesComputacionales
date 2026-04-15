`timescale 1ns / 1ps

module udp_hello_tx (
    input  wire clk_50mhz,  // Reloj principal de la placa
    input  wire rst_n,      // Reset activo en bajo
    input  wire btn_send,   // Boton fisico para enviar
    
    // Interfaz MII
    output wire eth_tx_en,  // Habilitador de transmision
    output wire [3:0] eth_txd, // Datos MII (Nibble)
    input  wire eth_tx_clk  // Reloj MII de 25 MHz del PHY
);

    // --- PARAMETROS MAC ---
    localparam [47:0] MAC_DEST = 48'hAA_BB_CC_DD_EE_FF; // MacBook (Cambiar por real)
    localparam [47:0] MAC_SRC  = 48'h00_18_3E_02_11_22; // Arty A7
    localparam [15:0] ETHER_TYPE = 16'h0800; // IPv4

    // --- REGISTROS DE ESTADO ---
    reg [2:0]  state;
    reg [10:0] byte_counter;
    reg [7:0]  current_byte;

    // --- REGISTROS MII ---
    reg [3:0] tx_data_nibble;
    reg       tx_en_reg;

    assign eth_txd = tx_data_nibble;
    assign eth_tx_en = tx_en_reg;

    // La logica de la maquina de estados se desarrollara en etapas posteriores.

endmodule
