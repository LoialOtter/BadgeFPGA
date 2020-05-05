module filter_biquad_section #(
    parameter AUDIO_BDEPTH    = 12,
    parameter COEF_BDEPTH     = 12
)  (
    input wire                           clk,

    input wire signed [AUDIO_BDEPTH-1:0] audio_in,
    input wire                           valid_in,

    // A note, these are -2 to +2 so -1 to 1 = -16384 to 16384
    input wire signed [COEF_BDEPTH-1:0]  k,
    input wire signed [COEF_BDEPTH-1:0]  a1,
    input wire signed [COEF_BDEPTH-1:0]  a2,
    input wire signed [COEF_BDEPTH-1:0]  b0,
    input wire signed [COEF_BDEPTH-1:0]  b1,
    input wire signed [COEF_BDEPTH-1:0]  b2,

    output reg signed [AUDIO_BDEPTH-1:0] audio_out,
    output reg                           valid_out,
    
    output wire                          sat_gain,
    output wire                          sat_accum

    //output reg signed [AUDIO_BDEPTH-1:0] debug_k ,
    //output reg signed [AUDIO_BDEPTH-1:0] debug_a1,
    //output reg signed [AUDIO_BDEPTH-1:0] debug_a2,
    //output reg signed [AUDIO_BDEPTH-1:0] debug_b0,
    //output reg signed [AUDIO_BDEPTH-1:0] debug_b1,
    //output reg signed [AUDIO_BDEPTH-1:0] debug_b2
    
    );


    // Structure:
    //
    //  X(n) --> gain(K) --> (+) --------------+--> gain(b0) --> (+) --> y(n)
    //                       ^ ^               |                 ^ ^
    //                       | |               v                 | |
    //                       | |            [Z^-1]               | |
    //                       | |               |                 | |
    //                       | |               |                 | |
    //                       | +-- gain(a1) <--+--> gain(b1) ----+ |
    //                       |                 |                   |
    //                       |                 v                   |
    //                       |              [Z^-1]                 |
    //                       |                 |                   |
    //                       |                 |                   |
    //                       +---- gain(a2) <--+--> gain(b2) ------+

    wire valid_in_pulse;
    reg last_valid_in;
    always @(posedge clk) begin
        last_valid_in <= valid_in;
    end
    assign valid_in_pulse = valid_in & !last_valid_in;

    reg [6:0] current_step;
    localparam STEP_K   = 7'b0000001;
    localparam STEP_A1  = 7'b0000010;
    localparam STEP_A2  = 7'b0000100;
    localparam STEP_B0  = 7'b0001000;
    localparam STEP_B1  = 7'b0010000;
    localparam STEP_B2  = 7'b0100000;
    localparam STEP_OUT = 7'b1000000;
    
    reg signed [AUDIO_BDEPTH-1:0]  z_1;
    reg signed [AUDIO_BDEPTH-1:0]  z_2;

    reg signed [AUDIO_BDEPTH-1:0]  gain_in;
    reg signed [COEF_BDEPTH-1:0]   coef_in;
    wire signed [AUDIO_BDEPTH-1:0] accum_in;
    reg signed [AUDIO_BDEPTH-1:0]  accum_reg;
    wire signed [AUDIO_BDEPTH-1:0] accum_out;
    
    saturation_signed_multiply #(
        .AS    ( AUDIO_BDEPTH ),
        .BS    ( COEF_BDEPTH  ),
        .OFFSET( COEF_BDEPTH-1 ),
        .OUTS  ( AUDIO_BDEPTH )
    ) mult_inst (
        .a  ( gain_in ),
        .b  ( coef_in ),
        .out( accum_in ),
        .sat( )
    );
    
    saturated_signed_adder #(
        .AS  ( AUDIO_BDEPTH ),
        .BS  ( AUDIO_BDEPTH ),
        .OUTS( AUDIO_BDEPTH )
    ) add_inst_1 
       (
        .a   ( accum_in  ),
        .b   ( accum_reg ),
        .out ( accum_out ),
        .sat ( )
    );

    reg signed [AUDIO_BDEPTH-1:0]  latched_audio_in;
    always @(posedge clk) begin
        latched_audio_in <= audio_in;
    end
    
    always @(posedge clk) begin
        case (current_step)
        STEP_K:   begin   gain_in = latched_audio_in;  coef_in =  k;  end
        STEP_A1:  begin   gain_in =              z_1;  coef_in = a1;  end
        STEP_A2:  begin   gain_in =              z_2;  coef_in = a2;  end
        STEP_B0:  begin   gain_in =        accum_reg;  coef_in = b0;  end
        STEP_B1:  begin   gain_in =              z_1;  coef_in = b1;  end
        STEP_B2:  begin   gain_in =              z_2;  coef_in = b2;  end
        STEP_OUT: begin   gain_in =                0;  coef_in =  0;  end
        endcase
    end

    
    always @(posedge clk) begin
        if (current_step == STEP_OUT) begin 
            accum_reg <= 0;
            valid_out <= 1;
            audio_out <= accum_reg;
        end
        else begin
            if (current_step != STEP_K || valid_in_pulse)
                accum_reg <= accum_out;
            valid_out     <= 0;
            audio_out     <= audio_out;
        end
        
        if (current_step == STEP_B0) begin
            z_1 <= accum_reg;
            z_2 <= z_1;
        end
        else begin
            z_1 <= z_1;
            z_2 <= z_2;
        end
            
        case (current_step)

        STEP_K: begin
            if (valid_in_pulse) current_step <= STEP_A1;
        end
        STEP_A1: current_step <= STEP_A2;
        STEP_A2: current_step <= STEP_B0;
        STEP_B0: current_step <= STEP_B1;
        STEP_B1: current_step <= STEP_B2;
        STEP_B2: current_step <= STEP_OUT;
        STEP_OUT: current_step <= STEP_K;
        default: begin
            z_1          <= 0;
            z_2          <= 0;
            accum_reg    <= 0;
            audio_out    <= 0;
            current_step <= STEP_K;
        end
        endcase
    end


    //always @(posedge clk) begin
    //    case (current_step)
    //    STEP_K:   begin  debug_k  <= accum_in;  end
    //    STEP_A1:  begin  debug_a1 <= accum_in;  end
    //    STEP_A2:  begin  debug_a2 <= accum_in;  end
    //    STEP_B0:  begin  debug_b0 <= accum_in;  end
    //    STEP_B1:  begin  debug_b1 <= accum_in;  end
    //    STEP_B2:  begin  debug_b2 <= accum_in;  end
    //    STEP_OUT: begin    end
    //    endcase
    //end
        
endmodule
