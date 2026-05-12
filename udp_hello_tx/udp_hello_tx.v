`timescale 1ns / 1ps

module udp_hello_tx (
    input  wire clk_100mhz,
    input  wire rst_n,
    input  wire btn_send,

    output wire eth_tx_en,
    output wire [3:0] eth_txd,
    input  wire eth_tx_clk,
    output wire eth_ref_clk,
    output wire eth_rstn
);

    // --- ETHERNET PHY CONTROL ---
    reg [1:0] ref_clk_cnt = 0;
    always @(posedge clk_100mhz) ref_clk_cnt <= ref_clk_cnt + 1;
    assign eth_ref_clk = ref_clk_cnt[1];

    reg [19:0] phy_rst_cnt = 0;
    assign eth_rstn = (phy_rst_cnt > 20'h80000); 
    always @(posedge clk_100mhz) begin
        if (phy_rst_cnt < 20'hFFFFF) phy_rst_cnt <= phy_rst_cnt + 1;
    end

    // --- NETWORK PARAMETERS ---
    localparam [47:0] MAC_DEST = 48'hFF_FF_FF_FF_FF_FF;
    localparam [47:0] MAC_SRC  = 48'h00_18_3E_02_11_22;
    localparam [15:0] ETHER_TYPE = 16'h0800;

    localparam [31:0] IP_DEST = {8'd192, 8'd168, 8'd1, 8'd100};
    localparam [31:0] IP_SRC  = {8'd192, 8'd168, 8'd1, 8'd200};

    wire [159:0] IP_HEADER = {
        8'h45, 8'h00, 16'h0021, 16'h0000, 16'h0000,
        8'h40, 8'h11, 16'hF64F, IP_SRC, IP_DEST
    };

    localparam [15:0] UDP_SRC_PORT = 16'd1234;
    localparam [15:0] UDP_DST_PORT = 16'd5678;
    localparam [15:0] UDP_LENGTH   = 16'd13;

    wire [63:0] UDP_HEADER = {
        UDP_SRC_PORT, UDP_DST_PORT, UDP_LENGTH, 16'h0000
    };

    wire [39:0] PAYLOAD_DATA = {8'h48, 8'h45, 8'h4C, 8'h4C, 8'h4F};
    wire [263:0] FULL_PAYLOAD = {IP_HEADER, UDP_HEADER, PAYLOAD_DATA};

    // --- BUTTON DEBOUNCE ---
    reg [19:0] debounce_counter = 0;
    reg btn_clean = 0;
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            debounce_counter <= 0;
            btn_clean <= 0;
        end else begin
            if (btn_send == 1'b1) begin
                if (debounce_counter < 20'hFFFFF) debounce_counter <= debounce_counter + 1;
                else btn_clean <= 1'b1;
            end else begin
                debounce_counter <= 0;
                btn_clean <= 0;
            end
        end
    end

    // --- EDGE DETECTOR ---
    reg btn_sync_1, btn_sync_2;
    wire btn_send_pulse;
    always @(posedge eth_tx_clk or negedge rst_n) begin
        if (!rst_n) {btn_sync_1, btn_sync_2} <= 2'b00;
        else {btn_sync_1, btn_sync_2} <= {btn_clean, btn_sync_1};
    end
    assign btn_send_pulse = (btn_sync_1 && !btn_sync_2);

    // --- MII ADAPTATION ---
    reg [2:0]  state = 0;
    reg [10:0] byte_counter = 0;
    reg [7:0]  current_byte = 0;
    reg        tx_en_reg = 0;
    reg [3:0]  tx_data_nibble = 0;
    reg        nibble_sel = 0;
    reg        nibble_tick = 0;

    assign eth_txd = tx_data_nibble;
    assign eth_tx_en = tx_en_reg;

    always @(negedge eth_tx_clk or negedge rst_n) begin
        if (!rst_n) begin
            nibble_sel <= 0; tx_data_nibble <= 0; nibble_tick <= 0;
        end else if (tx_en_reg) begin
            if (nibble_sel == 0) begin
                tx_data_nibble <= current_byte[3:0];
                nibble_sel <= 1; nibble_tick <= 0;
            end else begin
                tx_data_nibble <= current_byte[7:4];
                nibble_sel <= 0; nibble_tick <= 1;
            end
        end else begin
            nibble_sel <= 0; tx_data_nibble <= 0; nibble_tick <= 0;
        end
    end

    // --- DYNAMIC CRC ---
    reg crc_en, crc_rst;
    wire [31:0] crc_out;
    crc32_nibble crc_inst (.clk(eth_tx_clk), .rst_n(rst_n & ~crc_rst), .en(crc_en), .d(eth_txd), .crc_out(crc_out));

    // --- MAIN FSM ---
    localparam [2:0] IDLE=0, TX_PREAMBLE=1, TX_SFD=2, TX_MAC=3, TX_IP_UDP_DATA=4, TX_PADDING=5, TX_FCS=6;

    always @(negedge eth_tx_clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; byte_counter <= 0; tx_en_reg <= 0; crc_en <= 0; crc_rst <= 1;
        end else begin
            case (state)
                IDLE: begin
                    tx_en_reg <= 0; crc_en <= 0; crc_rst <= 1;
                    if (btn_send_pulse) begin
                        state <= TX_PREAMBLE; byte_counter <= 0; current_byte <= 8'h55; tx_en_reg <= 1; crc_rst <= 0;
                    end
                end
                TX_PREAMBLE: begin
                    current_byte <= 8'h55;
                    if (nibble_tick) begin
                        if (byte_counter == 6) begin state <= TX_SFD; byte_counter <= 0; end
                        else byte_counter <= byte_counter + 1;
                    end
                end
                TX_SFD: begin
                    current_byte <= 8'hD5;
                    if (nibble_tick) begin state <= TX_MAC; byte_counter <= 0; crc_en <= 1; end
                end
                TX_MAC: begin
                    case (byte_counter)
                        0: current_byte <= MAC_DEST[47:40]; 1: current_byte <= MAC_DEST[39:32];
                        2: current_byte <= MAC_DEST[31:24]; 3: current_byte <= MAC_DEST[23:16];
                        4: current_byte <= MAC_DEST[15:8];  5: current_byte <= MAC_DEST[7:0];
                        6: current_byte <= MAC_SRC[47:40];  7: current_byte <= MAC_SRC[39:32];
                        8: current_byte <= MAC_SRC[31:24];  9: current_byte <= MAC_SRC[23:16];
                        10: current_byte <= MAC_SRC[15:8]; 11: current_byte <= MAC_SRC[7:0];
                        12: current_byte <= ETHER_TYPE[15:8]; 13: current_byte <= ETHER_TYPE[7:0];
                        default: current_byte <= 8'h00;
                    endcase
                    if (nibble_tick) begin
                        if (byte_counter == 13) begin state <= TX_IP_UDP_DATA; byte_counter <= 0; end
                        else byte_counter <= byte_counter + 1;
                    end
                end
                TX_IP_UDP_DATA: begin
                    current_byte <= FULL_PAYLOAD[ (32 - byte_counter)*8 +: 8 ];
                    if (nibble_tick) begin
                        if (byte_counter == 32) begin state <= TX_PADDING; byte_counter <= 0; end
                        else byte_counter <= byte_counter + 1;
                    end
                end
                TX_PADDING: begin
                    current_byte <= 8'h00;
                    if (nibble_tick) begin
                        if (byte_counter == 20) begin state <= TX_FCS; byte_counter <= 0; crc_en <= 0; end
                        else byte_counter <= byte_counter + 1;
                    end
                end
                TX_FCS: begin
                    // Sending CRC bytes in little-endian order (Standard Ethernet)
                    case (byte_counter)
                        0: current_byte <= crc_out[7:0];
                        1: current_byte <= crc_out[15:8];
                        2: current_byte <= crc_out[23:16];
                        3: current_byte <= crc_out[31:24];
                    endcase
                    if (nibble_tick) begin
                        if (byte_counter == 3) begin state <= IDLE; tx_en_reg <= 0; end
                        else byte_counter <= byte_counter + 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
