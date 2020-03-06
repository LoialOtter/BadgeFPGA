module protocol_testbench #() ();

    localparam ADDRESS_WIDTH = 16;
    localparam DATA_WIDTH    = 8;
    localparam DATA_BYTES    = 1;
    localparam MAX_WAIT      = 8;
    localparam MAX_PAYLOAD = 8;
    
    localparam INTERFACE_WIDTH = (MAX_PAYLOAD * DATA_WIDTH);
    localparam INTERFACE_LENGTH_N = ((MAX_PAYLOAD <=  2) ? 1 :
                                     (MAX_PAYLOAD <=  4) ? 2 :
                                     (MAX_PAYLOAD <=  8) ? 3 :
                                     (MAX_PAYLOAD <= 16) ? 4 :
                                     (MAX_PAYLOAD <= 32) ? 5 :
                                     /*           <= 64 */ 6);

    wire                         clk;
    wire                         rst;

    reg                          rst_i;
    reg                          clk_i;

                                 
    wire [ADDRESS_WIDTH-1:0]     adr_o;
    reg [DATA_WIDTH-1:0]         dat_i;
    wire [DATA_WIDTH-1:0]        dat_o;
    wire                         we_o;
    wire [DATA_BYTES-1:0]        sel_o;
    wire                         stb_o;
    reg                          cyc_i;
    wire                         cyc_o;
    reg                          ack_i;
    wire [2:0]                   cti_o;


    // Uart interfaces
    reg [7:0]                rx_byte;
    reg                      rx_byte_valid;
        
    wire [7:0]               tx_byte;
    wire                     tx_byte_valid;
    reg                      tx_ready;

    

    rs232_protocol #(
        .ADDRESS_WIDTH (16),
        .DATA_WIDTH    (8 ),
        .DATA_BYTES    (1 ),
        .MAX_WAIT      (8 ),
        .MAX_PAYLOAD   (8 )
    ) protocol_inst (
        // Wishbone interface
        .rst_i ( rst_i ),
        .clk_i ( clk_i ),

        .adr_o ( adr_o ),
        .dat_i ( dat_i ),
        .dat_o ( dat_o ),
        .we_o  ( we_o  ),
        .sel_o ( sel_o ),
        .stb_o ( stb_o ),
        .cyc_i ( cyc_i ),
        .cyc_o ( cyc_o ),
        .ack_i ( ack_i ),
        .cti_o ( cti_o ),
        
        // Uart interfaces
        .rx_byte       ( rx_byte       ),
        .rx_byte_valid ( rx_byte_valid ),
        
        .tx_byte       ( tx_byte       ),
        .tx_byte_valid ( tx_byte_valid ),
        .tx_ready      ( tx_ready      )
    );


    // simple LED module to check the wishbone interface
    reg [4:0]                leds;
    reg [4:0]                next_leds;
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            leds <= 5'b01010;
        end
        else begin
            leds <= next_leds;
        end
    end
    always @(*) begin
        dat_i     = 8'd0;
        next_leds = leds;
        ack_i     = 1'd0;
        
        if (cyc_o && adr_o == 16'd0) begin
            dat_i = { 3'd0, leds };
            ack_i = 1'b1;
            if (we_o) begin
                next_leds = dat_o[4:0];
            end
        end
    end

    initial cyc_i = 0;

    
    localparam  CLOCK_PERIOD            = 100; // Clock period in ps
    localparam  INITIAL_RESET_CYCLES    = 10;  // Number of cycles to reset when simulation starts
    // Clock signal generator
    initial clk_i = 1'b1;
    always begin
        #(CLOCK_PERIOD / 2);
        clk_i = ~clk_i;
    end
    
    // Initial reset
    initial begin
        rst_i = 1'b1;
        repeat(INITIAL_RESET_CYCLES) @(posedge clk_i);
        rst_i = 1'b0;
    end

    assign clk = clk_i;
    assign rst = rst_i;

    // Test cycle
    initial begin
        tx_ready      = 1;
        rx_byte       = 8'd0;
        rx_byte_valid = 0;

        wait(rst);
        wait(!rst);
        repeat(12) @(posedge clk);

        // Error cycle - command not found
        rx_byte       = "?";
        rx_byte_valid = 1;
        @(posedge clk);
        rx_byte_valid = 0;

        repeat(9) @(posedge clk);
        rx_byte       = "a";
        rx_byte_valid = 1;
        @(posedge clk);
        rx_byte_valid = 0;

        //-----------------------------------------
        // read of address 0
        repeat(10) @(posedge clk);
        repeat(9) @(posedge clk);
        rx_byte       = "?";
        rx_byte_valid = 1;
        @(posedge clk);
        rx_byte_valid = 0;
        
        repeat(9) @(posedge clk);
        rx_byte       = "r";
        rx_byte_valid = 1;
        @(posedge clk);
        rx_byte_valid = 0;
        
        repeat(9) @(posedge clk);
        rx_byte       = "0";
        rx_byte_valid = 1;
        @(posedge clk);
        rx_byte_valid = 0;
        
        repeat(9) @(posedge clk);
        rx_byte       = "0";
        rx_byte_valid = 1;
        @(posedge clk);
        rx_byte_valid = 0;
        
        repeat(9) @(posedge clk);
        rx_byte       = "0";
        rx_byte_valid = 1;
        @(posedge clk);
        rx_byte_valid = 0;
        
        repeat(9) @(posedge clk);
        rx_byte       = "0";
        rx_byte_valid = 1;
        @(posedge clk);
        rx_byte_valid = 0;

        //-----------------------------------------
        // write of address 0
        repeat(10) @(posedge clk);
        repeat(9) @(posedge clk);  rx_byte = "?";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "w";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "0";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "0";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "0";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "0";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "1";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "5";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;

        //-----------------------------------------
        // re-read of address 0
        repeat(10) @(posedge clk);
        repeat(9) @(posedge clk);  rx_byte = "?";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "r";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "0";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "0";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "0";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        repeat(9) @(posedge clk);  rx_byte = "0";  rx_byte_valid = 1; @(posedge clk); rx_byte_valid = 0;
        
    end


    
        
    
endmodule


