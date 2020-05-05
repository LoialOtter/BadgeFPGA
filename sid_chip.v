`include "globals.v"

module sid_chip #(
    parameter ADDRESS_WIDTH = 16,
    parameter DATA_WIDTH = 8,
    parameter DATA_BYTES = 1,
    parameter BASE_ADDRESS = 0,
    parameter FILTER_BASE_ADDRESS = 16'h0100
)  (
    // Wishbone interface
    input wire                     rst_i,
    input wire                     clk_i,

    input wire [ADDRESS_WIDTH-1:0] adr_i,
    input wire [DATA_WIDTH-1:0]    dat_i,
    output reg [DATA_WIDTH-1:0]    dat_o,
    input wire                     we_i,
    input wire [DATA_BYTES-1:0]    sel_i,
    input wire                     stb_i,
    input wire                     cyc_i,
    output reg                     ack_o,
    input wire [2:0]               cti_i,

    // audio out
    output wire                    audio_p,
    output wire                    audio_n,

    output wire [11:0]             debug
    );

    localparam FILTER_BDEPTH      = 16;
    localparam FILTER_COEF_BDEPTH = 16;

    reg [FILTER_COEF_BDEPTH-1:0] f_coefficient;
    reg [FILTER_COEF_BDEPTH-1:0] q_coefficient;


    wire [DATA_WIDTH-1:0] filter_dat_o;
    wire                  filter_ack_o;
    reg [DATA_WIDTH-1:0]  sid_dat_o;
    reg                   sid_ack_o;
    always @(*) begin
        if (filter_ack_o) begin
            ack_o = 1;
            dat_o = filter_dat_o;
        end
        else if (sid_ack_o) begin
            ack_o = 1;
            dat_o = sid_dat_o;
        end
        else begin
            ack_o = 0;
            dat_o = 0;
        end
    end
    
    
    reg        valid_address;
    
    reg [15:0] voice1_freq    ;
    reg [12:0] voice1_pw      ;
    reg [3:0]  voice1_extra   ;
    reg        voice1_pulse   ;
    reg        voice1_saw     ;
    reg        voice1_tri     ;
    reg        voice1_noise   ;
    reg        voice1_sample  ;
    reg        voice1_test    ;
    reg        voice1_ringmod ;
    reg        voice1_sync    ;
    reg        voice1_gate    ;
    reg [3:0]  voice1_attack  ;
    reg [3:0]  voice1_decay   ;
    reg [3:0]  voice1_sustain ;
    reg [3:0]  voice1_release ;
    
    //reg [15:0] voice2_freq    ;
    //reg [12:0] voice2_pw      ;
    //reg [3:0]  voice2_extra   ;
    //reg        voice2_pulse   ;
    //reg        voice2_saw     ;
    //reg        voice2_tri     ;
    //reg        voice2_noise   ;
    //reg        voice2_sample  ;
    //reg        voice2_test    ;
    //reg        voice2_ringmod ;
    //reg        voice2_sync    ;
    //reg        voice2_gate    ;
    //reg [3:0]  voice2_attack  ;
    //reg [3:0]  voice2_decay   ;
    //reg [3:0]  voice2_sustain ;
    //reg [3:0]  voice2_release ;
    //
    //reg [15:0] voice3_freq    ;
    //reg [12:0] voice3_pw      ;
    //reg [3:0]  voice3_extra   ;
    //reg        voice3_pulse   ;
    //reg        voice3_saw     ;
    //reg        voice3_tri     ;
    //reg        voice3_noise   ;
    //reg        voice3_sample  ;
    //reg        voice3_test    ;
    //reg        voice3_ringmod ;
    //reg        voice3_sync    ;
    //reg        voice3_gate    ;
    //reg [3:0]  voice3_attack  ;
    //reg [3:0]  voice3_decay   ;
    //reg [3:0]  voice3_sustain ;
    //reg [3:0]  voice3_release ;
    
    reg [10:0] filter_center  ;
    reg [4:0]  filter_extra   ;
    reg [3:0]  filter_res     ;
    reg        filter_ex      ;
    reg        filter_v1      ;
    reg        filter_v2      ;
    reg        filter_v3      ;
    reg        filter_3_off   ;
    reg        filter_lp      ;
    reg        filter_hp      ;
    reg        filter_bp      ;
    
    reg [3:0]  volume         ;

    wire       address_in_range;
    wire [5:0] local_address;
    assign address_in_range = (adr_i & 16'hFFE0) == BASE_ADDRESS;
    assign local_address = address_in_range ? adr_i[5:0] : 6'h3F;

    wire       clk;
    wire       rst;
    assign clk = clk_i;
    assign rst = rst_i;

    
    always @(posedge clk_i) begin
        sid_ack_o <= cyc_i & valid_address;
    end
    
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            voice1_freq    <= 60000;
            voice1_pw      <= 2048;
            voice1_extra   <= 0;
            voice1_pulse   <= 0;
            voice1_saw     <= 1;
            voice1_tri     <= 1;
            voice1_noise   <= 0;
            voice1_sample  <= 0;
            voice1_test    <= 0;
            voice1_ringmod <= 0;
            voice1_sync    <= 0;
            voice1_gate    <= 0;
            voice1_attack  <= 0;
            voice1_decay   <= 0;
            voice1_sustain <= 8;
            voice1_release <= 0;

            //voice2_freq    <= 0;
            //voice2_pw      <= 0;
            //voice2_extra   <= 0;
            //voice2_pulse   <= 0;
            //voice2_saw     <= 0;
            //voice2_tri     <= 0;
            //voice2_noise   <= 0;
            //voice2_sample  <= 0;
            //voice2_test    <= 0;
            //voice2_ringmod <= 0;
            //voice2_sync    <= 0;
            //voice2_gate    <= 0;
            //voice2_attack  <= 0;
            //voice2_decay   <= 0;
            //voice2_sustain <= 0;
            //voice2_release <= 0;
            //
            //voice3_freq    <= 0;
            //voice3_pw      <= 0;
            //voice3_extra   <= 0;
            //voice3_pulse   <= 0;
            //voice3_saw     <= 0;
            //voice3_tri     <= 0;
            //voice3_noise   <= 0;
            //voice3_sample  <= 0;
            //voice3_test    <= 0;
            //voice3_ringmod <= 0;
            //voice3_sync    <= 0;
            //voice3_gate    <= 0;
            //voice3_attack  <= 0;
            //voice3_decay   <= 0;
            //voice3_sustain <= 0;
            //voice3_release <= 0;
            
            filter_center  <= 0;
            filter_extra   <= 0;
            filter_res     <= 0;
            filter_ex      <= 0;
            filter_v1      <= 0;
            filter_v2      <= 0;
            filter_v3      <= 0;
            filter_3_off   <= 0;
            filter_lp      <= 0;
            filter_hp      <= 0;
            filter_bp      <= 0;
            
            volume         <= 15;

            f_coefficient  <= 800;
            q_coefficient  <= 4096;
        end
        else begin
            if (cyc_i & we_i) begin
                if      (local_address == `SID_OFFSET_VOICE1_FREQ_L ) { voice1_freq[7:0] } <= dat_i;
                else if (local_address == `SID_OFFSET_VOICE1_FREQ_H ) { voice1_freq[15:8] } <= dat_i;
                else if (local_address == `SID_OFFSET_VOICE1_PW_L   ) { voice1_pw[7:0]    } <= dat_i;
                else if (local_address == `SID_OFFSET_VOICE1_PW_H   ) { voice1_extra, voice1_pw[11:8] } <= dat_i;
                else if (local_address == `SID_OFFSET_VOICE1_CONTROL) { voice1_noise, voice1_pulse, voice1_saw, voice1_tri, voice1_test, voice1_ringmod, voice1_sync, voice1_gate } <= dat_i;
                else if (local_address == `SID_OFFSET_VOICE1_ATTDEC ) { voice1_attack, voice1_decay }  <= dat_i;
                else if (local_address == `SID_OFFSET_VOICE1_SSTREL ) { voice1_sustain, voice1_release } <= dat_i;

                //else if (local_address == `SID_OFFSET_VOICE2_FREQ_L ) { voice2_freq[7:0]  } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE2_FREQ_H ) { voice2_freq[15:8] } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE2_PW_L   ) { voice2_pw[7:0]    } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE2_PW_H   ) { voice2_extra, voice2_pw[11:8] } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE2_CONTROL) { voice2_noise, voice2_pulse, voice2_saw, voice2_tri, voice2_test, voice2_ringmod, voice2_sync, voice2_gate } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE2_ATTDEC ) { voice2_attack, voice2_decay }  <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE2_SSTREL ) { voice2_sustain, voice2_release } <= dat_i;
                //
                //else if (local_address == `SID_OFFSET_VOICE3_FREQ_L ) { voice3_freq[7:0]  } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE3_FREQ_H ) { voice3_freq[15:8] } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE3_PW_L   ) { voice3_pw[7:0]    } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE3_PW_H   ) { voice3_extra, voice3_pw[11:8] } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE3_CONTROL) { voice3_noise, voice3_pulse, voice3_saw, voice3_tri, voice3_test, voice3_ringmod, voice3_sync, voice3_gate } <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE3_ATTDEC ) { voice3_attack, voice3_decay }  <= dat_i;
                //else if (local_address == `SID_OFFSET_VOICE3_SSTREL ) { voice3_sustain, voice3_release } <= dat_i;
                
                else if (local_address == `SID_OFFSET_FILT_L        ) { f_coefficient[7:0] } <= dat_i; // { filter_extra, filter_center[2:0] } <= dat_i;
                else if (local_address == `SID_OFFSET_FILT_H        ) { f_coefficient[15:8] }  <= dat_i; // { filter_center[10:3] }  <= dat_i;
                else if (local_address == `SID_OFFSET_RESFILT       ) { filter_res, filter_ex, filter_v3, filter_v2, filter_v1 } <= dat_i;
                else if (local_address == `SID_OFFSET_MODEVOL       ) { filter_3_off, filter_hp, filter_bp, filter_lp, volume } <= dat_i;
                else if (local_address == `SID_OFFSET_FILT_Q_L      ) { q_coefficient[7:0] } <= dat_i;
                else if (local_address == `SID_OFFSET_FILT_Q_H      ) { q_coefficient[15:8] } <= dat_i;
            end
        end
    end


    always @(*) begin
        if      (local_address == `SID_OFFSET_VOICE1_FREQ_L ) begin  valid_address = 1;  sid_dat_o = { voice1_freq[7:0] }; end
        else if (local_address == `SID_OFFSET_VOICE1_FREQ_H ) begin  valid_address = 1;  sid_dat_o = { voice1_freq[15:8] }; end
        else if (local_address == `SID_OFFSET_VOICE1_PW_L   ) begin  valid_address = 1;  sid_dat_o = { voice1_pw[7:0]    }; end
        else if (local_address == `SID_OFFSET_VOICE1_PW_H   ) begin  valid_address = 1;  sid_dat_o = { voice1_extra, voice1_pw[3:0] }; end
        else if (local_address == `SID_OFFSET_VOICE1_CONTROL) begin  valid_address = 1;  sid_dat_o = { voice1_noise, voice1_pulse, voice1_saw, voice1_tri, voice1_test, voice1_ringmod, voice1_sync, voice1_gate }; end
        else if (local_address == `SID_OFFSET_VOICE1_ATTDEC ) begin  valid_address = 1;  sid_dat_o = { voice1_attack, voice1_decay } ; end
        else if (local_address == `SID_OFFSET_VOICE1_SSTREL ) begin  valid_address = 1;  sid_dat_o = { voice1_sustain, voice1_release }; end

        //else if (local_address == `SID_OFFSET_VOICE2_FREQ_L ) begin  valid_address = 1;  sid_dat_o = { voice2_freq[7:0]  }; end
        //else if (local_address == `SID_OFFSET_VOICE2_FREQ_H ) begin  valid_address = 1;  sid_dat_o = { voice2_freq[15:8] }; end
        //else if (local_address == `SID_OFFSET_VOICE2_PW_L   ) begin  valid_address = 1;  sid_dat_o = { voice2_pw[7:0]    }; end
        //else if (local_address == `SID_OFFSET_VOICE2_PW_H   ) begin  valid_address = 1;  sid_dat_o = { voice2_extra, voice2_pw[3:0] }; end
        //else if (local_address == `SID_OFFSET_VOICE2_CONTROL) begin  valid_address = 1;  sid_dat_o = { voice2_noise, voice2_pulse, voice2_saw, voice2_tri, voice2_test, voice2_ringmod, voice2_sync, voice2_gate }; end
        //else if (local_address == `SID_OFFSET_VOICE2_ATTDEC ) begin  valid_address = 1;  sid_dat_o = { voice2_attack, voice2_decay } ; end
        //else if (local_address == `SID_OFFSET_VOICE2_SSTREL ) begin  valid_address = 1;  sid_dat_o = { voice2_sustain, voice2_release }; end
        //
        //else if (local_address == `SID_OFFSET_VOICE3_FREQ_L ) begin  valid_address = 1;  sid_dat_o = { voice3_freq[7:0]  }; end
        //else if (local_address == `SID_OFFSET_VOICE3_FREQ_H ) begin  valid_address = 1;  sid_dat_o = { voice3_freq[15:8] }; end
        //else if (local_address == `SID_OFFSET_VOICE3_PW_L   ) begin  valid_address = 1;  sid_dat_o = { voice3_pw[7:0]    }; end
        //else if (local_address == `SID_OFFSET_VOICE3_PW_H   ) begin  valid_address = 1;  sid_dat_o = { voice3_extra, voice3_pw[3:0] }; end
        //else if (local_address == `SID_OFFSET_VOICE3_CONTROL) begin  valid_address = 1;  sid_dat_o = { voice3_noise, voice3_pulse, voice3_saw, voice3_tri, voice3_test, voice3_ringmod, voice3_sync, voice3_gate }; end
        //else if (local_address == `SID_OFFSET_VOICE3_ATTDEC ) begin  valid_address = 1;  sid_dat_o = { voice3_attack, voice3_decay } ; end
        //else if (local_address == `SID_OFFSET_VOICE3_SSTREL ) begin  valid_address = 1;  sid_dat_o = { voice3_sustain, voice3_release }; end
        
        else if (local_address == `SID_OFFSET_FILT_L        ) begin  valid_address = 1;  sid_dat_o = { f_coefficient[7:0] }; end //{ filter_extra, filter_center[2:0] }; end
        else if (local_address == `SID_OFFSET_FILT_H        ) begin  valid_address = 1;  sid_dat_o = { f_coefficient[15:8] } ; end //{ filter_center[10:3] } ; end
        else if (local_address == `SID_OFFSET_RESFILT       ) begin  valid_address = 1;  sid_dat_o = { filter_res, filter_ex, filter_v3, filter_v2, filter_v1 }; end
        else if (local_address == `SID_OFFSET_MODEVOL       ) begin  valid_address = 1;  sid_dat_o = { filter_3_off, filter_hp, filter_bp, filter_lp, volume }; end
        else if (local_address == `SID_OFFSET_FILT_Q_L      ) begin  valid_address = 1;  sid_dat_o = { q_coefficient[7:0] }; end
        else if (local_address == `SID_OFFSET_FILT_Q_H      ) begin  valid_address = 1;  sid_dat_o = { q_coefficient[15:8] }; end
        
        else begin 
            valid_address = 0;
            sid_dat_o = 0;
        end
    end




    reg local_clock = 0;
    reg [3:0] local_clock_div = 0;
    always @(posedge clk) begin
        if (local_clock_div) local_clock_div <= local_clock_div-1;
        else begin
            local_clock_div <= 11;
            local_clock     <= !local_clock;
        end
    end
    
    
    localparam COUNT_I = 23;
    reg [COUNT_I-1:0] voice1_address = 0;
    always @(posedge local_clock) begin
        voice1_address <= voice1_address + voice1_freq;
        //lut1_address   <= voice1_address[COUNT_I-1:COUNT_I-8];
    end

    wire voice1_update = voice1_address[COUNT_I-6];
    reg  voice1_last_update = 0;
    always @(posedge local_clock) begin
        voice1_last_update <= voice1_update;
    end
    wire voice1_update_pulse = voice1_update & (voice1_last_update ^ voice1_update);

    reg [11:0] voice1_pw_reg;
    always @(posedge local_clock) begin
        if (voice1_update_pulse) begin
            voice1_pw_reg <= voice1_pw;
        end
    end
    
    localparam PRBS_SIZE = 24;
    reg signed [PRBS_SIZE-1:0] prbs;
    always @(posedge local_clock or posedge rst) begin
        if (rst) prbs <= 42; // totally random seed value chosen by fair dice role, guaranteed to be random!
        else if (voice1_update_pulse) prbs <= { prbs[PRBS_SIZE-2:0], prbs[PRBS_SIZE-1] ^ prbs[PRBS_SIZE-2] };
    end
        
    wire [7:0] voice1_pos              = voice1_address[COUNT_I-1:COUNT_I-8];
    
    wire signed [7:0] voice1_saw_out   = voice1_pos;
    wire signed [7:0] voice1_tri_out   = {(voice1_pos[7] ? 127-voice1_pos[6:0] : voice1_pos[6:0]), 1'b0};
    wire signed [7:0] voice1_pulse_out = (voice1_pos > voice1_pw_reg[11:4]) ? 0 : 255;
    wire signed [7:0] voice1_noise_out = prbs[PRBS_SIZE-1:PRBS_SIZE-8];
    
    wire signed [7:0] voice1_wave_out  = (|{voice1_saw,voice1_tri,voice1_pulse,voice1_noise} ? // if any waveform is used
                                          ((voice1_saw   ? voice1_saw_out   : 255) &           // and them all together
                                           (voice1_tri   ? voice1_tri_out   : 255) &
                                           (voice1_pulse ? voice1_pulse_out : 255) &    
                                           (voice1_noise ? voice1_noise_out : 255))  : 127);   // otherwise output mid-level

    localparam AVERAGE_LENGTH = 24;
    reg [AVERAGE_LENGTH-1:0] voice1_average = 1<<(AVERAGE_LENGTH-2);
    always @(posedge local_clock) begin
        voice1_average <= voice1_average - voice1_average[AVERAGE_LENGTH-1:AVERAGE_LENGTH-8] + voice1_wave_out;
    end
    

    wire signed [8:0] voice1_wave  = $signed({1'b0, voice1_wave_out}) - $signed({1'b0, voice1_average[AVERAGE_LENGTH-1:AVERAGE_LENGTH-8]});
    
    //--------------------------------------------------------------------------
    localparam ENV_STATE_RELEASE    = 4'b0001;
    localparam ENV_STATE_ATTACK     = 4'b0010;
    localparam ENV_STATE_DECAY      = 4'b0100;
    localparam ENV_STATE_SUSTAIN    = 4'b1000;

    localparam ENV_SIZE      = 6;
    
    reg env_clock           = 0;
    reg [3:0] env_clock_div = 0;
    always @(posedge local_clock) begin
        if (env_clock_div) env_clock_div <= env_clock_div-1;
        else begin
            env_clock_div <= 7;
            env_clock     <= !env_clock;
        end
    end
    
    
    //--------------------------------------------------------------------------
    // Voice 1 envolope
    reg [13:0]          voice1_counter;
    reg [13:0]          next_voice1_counter;
    reg [ENV_SIZE-1:0]  voice1_volume;
    reg [ENV_SIZE-1:0] next_voice1_volume;
    reg [3:0]           voice1_env_state;
    reg [3:0]           next_voice1_env_state;
    always @(posedge env_clock) begin
        if (rst) begin
            voice1_env_state <= ENV_STATE_RELEASE;
            voice1_counter   <= 0;
            voice1_volume    <= 0;
        end
        else begin
            voice1_env_state <= next_voice1_env_state;
            voice1_counter   <= next_voice1_counter;
            voice1_volume    <= next_voice1_volume;
        end
    end
    wire [4:0] voice1_delay_lookup_value;
    assign voice1_delay_lookup_value = (voice1_env_state == ENV_STATE_ATTACK  ? { 1'b0, voice1_attack } :
                                        voice1_env_state == ENV_STATE_DECAY   ? { 1'b1, voice1_decay } :
                                        voice1_env_state == ENV_STATE_SUSTAIN ? 0 :
                                        /*                  ENV_STATE_RELEASE*/ { 1'b1, voice1_release });
    always @(*) begin
        next_voice1_env_state = voice1_env_state;
        next_voice1_counter   = voice1_counter;
        next_voice1_volume    = voice1_volume;
        
        if (voice1_counter > 0) next_voice1_counter = voice1_counter - 1;
        else begin
            // go through if the volume should increase, decrease or stay the same
            if (voice1_env_state == ENV_STATE_ATTACK) begin
                if (voice1_volume < ((1<<ENV_SIZE)-1)) next_voice1_volume = voice1_volume + 1;
            end
            else if (voice1_env_state == ENV_STATE_DECAY) begin
                if (voice1_volume[ENV_SIZE-1:ENV_SIZE-4] > voice1_sustain) next_voice1_volume = voice1_volume - 1;
            end
            else if (voice1_env_state == ENV_STATE_SUSTAIN) begin
            end
            else /* RELEASE */ begin
                if (voice1_volume > 0) next_voice1_volume = voice1_volume - 1;
            end

            // look up what the next timer period is
            case(voice1_delay_lookup_value)
                5'h00 : next_voice1_counter = 2     /2; // Attack
                5'h01 : next_voice1_counter = 8     /2;
                5'h02 : next_voice1_counter = 16    /2;
                5'h03 : next_voice1_counter = 24    /2;
                5'h04 : next_voice1_counter = 38    /2;
                5'h05 : next_voice1_counter = 56    /2;
                5'h06 : next_voice1_counter = 68    /2;
                5'h07 : next_voice1_counter = 80    /2;
                5'h08 : next_voice1_counter = 100   /2;
                5'h09 : next_voice1_counter = 250   /2;
                5'h0A : next_voice1_counter = 500   /2;
                5'h0B : next_voice1_counter = 800   /2;
                5'h0C : next_voice1_counter = 1000  /2;
                5'h0D : next_voice1_counter = 3000  /2;
                5'h0E : next_voice1_counter = 5000  /2;
                5'h0F : next_voice1_counter = 8000  /2;
                5'h10 : next_voice1_counter = 6     /2; // Release or Decay
                5'h11 : next_voice1_counter = 24    /2;
                5'h12 : next_voice1_counter = 48    /2;
                5'h13 : next_voice1_counter = 72    /2;
                5'h14 : next_voice1_counter = 114   /2;
                5'h15 : next_voice1_counter = 168   /2;
                5'h16 : next_voice1_counter = 204   /2;
                5'h17 : next_voice1_counter = 240   /2;
                5'h18 : next_voice1_counter = 300   /2;
                5'h19 : next_voice1_counter = 750   /2;
                5'h1A : next_voice1_counter = 1500  /2;
                5'h1B : next_voice1_counter = 2400  /2;
                5'h1C : next_voice1_counter = 3000  /2;
                5'h1D : next_voice1_counter = 9000  /2;
                5'h1E : next_voice1_counter = 15000 /2;
                5'h1F : next_voice1_counter = 24000 /2;
            endcase
        end

        // handle change of state
        if (voice1_gate) begin
            if      (voice1_env_state == ENV_STATE_RELEASE) next_voice1_env_state = ENV_STATE_ATTACK;
            else if (voice1_env_state == ENV_STATE_ATTACK) begin
                if (voice1_volume == ((1<<ENV_SIZE)-1)) next_voice1_env_state = ENV_STATE_DECAY;
            end
            else if (voice1_env_state == ENV_STATE_DECAY) begin
                if (voice1_volume[ENV_SIZE-1:ENV_SIZE-4] <= voice1_sustain) next_voice1_env_state = ENV_STATE_SUSTAIN;
            end
            else if (voice1_env_state == ENV_STATE_SUSTAIN) begin
                if (voice1_volume[ENV_SIZE-1:ENV_SIZE-4] > voice1_sustain) next_voice1_env_state = ENV_STATE_DECAY;
            end
        end
        else begin
            if (voice1_env_state != ENV_STATE_RELEASE) begin
                next_voice1_env_state = ENV_STATE_RELEASE;
            end
        end
    end
    
    reg signed [ENV_SIZE+8:0] voice1_amplified = 0;
    wire signed [8:0] voice1_scaled = voice1_amplified[ENV_SIZE+8:ENV_SIZE];
    always @(posedge local_clock or posedge rst) begin
        if (rst) begin
            voice1_amplified <= 0;
        end
        else begin
            voice1_amplified <= voice1_wave * $signed({1'b0, voice1_volume});
        end
    end



    reg signed [12:0] audio_amplified = 0;
    wire signed [7:0] audio_scaled = audio_amplified[12:5];
    always @(posedge local_clock or posedge rst) begin
        if (rst) begin
            audio_amplified <= 0;
        end
        else begin
            audio_amplified <= voice1_scaled * $signed({1'b0, volume});
        end
    end

    wire signed [11:0] audio_filtered;

    reg [5:0]          filter_divider = 0;
    reg                filter_pulse;
    always @(posedge env_clock) begin
        if (filter_divider) begin
            filter_divider <= filter_divider - 1;
            filter_pulse   <= 0;
        end
        else begin
            filter_divider <= 20;
            filter_pulse   <= 1;
        end
    end
                                   
    filter_bank #(
        .AUDIO_BDEPTH     ( 12 ),
        .FILTER_COUNT     ( 4 ),
        .BASE_ADDRESS     ( FILTER_BASE_ADDRESS )
    ) filter_bank_inst (
        .rst_i ( rst ),
        .clk_i ( clk ),
        
        .adr_i ( adr_i ),
        .dat_i ( dat_i ),
        .dat_o ( filter_dat_o ),
        .we_i  ( we_i ),
        .sel_i ( sel_i ),
        .stb_i ( stb_i ),
        .cyc_i ( cyc_i ),
        .ack_o ( filter_ack_o ),
        .cti_i ( cti_i ),
        
        .audio_in ( audio_amplified[12:1] ),
        .valid_in ( filter_pulse ),
        
        .audio_out ( audio_filtered ),
        .valid_out (  )
    );
    
    
    wire       audio_sign = audio_filtered < 0;
    wire [7:0] audio_abs = (audio_sign ? -audio_filtered[11:4] : audio_filtered[11:4]);

    
    reg [15:0] error_accumulator = 0;
    reg [15:0] next_error_accumulator = 0;
    reg       next_out;
    reg       out;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            error_accumulator <= 0;
            out               <= 0;
        end
        else begin
            error_accumulator <= next_error_accumulator;
            out               <= next_out;
        end
    end

    always @(*) begin
        if (error_accumulator + audio_abs >= 16'h80) begin
            next_error_accumulator = error_accumulator + audio_abs - 16'h80;
            next_out               = 1;
        end
        else begin
            next_error_accumulator = error_accumulator + audio_abs;
            next_out               = 0;
        end
    end

    
    assign audio_p = (audio_sign ? 0 : out);
    assign audio_n = (audio_sign ? out : 0);

endmodule
