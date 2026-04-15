module circuit(
    input  wire       clk,        // 25MHz Ethernet TX Clock from PHY
    input  wire       rst,        // System Reset
    input  wire       send_btn,   // Button to trigger transmission
    output reg  [3:0] eth_txd,    // MII Data Nibbles
    output reg        eth_tx_en   // TX Enable
);

    // State Machine
    localparam IDLE     = 0,
               PREAMBLE = 1,
               SFD      = 2,
               PAYLOAD  = 3,
               CRC_OUT  = 4;

    reg [2:0]  state = IDLE;
    reg [4:0]  count = 0;
    reg [6:0]  byte_count = 0;
    
    // --- CRC Logic Signals ---
    reg [31:0] crc_reg;
    wire [3:0] current_data = (state == PAYLOAD) ? 4'hA : 4'h0; // Using 0xA as dummy
    wire [31:0] POLY = 32'hEDB88320;

    // Unified State Machine
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            eth_tx_en <= 0;
            crc_reg <= 32'hFFFFFFFF;
        end else begin
            case (state)
                IDLE: begin
                    eth_tx_en <= 0;
                    crc_reg <= 32'hFFFFFFFF; // Reset CRC for new frame
                    if (send_btn) state <= PREAMBLE;
                end

                PREAMBLE: begin
                    eth_tx_en <= 1;
                    eth_txd <= 4'h5; 
                    if (count == 13) begin // 7 bytes preamble
                        state <= SFD;
                        count <= 0;
                    end else count <= count + 1;
                end

                SFD: begin
                    if (count == 0) begin
                        eth_txd <= 4'h5;
                        count <= 1;
                    end else begin
                        eth_txd <= 4'hD;
                        state <= PAYLOAD;
                        count <= 0;
                        byte_count <= 0;
                    end
                end

                PAYLOAD: begin
                    eth_txd <= current_data;

                    // --- CRC Logic Step (Performed per nibble) ---
                    // 4 bits processed every clock cycle
                    begin : crc_update
                        integer i;
                        reg [31:0] next_crc;
                        next_crc = crc_reg;
                        for (i = 0; i < 4; i = i + 1) begin
                            if (next_crc[0] ^ current_data[i])
                                next_crc = (next_crc >> 1) ^ POLY;
                            else
                                next_crc = (next_crc >> 1);
                        end
                        crc_reg <= next_crc;
                    end

                    // Check for finished the minimum frame (64 bytes)
                    // Note: byte_count increments every 2 nibbles
                    if (count == 1) begin
                        count <= 0;
                        if (byte_count == 59) begin // 60 bytes (Payload) + 4 bytes (CRC) = 64
                            state <= CRC_OUT;
                            byte_count <= 0;
                        end else byte_count <= byte_count + 1;
                    end else count <= count + 1;
                end

                CRC_OUT: begin
                    // Transmit the inverted CRC_REG (The Remainder R)
                    // Nibble order: LSB nibble first
                    case (count)
                        0: eth_txd <= ~crc_reg[3:0];
                        1: eth_txd <= ~crc_reg[7:4];
                        2: eth_txd <= ~crc_reg[11:8];
                        3: eth_txd <= ~crc_reg[15:12];
                        4: eth_txd <= ~crc_reg[19:16];
                        5: eth_txd <= ~crc_reg[23:20];
                        6: eth_txd <= ~crc_reg[27:24];
                        7: eth_txd <= ~crc_reg[31:28];
                    endcase

                    if (count == 7) begin
                        state <= IDLE;
                        count <= 0;
                    end else count <= count + 1;
                end
            endcase
        end
    end
endmodule