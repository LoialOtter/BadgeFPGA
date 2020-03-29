module sid_chip_filter #(
    parameter AUDIO_BDEPTH       = 12,
    parameter AUDIO_OUT_BDEPTH   = AUDIO_BDEPTH,
    parameter FILTER_BDEPTH      = 16,
    parameter FILTER_COEF_BDEPTH = 16,
    parameter INPUT_GAIN_BITS    = 4,
    parameter OUTPUT_GAIN_BITS   = 6
                         
)  (
    input                                      clk,
    
    input wire signed [FILTER_COEF_BDEPTH-1:0] f_coefficient,
    input wire signed [FILTER_COEF_BDEPTH-1:0] q_coefficient,
    input wire                                 en_pass,
    input wire                                 en_lowpass,
    input wire                                 en_highpass,
    input wire                                 en_bandpass,

    input wire signed [AUDIO_BDEPTH-1:0]       audio_in,
    output wire signed [AUDIO_OUT_BDEPTH-1:0]  audio_out,

    output wire [11:0]                         debug
    );    


    // this is an alternative but I don't know how to read it
    //-- Predictor stage
    // hp  = -lp - sqrt(2)*bp + u(tt)
    // bp2 = bp + h*hp
    // lp2 = lp + h*hp
    //-- corrector stage
    // bp0 = bp
    // lp0 = lp
    // lp  = lp + 0.5*h*(bp0+bp2)
    // hp2 = -lp - sqrt(2)*bp2 + u(tt+1)
    // bp  = bp + 0.5*h*(hp0+hp2)


    
    wire signed [FILTER_BDEPTH-1:0] highpass;
    wire signed [FILTER_BDEPTH-1:0] f_highpass;
    wire signed [FILTER_BDEPTH-1:0] bandpass;
    wire signed [FILTER_BDEPTH-1:0] q_bandpass_1;
    wire signed [FILTER_BDEPTH-1:0] f_bandpass_1;
    wire signed [FILTER_BDEPTH-1:0] lowpass;
    reg signed [FILTER_BDEPTH-1:0]  highpass_1 = 0;
    reg signed [FILTER_BDEPTH-1:0]  bandpass_1 = 0;
    reg signed [FILTER_BDEPTH-1:0]  lowpass_1 = 0;
    
    wire [6:0] saturation;

    wire signed [FILTER_COEF_BDEPTH+1-1:0] q_coefficient_used;
    wire signed [FILTER_COEF_BDEPTH+1-1:0] f_coefficient_used;
    assign q_coefficient_used = $signed({1'b0,q_coefficient});  //(|saturation ? $signed({1'b0,q_coefficient[FILTER_COEF_BDEPTH-8-1:0],8'b0}) : $signed({1'b0,q_coefficient}));
    assign f_coefficient_used = $signed({1'b0,f_coefficient});

    //-- High pass
    // highpass = input + -q_bandpass_1 + -lowpass
    wire signed [FILTER_BDEPTH+1-1:0] q_bandpass1_lowpass;
    wire signed [FILTER_BDEPTH-1:0] q_bandpass1_lowpass_clipped;
    saturated_signed_adder #(.AS(FILTER_BDEPTH),.BS(FILTER_BDEPTH),.OUTS(FILTER_BDEPTH+1)) add_inst_1 (.a(q_bandpass_1), .b(lowpass), .out(q_bandpass1_lowpass), .sat(saturation[0]));
    
    saturate #(.AS(FILTER_BDEPTH+1),.OUTS(FILTER_BDEPTH)) saturate_inst_1 (.a(-q_bandpass1_lowpass), .out(q_bandpass1_lowpass_clipped), .sat());
    
    saturated_signed_adder #(.AS(AUDIO_BDEPTH+INPUT_GAIN_BITS),.BS(FILTER_BDEPTH),.OUTS(FILTER_BDEPTH)) add_inst_2 (.a({audio_in,{INPUT_GAIN_BITS{1'b0}}}), .b(q_bandpass1_lowpass_clipped), .out(highpass), .sat(saturation[1]));

    // f_highpass = f_coefficient * highpass
    saturation_signed_multiply #(.AS(FILTER_COEF_BDEPTH+1),.BS(FILTER_BDEPTH),.OFFSET(16),.OUTS(FILTER_BDEPTH)) mult_inst_1 (.a(f_coefficient_used), .b(highpass), .out(f_highpass), .sat(saturation[2]));
    
    // bandpass = f_highpass + bandpass_1
    saturated_signed_adder #(.AS(FILTER_BDEPTH),.BS(FILTER_BDEPTH)) add_inst_3 (.a(f_highpass), .b(bandpass_1), .out(bandpass), .sat(saturation[3]));

    // q_bandpass_1 = q_coefficient * bandpass_1
    saturation_signed_multiply #(.AS(FILTER_COEF_BDEPTH+1),.BS(FILTER_BDEPTH),.OFFSET(12),.OUTS(FILTER_BDEPTH)) mult_inst_2 (.a(q_coefficient_used), .b(bandpass_1), .out(q_bandpass_1), .sat(saturation[4]));
    
    // f_bandpass_1 = f_coefficient * bandpass_1
    saturation_signed_multiply #(.AS(FILTER_COEF_BDEPTH+1),.BS(FILTER_BDEPTH),.OFFSET(16),.OUTS(FILTER_BDEPTH)) mult_inst_3 (.a(f_coefficient_used), .b(bandpass_1), .out(f_bandpass_1), .sat(saturation[5]));
    
    // lowpass = lowpass_1 + f_bandpass_1
    saturated_signed_adder #(.AS(FILTER_BDEPTH),.BS(FILTER_BDEPTH)) add_inst_4 (.a(lowpass_1), .b(f_bandpass_1), .out(lowpass), .sat(saturation[6]));


    
    // bandpass_1 <= bandpass
    // lowpass_1 <= lowpass
    always @(posedge clk) begin
        highpass_1   <= highpass;
        bandpass_1   <= bandpass;
        lowpass_1    <= lowpass;
    end


    wire signed [FILTER_BDEPTH-1:0] audio_p_lp;
    wire signed [FILTER_BDEPTH-1:0] audio_hp_bp;
    wire signed [FILTER_BDEPTH-1:0] audio_mixed;

    saturated_signed_adder #(.AS(FILTER_BDEPTH),.BS(AUDIO_BDEPTH+INPUT_GAIN_BITS),.OUTS(FILTER_BDEPTH)) add_inst_5 (
        .a(en_lowpass ? lowpass_1 : {FILTER_BDEPTH{1'b0}}),
        .b(en_pass ? {audio_in,{INPUT_GAIN_BITS{1'b0}}} : {(AUDIO_BDEPTH+INPUT_GAIN_BITS){1'b0}}),
        .out(audio_p_lp), .sat()
    );
    saturated_signed_adder #(.AS(FILTER_BDEPTH),.BS(FILTER_BDEPTH)) add_inst_6 (
        .a(en_bandpass ? bandpass_1 : {FILTER_BDEPTH{1'b0}}),
        .b(en_highpass ? highpass_1 : {FILTER_BDEPTH{1'b0}}),
        .out(audio_hp_bp), .sat()
    );
    saturated_signed_adder #(.AS(FILTER_BDEPTH),.BS(FILTER_BDEPTH)) add_inst_7 (
        .a(audio_p_lp), .b(audio_hp_bp), .out(audio_mixed), .sat()
    );

    reg signed [FILTER_BDEPTH-1:0] audio_p_lp_1 = 0;
    reg signed [FILTER_BDEPTH-1:0] audio_hp_bp_1 = 0;
    reg signed [FILTER_BDEPTH-1:0] audio_mixed_1 = 0;
    always @(posedge clk) begin
        audio_p_lp_1  <= audio_p_lp;
        audio_hp_bp_1 <= audio_hp_bp;
        audio_mixed_1 <= audio_mixed;
    end

    saturate #(.AS(FILTER_BDEPTH-OUTPUT_GAIN_BITS),.OUTS(AUDIO_OUT_BDEPTH)) saturate_inst_2 (.a(audio_mixed_1[FILTER_BDEPTH-1:OUTPUT_GAIN_BITS]), .out(audio_out), .sat());

    assign debug = { 4'd0, audio_out };
    
endmodule
