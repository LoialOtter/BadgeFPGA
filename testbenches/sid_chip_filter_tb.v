
module sid_chip_filter_testbench #() ();
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

    wire signed [7:0] audio_in;
    wire signed [7:0] audio_out;

    reg [15:0]        f_coefficient = 100;
    reg [15:0]        q_coefficient = 4096;
    wire              en_pass   = 0;
    wire              filter_lp = 1;
    wire              filter_hp = 0;
    wire              filter_bp = 0;
    
    sid_chip_filter #(
        .AUDIO_BDEPTH      (8),
        .FILTER_BDEPTH     (16),
        .FILTER_COEF_BDEPTH(16),
        .INPUT_GAIN_BITS   (6)
    ) filter_inst (
        .clk          (clk),

        .f_coefficient(f_coefficient),
        .q_coefficient(q_coefficient),
        .en_pass      (en_pass),
        .en_lowpass   (filter_lp),
        .en_highpass  (filter_hp),
        .en_bandpass  (filter_bp),

        .audio_in     (audio_in),
        .audio_out    (audio_out)
    );

    integer           clock_div = 1;
    reg signed [5:0]  saw_gen = 0;
    always @(posedge clk) begin
        if (clock_div > 0) clock_div <= clock_div - 1;
        else begin
            clock_div <= 100;
            saw_gen <= saw_gen + 1;
        end
    end

    assign audio_in = (saw_gen > 0 ? 8'd127 : 8'd128);

endmodule

