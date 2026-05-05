`timescale 1ns / 1ps

module udp_hello_tx #(
    parameter [47:0] MAC_DEST = 48'hAA_BB_CC_DD_EE_FF,
    parameter [47:0] MAC_SRC  = 48'h00_18_3E_02_11_22,
    parameter [15:0] ETHER_TYPE = 16'h0800,
    parameter [31:0] IP_DEST  = {8'd192, 8'd168, 8'd1, 8'd100},
    parameter [31:0] IP_SRC   = {8'd192, 8'd168, 8'd1, 8'd200},
    parameter [15:0] UDP_SRC_PORT = 16'd1234,
    parameter [15:0] UDP_DST_PORT = 16'd5678,
    parameter integer PAYLOAD_LEN = 5,
    parameter [PAYLOAD_LEN*8-1:0] PAYLOAD_STR = "HELLO"
) (
    input  wire clk_50mhz,
    input  wire rst_n,
    input  wire btn_send,
    
    output wire eth_tx_en,
    output wire [3:0] eth_txd,
    input  wire eth_tx_clk
);

    // Calculos de longitud
    localparam [15:0] IP_TOTAL_LEN  = 16'd28 + PAYLOAD_LEN;
    localparam [15:0] UDP_TOTAL_LEN = 16'd8 + PAYLOAD_LEN;
    
    // Calculo Dinamico del Checksum de IP
    wire [31:0] ip_checksum_sum = 
        16'h4500 + IP_TOTAL_LEN + 16'h0000 + 16'h0000 + 16'h4011 + 
        IP_SRC[31:16] + IP_SRC[15:0] + IP_DEST[31:16] + IP_DEST[15:0];
    
    wire [15:0] ip_checksum_final = ~(ip_checksum_sum[15:0] + ip_checksum_sum[31:16]);

    wire [159:0] IP_HEADER = {
        8'h45, 8'h00, IP_TOTAL_LEN, 16'h0000, 16'h0000, 
        8'h40, 8'h11, ip_checksum_final, IP_SRC, IP_DEST
    };

    wire [63:0] UDP_HEADER = {
        UDP_SRC_PORT, UDP_DST_PORT, UDP_TOTAL_LEN, 16'h0000
    };

    // Concatenacion del Payload completo (IP + UDP + DATOS)
    localparam integer FULL_PAYLOAD_LEN = 28 + PAYLOAD_LEN;
    wire [(FULL_PAYLOAD_LEN*8)-1:0] FULL_PAYLOAD = {IP_HEADER, UDP_HEADER, PAYLOAD_STR};

    // Calculo de Padding (Minimo Ethernet payload = 46 bytes)
    localparam integer PADDING_COUNT = (FULL_PAYLOAD_LEN < 46) ? (46 - FULL_PAYLOAD_LEN) : 0;

    // --- ESTADOS FSM ---
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] TX_PREAMBLE    = 3'd1;
    localparam [2:0] TX_SFD         = 3'd2;
    localparam [2:0] TX_MAC         = 3'd3;
    localparam [2:0] TX_IP_UDP_DATA = 3'd4;
    localparam [2:0] TX_PADDING     = 3'd5;
    localparam [2:0] TX_FCS         = 3'd6;

    reg [2:0]  state = IDLE;
    reg [10:0] byte_counter = 0;
    reg [7:0]  current_byte = 0;

    reg [3:0] tx_data_nibble = 0;
    reg       tx_en_reg = 0;
    assign eth_txd = tx_data_nibble;
    assign eth_tx_en = tx_en_reg;

    // Simulacion de senales que faltan por implementar (Parte 4)
    wire btn_send_sync = btn_send; // Placeholder
    wire nibble_tick = 1'b1;       // Placeholder

    // CRC32 Precalculado para paquete estatico
    wire [31:0] crc_value = 32'hD5213F93; 

    // --- FSM ---
    always @(posedge eth_tx_clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            byte_counter <= 0;
            tx_en_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_en_reg <= 0;
                    if (btn_send_sync) begin
                        state <= TX_PREAMBLE;
                        byte_counter <= 0;
                    end
                end
                
                TX_PREAMBLE: begin
                    tx_en_reg <= 1;
                    current_byte <= 8'h55;
                    if (nibble_tick) begin
                        if (byte_counter == 6) begin
                            state <= TX_SFD;
                            byte_counter <= 0;
                        end else begin
                            byte_counter <= byte_counter + 1;
                        end
                    end
                end
                
                TX_SFD: begin
                    current_byte <= 8'hD5;
                    if (nibble_tick) begin
                        state <= TX_MAC;
                        byte_counter <= 0;
                    end
                end
                
                TX_MAC: begin
                    case (byte_counter)
                        0: current_byte <= MAC_DEST[47:40];
                        1: current_byte <= MAC_DEST[39:32];
                        2: current_byte <= MAC_DEST[31:24];
                        3: current_byte <= MAC_DEST[23:16];
                        4: current_byte <= MAC_DEST[15:8];
                        5: current_byte <= MAC_DEST[7:0];
                        6: current_byte <= MAC_SRC[47:40];
                        7: current_byte <= MAC_SRC[39:32];
                        8: current_byte <= MAC_SRC[31:24];
                        9: current_byte <= MAC_SRC[23:16];
                        10: current_byte <= MAC_SRC[15:8];
                        11: current_byte <= MAC_SRC[7:0];
                        12: current_byte <= ETHER_TYPE[15:8];
                        13: current_byte <= ETHER_TYPE[7:0];
                    endcase
                    if (nibble_tick) begin
                        if (byte_counter == 13) begin
                            state <= TX_IP_UDP_DATA;
                            byte_counter <= 0;
                        end else begin
                            byte_counter <= byte_counter + 1;
                        end
                    end
                end
                
                TX_IP_UDP_DATA: begin
                    // Indexacion del Payload Completo
                    current_byte <= FULL_PAYLOAD[ (FULL_PAYLOAD_LEN - 1 - byte_counter)*8 +: 8 ];
                    
                    if (nibble_tick) begin
                        if (byte_counter == (FULL_PAYLOAD_LEN - 1)) begin
                            if (PADDING_COUNT > 0)
                                state <= TX_PADDING;
                            else
                                state <= TX_FCS;
                            byte_counter <= 0;
                        end else begin
                            byte_counter <= byte_counter + 1;
                        end
                    end
                end
                
                TX_PADDING: begin
                    current_byte <= 8'h00; // Ceros
                    if (nibble_tick) begin
                        if (byte_counter == (PADDING_COUNT - 1)) begin
                            state <= TX_FCS;
                            byte_counter <= 0;
                        end else begin
                            byte_counter <= byte_counter + 1;
                        end
                    end
                end
                
                TX_FCS: begin
                    case (byte_counter)
                        0: current_byte <= ~crc_value[31:24];
                        1: current_byte <= ~crc_value[23:16];
                        2: current_byte <= ~crc_value[15:8];
                        3: current_byte <= ~crc_value[7:0];
                    endcase
                    if (nibble_tick) begin
                        if (byte_counter == 3) begin
                            state <= IDLE;
                            tx_en_reg <= 0;
                        end else begin
                            byte_counter <= byte_counter + 1;
                        end
                    end
                end
            endcase
        end
    end

endmodule