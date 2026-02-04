module circuit(
    input  wire       clk,        // 25MHz Ethernet TX Clock from PHY
    input  wire       rst,        // System Reset
    input  wire       send_btn,   // Button to trigger transmission
    output reg  [3:0] eth_txd,    // MII Data Nibbles
    output reg        eth_tx_en   // TX Enable (High while sending)
);

    // State Machine
    localparam IDLE     = 0,
               PREAMBLE = 1,
               SFD      = 2,
               PAYLOAD  = 3;

    reg [1:0] state = IDLE;
    reg [3:0] count = 0;
    reg [7:0] byte_count = 0;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            eth_tx_en <= 0;
        end else begin
            case (state)
                IDLE: begin
                    eth_tx_en <= 0;
                    if (send_btn) state <= PREAMBLE;
                end

                PREAMBLE: begin
                    eth_tx_en <= 1;
                    eth_txd <= 4'h5; // MII sends nibbles, 0x55 is 8'h5 then 8'h5
                    if (count == 13) begin // 7 bytes = 14 nibbles
                        state <= SFD;
                        count <= 0;
                    end else count <= count + 1;
                end

                SFD: begin
                    // SFD is 0xD5 (nibbles 5 then D)
                    if (count == 0) begin
                        eth_txd <= 4'h5;
                        count <= 1;
                    end else begin
                        eth_txd <= 4'hD;
                        state <= PAYLOAD;
                        count <= 0;
                    end
                end

                PAYLOAD: begin
                    eth_txd <= 4'hA; // Dummy Data
                    if (byte_count == 63) begin // Minimum 64 bytes
                        state <= IDLE;
                        byte_count <= 0;
                    end else byte_count <= byte_count + 1;
                end
            endcase
        end
    end
endmodule