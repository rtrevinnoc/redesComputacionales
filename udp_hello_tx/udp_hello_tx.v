`timescale 1ns / 1ps

module udp_hello_tx (
    input  wire clk_100mhz,
    input  wire rst_n,
    input  wire btn_send,

    output wire eth_tx_en,
    output wire [3:0] eth_txd,
    input  wire eth_tx_clk,
    output wire eth_ref_clk,
    output wire eth_rstn,
    output wire [3:0] led
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

    assign led = {tx_en_reg, state[2:0]};

    // --- NETWORK PARAMETERS ---
    localparam [47:0] MAC_DEST = 48'hFF_FF_FF_FF_FF_FF;
    localparam [47:0] MAC_SRC  = 48'h00_18_3E_02_11_22;
    localparam [15:0] ETHER_TYPE = 16'h0800;

    localparam [31:0] IP_DEST = {8'd192, 8'd168, 8'd1, 100};
    localparam [31:0] IP_SRC  = {8'd192, 8'd168, 8'd1, 200};

    wire [159:0] IP_HEADER = {
        8'h45, 8'h00, 16'h0021, 16'h0000, 16'h0000,
        8'h40, 8'h11, 16'hF64F, IP_SRC, IP_DEST
    };

    wire [63:0] UDP_HEADER = { 16'd1234, 16'd5678, 16'd13, 16'h0000 };
    wire [39:0] PAYLOAD_DATA = 40'h48454C4C4F; // "HELLO"
    wire [263:0] FULL_PAYLOAD = {IP_HEADER, UDP_HEADER, PAYLOAD_DATA};

    // --- BUTTON DEBOUNCE ---
    reg [19:0] debounce_counter = 0;
    reg btn_clean = 0;
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin debounce_counter <= 0; btn_clean <= 0; end
        else begin
            if (btn_send) begin
                if (debounce_counter < 20'hFFFFF) debounce_counter <= debounce_counter + 1;
                else btn_clean <= 1'b1;
            end else begin debounce_counter <= 0; btn_clean <= 0; end
        end
    end

    reg btn_sync_1, btn_sync_2;
    wire btn_send_pulse;
    always @(posedge eth_tx_clk or negedge rst_n) begin
        if (!rst_n) {btn_sync_1, btn_sync_2} <= 2'b00;
        else {btn_sync_1, btn_sync_2} <= {btn_clean, btn_sync_1};
    end
    assign btn_send_pulse = (btn_sync_1 && !btn_sync_2);

    // --- MAIN FSM (Falling Edge) ---
    reg [2:0]  state = 0;
    reg [10:0] byte_counter = 0;
    reg [7:0]  current_byte = 0;
    reg        tx_en_reg = 0;
    reg        nibble_sel = 0;
    
    localparam IDLE=0, PREAMBLE=1, SFD=2, DATA=3, FCS=4;

    // CRC instance
    reg crc_en, crc_rst;
    wire [31:0] crc_out;
    crc32_nibble crc_inst (.clk(eth_tx_clk), .rst_n(rst_n & ~crc_rst), .en(crc_en), .d(eth_txd), .crc_out(crc_out));

    assign eth_txd = (nibble_sel == 1) ? current_byte[3:0] : current_byte[7:4];
    assign eth_tx_en = tx_en_reg;

    always @(negedge eth_tx_clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; tx_en_reg <= 0; nibble_sel <= 0; byte_counter <= 0; crc_en <= 0; crc_rst <= 1;
        end else begin
            case (state)
                IDLE: begin
                    tx_en_reg <= 0; nibble_sel <= 0; crc_rst <= 1;
                    if (btn_send_pulse) begin
                        state <= PREAMBLE; byte_counter <= 0; current_byte <= 8'h55; tx_en_reg <= 1;
                    end
                end

                PREAMBLE: begin
                    current_byte <= 8'h55;
                    if (nibble_sel) begin
                        if (byte_counter == 31) begin state <= SFD; byte_counter <= 0; end
                        else byte_counter <= byte_counter + 1;
                    end
                    nibble_sel <= ~nibble_sel;
                end

                SFD: begin
                    current_byte <= 8'hD5;
                    if (nibble_sel) begin state <= DATA; byte_counter <= 0; crc_rst <= 0; end
                    nibble_sel <= ~nibble_sel;
                end

                DATA: begin
                    if (!crc_en) crc_en <= 1;
                    // MAC_DEST(6) + MAC_SRC(6) + TYPE(2) + PAYLOAD(33) + PADDING(13) = 60 bytes
                    if (byte_counter < 6)  current_byte <= MAC_DEST[ (5-byte_counter)*8 +: 8 ];
                    else if (byte_counter < 12) current_byte <= MAC_SRC[ (11-byte_counter)*8 +: 8 ];
                    else if (byte_counter < 14) current_byte <= ETHER_TYPE[ (13-byte_counter)*8 +: 8 ];
                    else if (byte_counter < 47) current_byte <= FULL_PAYLOAD[ (32-(byte_counter-14))*8 +: 8 ];
                    else current_byte <= 8'h00; // Padding

                    if (nibble_sel) begin
                        if (byte_counter == 59) begin state <= FCS; byte_counter <= 0; end
                        else byte_counter <= byte_counter + 1;
                    end
                    nibble_sel <= ~nibble_sel;
                end

                FCS: begin
                    if (crc_en) crc_en <= 0;
                    case (byte_counter)
                        0: current_byte <= crc_out[7:0];
                        1: current_byte <= crc_out[15:8];
                        2: current_byte <= crc_out[23:16];
                        3: current_byte <= crc_out[31:24];
                    endcase
                    if (nibble_sel) begin
                        if (byte_counter == 3) begin state <= IDLE; tx_en_reg <= 0; end
                        else byte_counter <= byte_counter + 1;
                    end
                    nibble_sel <= ~nibble_sel;
                end
            endcase
        end
    end
endmodule
