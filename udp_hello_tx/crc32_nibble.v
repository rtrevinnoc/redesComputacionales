module crc32_nibble (
    input clk,
    input rst_n,
    input en,
    input [3:0] d,
    output [31:0] crc_out
);
    reg [31:0] c;
    wire [31:0] n;
    
    // Standard Ethernet CRC-32 polynomial logic for 4-bit nibbles
    assign n[0] = c[28] ^ d[0];
    assign n[1] = c[28] ^ c[29] ^ d[0] ^ d[1];
    assign n[2] = c[28] ^ c[29] ^ c[30] ^ d[0] ^ d[1] ^ d[2];
    assign n[3] = c[29] ^ c[30] ^ c[31] ^ d[1] ^ d[2] ^ d[3];
    assign n[4] = c[0] ^ c[28] ^ c[30] ^ c[31] ^ d[0] ^ d[2] ^ d[3];
    assign n[5] = c[1] ^ c[28] ^ c[29] ^ c[31] ^ d[0] ^ d[1] ^ d[3];
    assign n[6] = c[2] ^ c[29] ^ c[30] ^ d[1] ^ d[2];
    assign n[7] = c[3] ^ c[28] ^ c[30] ^ c[31] ^ d[0] ^ d[2] ^ d[3];
    assign n[8] = c[4] ^ c[28] ^ c[29] ^ c[31] ^ d[0] ^ d[1] ^ d[3];
    assign n[9] = c[5] ^ c[29] ^ c[30] ^ d[1] ^ d[2];
    assign n[10] = c[6] ^ c[28] ^ c[30] ^ c[31] ^ d[0] ^ d[2] ^ d[3];
    assign n[11] = c[7] ^ c[28] ^ c[29] ^ c[31] ^ d[0] ^ d[1] ^ d[3];
    assign n[12] = c[8] ^ c[28] ^ c[29] ^ c[30] ^ d[0] ^ d[1] ^ d[2];
    assign n[13] = c[9] ^ c[29] ^ c[30] ^ c[31] ^ d[1] ^ d[2] ^ d[3];
    assign n[14] = c[10] ^ c[30] ^ c[31] ^ d[2] ^ d[3];
    assign n[15] = c[11] ^ c[31] ^ d[3];
    assign n[16] = c[12] ^ c[28] ^ d[0];
    assign n[17] = c[13] ^ c[29] ^ d[1];
    assign n[18] = c[14] ^ c[30] ^ d[2];
    assign n[19] = c[15] ^ c[31] ^ d[3];
    assign n[20] = c[16];
    assign n[21] = c[17];
    assign n[22] = c[18] ^ c[28] ^ d[0];
    assign n[23] = c[19] ^ c[28] ^ c[29] ^ d[0] ^ d[1];
    assign n[24] = c[20] ^ c[29] ^ c[30] ^ d[1] ^ d[2];
    assign n[25] = c[21] ^ c[30] ^ c[31] ^ d[2] ^ d[3];
    assign n[26] = c[22] ^ c[28] ^ c[31] ^ d[0] ^ d[3];
    assign n[27] = c[23] ^ c[29] ^ d[1];
    assign n[28] = c[24] ^ c[30] ^ d[2];
    assign n[29] = c[25] ^ c[31] ^ d[3];
    assign n[30] = c[26];
    assign n[31] = c[27];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c <= 32'hFFFFFFFF;
        end else if (en) begin
            c <= n;
        end
    end

    // Remainder inverted for standard Ethernet
    assign crc_out = ~c;
endmodule
