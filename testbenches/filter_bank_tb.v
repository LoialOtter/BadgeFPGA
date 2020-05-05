
module filter_bank_tb #() ();
    localparam ADDRESS_WIDTH = 16;
    localparam DATA_WIDTH    = 8;

    reg                      rst;
    reg                      clk;
    reg [ADDRESS_WIDTH-1:0]  adr;
    reg [DATA_WIDTH-1:0]     data;
    wire [DATA_WIDTH-1:0]    dut_data;
    reg                      we;
    reg                      sel;
    reg                      stb;
    reg                      cycle;
    wire                     dut_ack;
    reg [2:0]                cti;

    localparam AUDIO_BDEPTH = 8;

    wire [AUDIO_BDEPTH-1:0]  audio_in;
    reg                      valid_in = 0;

    wire [AUDIO_BDEPTH-1:0]  audio_out;
    wire                     valid_out;
    
    filter_bank #(
        .AUDIO_BDEPTH     ( AUDIO_BDEPTH ),
        .FILTER_COUNT     ( 4        ),
        .BASE_ADDRESS     ( 16'h0000 )
    ) filter_bank_inst (
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
        
        .audio_in ( audio_in ),
        .valid_in ( valid_in ),
        
        .audio_out ( audio_out ),
        .valid_out ( valid_out )
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
        cti   = 0;
        repeat(20) @(posedge clk);

        repeat(100) @(posedge clk);

        adr = 16'h0002; data = 8'hFF; we = 1; cycle=1; @(posedge clk); @(posedge clk); we=0; cycle=0; @(posedge clk); @(posedge clk);
        adr = 16'h0003; data = 8'h3F; we = 1; cycle=1; @(posedge clk); @(posedge clk); we=0; cycle=0; @(posedge clk); @(posedge clk);
        
        adr = 16'h0004; data = 8'hFF; we = 1; cycle=1; @(posedge clk); @(posedge clk); we=0; cycle=0; @(posedge clk); @(posedge clk);
        adr = 16'h0005; data = 8'h3F; we = 1; cycle=1; @(posedge clk); @(posedge clk); we=0; cycle=0; @(posedge clk); @(posedge clk);
        
        adr = 16'h0006; data = 8'hFF; we = 1; cycle=1; @(posedge clk); @(posedge clk); we=0; cycle=0; @(posedge clk); @(posedge clk);
        adr = 16'h0007; data = 8'h3F; we = 1; cycle=1; @(posedge clk); @(posedge clk); we=0; cycle=0; @(posedge clk); @(posedge clk);
        
        adr = 16'h0008; data = 8'hFF; we = 1; cycle=1; @(posedge clk); @(posedge clk); we=0; cycle=0; @(posedge clk); @(posedge clk);
        adr = 16'h0009; data = 8'h3F; we = 1; cycle=1; @(posedge clk); @(posedge clk); we=0; cycle=0; @(posedge clk); @(posedge clk);

        repeat(400000) @(posedge clk);
    end

    
    integer           clock_div = 1;
    reg signed [5:0]  saw_gen = 0;
    always @(posedge clk) begin
        if (clock_div > 0) clock_div <= clock_div - 1;
        else begin
            clock_div <= 750;
            saw_gen <= saw_gen + 1;
        end
    end

    integer sample_rate_div = 0;
    always @(posedge clk) begin
        valid_in <= 0;
        if (sample_rate_div) sample_rate_div <= sample_rate_div - 1;
        else begin
            sample_rate_div <= 100;
            valid_in        <= 1;
        end
    end

    assign audio_in = saw_gen; //(saw_gen > 0 ? 8'd127 : 8'd128);
    
endmodule
