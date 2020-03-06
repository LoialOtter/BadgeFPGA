
module sid_chip_testbench #() ();

    localparam ADDRESS_WIDTH = 16;
    localparam DATA_WIDTH    = 8;

    reg rst;
    reg clk;
    reg [ADDRESS_WIDTH-1:0] adr;
    reg [DATA_WIDTH-1:0]    data;
    wire [DATA_WIDTH-1:0]   dut_data;
    reg                     we;
    reg                     sel;
    reg                     stb;
    reg                     cycle;
    wire                    dug_ack;
    reg [2:0]               ctl;

    wire                    audio_p;
    wire                    audio_n;
    
    sid_chip #(
        .ADDRESS_WIDTH (16),
        .DATA_WIDTH    (8),
        .DATA_BYTES    (1),
        .BASE_ADDRESS  (16'h0100)
    ) sid1_inst (
        .rst_i ( rst ),
        .clk_i ( clk ),
        .adr_i ( adr ),
        .dat_i ( data ),
        .dat_o ( dut_data ),
        .we_i  ( we ),
        .sel_i ( sel ),
        .stb_i ( stb ),
        .cyc_i ( cycle ),
        .ack_o ( dut_ack ),
        .cti_i ( cti ),

        .audio_p (audio_p),
        .audio_n (audio_n)
    );
    
    
    localparam  CLOCK_PERIOD            = 100; // Clock period in ps
    localparam  INITIAL_RESET_CYCLES    = 10;  // Number of cycles to reset when simulation starts
    initial clk = 1'b1;
    always begin
        #(CLOCK_PERIOD / 2);
        clk = ~clk;
    end

        // Initial reset
    initial begin
        rst = 1'b1;
        repeat(INITIAL_RESET_CYCLES) @(posedge clk);
        rst = 1'b0;
    end

    
    // Test cycle
    initial begin
        adr   = 16'h0000;
        data  = 8'h00;
        we    = 1;
        sel   = 1;
        stb   = 0;
        cycle = 0;
        ctl   = 0;

        repeat(20) @(posedge clk);

        repeat(100000) @(posedge clk);

        adr = 16'h0104; data = 8'h31; we = 1; cycle=1;
        @(posedge clk); @(posedge clk);
        we=0; cycle=0;
        repeat(400000) @(posedge clk);

        adr = 16'h0104; data = 8'h30; we = 1; cycle=1;
        @(posedge clk); @(posedge clk);
        we=0; cycle=0;
        repeat(400000) @(posedge clk);

        adr = 16'h0104; data = 8'h31; we = 1; cycle=1;
        @(posedge clk); @(posedge clk);
        we=0; cycle=0;
        repeat(400000) @(posedge clk);

        adr = 16'h0104; data = 8'h30; we = 1; cycle=1;
        @(posedge clk); @(posedge clk);
        we=0; cycle=0;
        repeat(400000) @(posedge clk);
    end

endmodule
