
module filter_biquad_section_testbench #() ();
    reg rst;
    reg clk;
    
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

    localparam AUDIO_BDEPTH = 8;
    
    wire signed [AUDIO_BDEPTH-1:0] audio_in;
    wire                           audio_valid;
    
    wire signed [AUDIO_BDEPTH-1:0] audio_out;
    wire                           audio_out_valid;

    reg signed [15:0]        k  = ( 16384* 0.1122);
    reg signed [15:0]        a1 = (-16384*-1.9898);
    reg signed [15:0]        a2 = (-16384* 0.9937);
    reg signed [15:0]        b0 = ( 16384* 0.0031);
    reg signed [15:0]        b1 = ( 16384* 0.0000);
    reg signed [15:0]        b2 = ( 16384*-0.0031);
    
    filter_biquad_section #(
        .AUDIO_BDEPTH      (AUDIO_BDEPTH),
        .COEF_BDEPTH      (16)
    ) filter_inst (
        .clk          (clk),

        .audio_in (audio_in),
        .valid_in (audio_valid),

        .k (k),
        .a1(a1),
        .a2(a2),
        .b0(b0),
        .b1(b1),
        .b2(b2),

        .audio_out(audio_out),
        .valid_out(audio_out_valid),

        .sat_gain (sat_gain),
        .sat_accum(sat_accum)
    );

    integer           clock_div = 1;
    reg signed [5:0]  saw_gen   = 0;
    localparam CLOCK_DIV_RESET_VALUE = 100;
    always @(posedge clk) begin
        if (clock_div > 0) clock_div <= clock_div - 1;
        else begin
            clock_div <= CLOCK_DIV_RESET_VALUE;
            saw_gen <= saw_gen + 1;
        end
    end

    assign audio_valid = (clock_div == CLOCK_DIV_RESET_VALUE);
    
    assign audio_in = (saw_gen > 0 ? +120 : -120);

endmodule

