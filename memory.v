`default_nettype none

module wishbone_memory #(
    parameter ADDRESS_WIDTH = 16,
    parameter DATA_WIDTH = 8,
    parameter DATA_BYTES = 1,
    parameter BASE_ADDRESS = 0,
    parameter MEMORY_SIZE = 512
)  (
    // Wishbone interface
    input wire                     rst_i,
    input wire                     clk_i,

    input wire [ADDRESS_WIDTH-1:0] adr_i,
    input wire [DATA_WIDTH-1:0]    dat_i,
    output wire [DATA_WIDTH-1:0]   dat_o,
    input wire                     we_i,
    input wire [DATA_BYTES-1:0]    sel_i,
    input wire                     stb_i,
    input wire                     cyc_i,
    output reg                     ack_o,
    input wire [2:0]               cti_i
    );

    localparam MEMORY_SIZE_I  = (MEMORY_SIZE <=  512 ? 9 :
                                 MEMORY_SIZE <= 1024 ? 10 :
                                 MEMORY_SIZE <= 2048 ? 11 : 
                                 MEMORY_SIZE <= 4096 ? 12 :
                                 MEMORY_SIZE <= 8192 ? 13 : 14);
    
    wire [ADDRESS_WIDTH-1:0] local_address;
    wire                     valid_address;
    assign local_address = adr_i - BASE_ADDRESS;
    assign valid_address = local_address < MEMORY_SIZE;

    always @(posedge clk_i) begin
        ack_o <= cyc_i & valid_address;
    end
    
    simple_ram #(
        .addr_width( MEMORY_SIZE_I ),
        .data_width( DATA_WIDTH )
    ) memory_inst (
        .clk     ( clk_i ),
        .address ( local_address[MEMORY_SIZE_I-1:0] ),
        .din     ( dat_i ),
        .dout    ( dat_o ),
        .we      ( cyc_i & valid_address & we_i )
    );
    
endmodule

module simple_ram #(//512x8
    parameter addr_width = 9,
    parameter data_width = 8
)  (
    input wire                  clk,
    input wire [addr_width-1:0] address, 
    input wire [data_width-1:0] din,
    output reg [data_width-1:0] dout,
    input wire                  we
    );
    
    reg [data_width-1:0] mem [(1<<addr_width)-1:0];
    
    always @(posedge clk) // Write memory.
    begin
        if (we)
            mem[address] <= din; // Using write address bus.
        dout <= mem[address]; // Using read address bus.
    end
endmodule    
