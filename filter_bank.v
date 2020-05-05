`include "globals.v"
`define FILTER_OFFSET_CONTROL     (8'h00)
`define FILTER_OFFSET_GAINS_START (8'h02)
`define FILTER_OFFSET_COEF_START  (8'h20)

module filter_bank #(
    parameter AUDIO_BDEPTH  = 12,
    parameter FILTER_COUNT  = 4,
    parameter ADDRESS_WIDTH = 16,
    parameter DATA_WIDTH    = 8,
    parameter DATA_BYTES    = (DATA_WIDTH / 8),
    parameter BASE_ADDRESS  = 16'h0000
)  (
    // Wishbone interface
    input wire                      rst_i,
    input wire                      clk_i,

    input wire [ADDRESS_WIDTH-1:0]  adr_i,
    input wire [DATA_WIDTH-1:0]     dat_i,
    output reg [DATA_WIDTH-1:0]     dat_o,
    input wire                      we_i,
    input wire [DATA_BYTES-1:0]     sel_i,
    input wire                      stb_i,
    input wire                      cyc_i,
    output reg                      ack_o,
    input wire [2:0]                cti_i,

    input wire signed [AUDIO_BDEPTH-1:0] audio_in,
    input wire                           valid_in,

    output reg signed [AUDIO_BDEPTH-1:0] audio_out,
    output reg                           valid_out
    );

    wire clk = clk_i;
    wire rst = rst_i;

    reg [AUDIO_BDEPTH-1:0] latched_audio_in;
    
    localparam FILTER_MEM_LENGTH = FILTER_COUNT * 6;
    localparam FILTER_MEM_SIZE = (FILTER_MEM_LENGTH < 16 ? 4 :
                                  FILTER_MEM_LENGTH < 32 ? 5 :
                                  FILTER_MEM_LENGTH < 64 ? 6 :
                                  FILTER_MEM_LENGTH < 128 ? 7 :
                                  FILTER_MEM_LENGTH < 256 ? 8 :
                                  FILTER_MEM_LENGTH < 512 ? 9 :
                                  FILTER_MEM_LENGTH < 1024 ? 10 :
                                  FILTER_MEM_LENGTH < 2048 ? 11 : 12);
    
    reg filter_enabled;

    wire [FILTER_MEM_SIZE:0] wb_mem_address; // note - one bit larger due to 8/16 conversion
    wire [7:0]               wb_write_value;
    reg [7:0]                wb_read_value;
    wire                     wb_write;

    reg signed [15:0]        filter_gains [0:FILTER_COUNT-1];
    integer init_filter_gains_i;
    initial begin
        for (init_filter_gains_i = 0; init_filter_gains_i < FILTER_COUNT; init_filter_gains_i = init_filter_gains_i+1) begin
            filter_gains[init_filter_gains_i] = 16'd0;
        end
    end
    
    //===========================================================================================
    // Wishbone slave
    reg        valid_address;
    
    wire       address_in_range;
    wire [7:0] local_address;
    assign address_in_range = (adr_i & 16'hFF00) == BASE_ADDRESS;
    assign local_address = address_in_range ? adr_i[7:0] : 8'hFF;
    wire       masked_cyc              = (address_in_range & cyc_i);

    wire       wb_mem_address_in_range;
    assign wb_mem_address_in_range = (local_address >= `FILTER_OFFSET_COEF_START && local_address < `FILTER_OFFSET_COEF_START + (FILTER_COUNT * 12));
    assign wb_mem_address = wb_mem_address_in_range ? local_address - `FILTER_OFFSET_COEF_START : 0;
    assign wb_write       = wb_mem_address_in_range ? masked_cyc & we_i : 0;
    assign wb_write_value = wb_mem_address_in_range ? dat_i : 0;

    
    // wb_write = cyc_i & valid_address & we_i
    always @(posedge clk_i) begin
        ack_o <= cyc_i & valid_address;
    end

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            filter_enabled <= 1;
        end
        else begin
            if (masked_cyc & we_i) begin
                if (local_address == `FILTER_OFFSET_CONTROL    ) { filter_enabled } <= dat_i[0];
                else if (local_address == `FILTER_OFFSET_GAINS_START + 0) filter_gains[0][ 7:0] <= dat_i;
                else if (local_address == `FILTER_OFFSET_GAINS_START + 1) filter_gains[0][15:8] <= dat_i;
                else if (local_address == `FILTER_OFFSET_GAINS_START + 2) filter_gains[1][ 7:0] <= dat_i;
                else if (local_address == `FILTER_OFFSET_GAINS_START + 3) filter_gains[1][15:8] <= dat_i;
                else if (local_address == `FILTER_OFFSET_GAINS_START + 4) filter_gains[2][ 7:0] <= dat_i;
                else if (local_address == `FILTER_OFFSET_GAINS_START + 5) filter_gains[2][15:8] <= dat_i;
                else if (local_address == `FILTER_OFFSET_GAINS_START + 6) filter_gains[3][ 7:0] <= dat_i;
                else if (local_address == `FILTER_OFFSET_GAINS_START + 7) filter_gains[3][15:8] <= dat_i;

                // note that wb_mem_address writes are handled above
            end
        end
    end

    integer wb_read_i;
    always @(*) begin
        if (~masked_cyc)                                          begin valid_address = 0; dat_o = 0; end
        else if (local_address == `FILTER_OFFSET_CONTROL)         begin valid_address = 1; dat_o = { 7'd0, filter_enabled }; end
        else if (local_address == `FILTER_OFFSET_GAINS_START + 0) begin valid_address = 1; dat_o = filter_gains[0][ 7:0]; end
        else if (local_address == `FILTER_OFFSET_GAINS_START + 1) begin valid_address = 1; dat_o = filter_gains[0][15:8]; end
        else if (local_address == `FILTER_OFFSET_GAINS_START + 2) begin valid_address = 1; dat_o = filter_gains[1][ 7:0]; end
        else if (local_address == `FILTER_OFFSET_GAINS_START + 3) begin valid_address = 1; dat_o = filter_gains[1][15:8]; end
        else if (local_address == `FILTER_OFFSET_GAINS_START + 4) begin valid_address = 1; dat_o = filter_gains[2][ 7:0]; end
        else if (local_address == `FILTER_OFFSET_GAINS_START + 5) begin valid_address = 1; dat_o = filter_gains[2][15:8]; end
        else if (local_address == `FILTER_OFFSET_GAINS_START + 6) begin valid_address = 1; dat_o = filter_gains[3][ 7:0]; end
        else if (local_address == `FILTER_OFFSET_GAINS_START + 7) begin valid_address = 1; dat_o = filter_gains[3][15:8]; end
        else if (wb_mem_address_in_range)                         begin valid_address = 1; dat_o = wb_read_value; end
        else begin 
            valid_address = 0;
            dat_o         = 0;
        end
    end
    

    //===========================================================================================
    // filter bank memory

    reg [FILTER_MEM_SIZE-1:0] current_address  = 0;
    reg [FILTER_MEM_SIZE-1:0] next_address     = 0;
    
    reg [FILTER_MEM_SIZE-1:0] filter_addr      = 0;
    reg [15:0]                filter_write_buf = 0;
    reg [15:0]                filter_out       = 0;
    reg                       filter_write     = 0;
    always @(*) begin
        if (!filter_enabled) begin
            filter_addr = wb_mem_address[FILTER_MEM_SIZE:1];
            if (wb_mem_address[0]) begin // upper byte
                filter_write_buf[7:0]  = filter_out[7:0];
                filter_write_buf[15:8] = wb_write_value;
                wb_read_value          = filter_out[15:8];
            end
            else begin // lower byte
                filter_write_buf[7:0]  = wb_write_value;
                filter_write_buf[15:8] = filter_out[15:8];
                wb_read_value          = filter_out[7:0];
            end
            filter_write = wb_write;
        end
        else begin
            filter_write     = 0;
            filter_addr      = next_address;
            filter_write_buf = 0;
            wb_read_value    = 0;
        end
    end


    //============= Memory Unit =====================
    reg [15:0] filter_bank_mem [(1<<FILTER_MEM_SIZE)-1:0];

    initial begin
        $readmemh("./filter_bank_mem.txt", filter_bank_mem);
    end
    
    always @(posedge clk) // Write memory.
    begin
        if (filter_write)
            filter_bank_mem[filter_addr] <= filter_write_buf;
        filter_out <= filter_bank_mem[filter_addr];
    end
    //============= Memory Unit =====================

    
    //===========================================================================================
    // filter sequencer

    localparam FILTER_SEQUENCE_LENGTH = FILTER_COUNT * 8;
    localparam FILTER_SEQUENCE_SIZE = (FILTER_SEQUENCE_LENGTH < 16 ? 4 :
                                       FILTER_SEQUENCE_LENGTH < 32 ? 5 :
                                       FILTER_SEQUENCE_LENGTH < 64 ? 6 :
                                       FILTER_SEQUENCE_LENGTH < 128 ? 7 :
                                       FILTER_SEQUENCE_LENGTH < 256 ? 8 :
                                       FILTER_SEQUENCE_LENGTH < 512 ? 9 :
                                       FILTER_SEQUENCE_LENGTH < 1024 ? 10 :
                                       FILTER_SEQUENCE_LENGTH < 2048 ? 11 : 12);

    
    reg signed [15:0]              gain;
    reg signed [15:0]              coef_k;
    reg signed [15:0]              coef_a1;
    reg signed [15:0]              coef_a2;
    reg signed [15:0]              coef_b0;
    reg signed [15:0]              coef_b1;
    reg signed [15:0]              coef_b2;
    reg                            filter_valid_in;
    wire signed [AUDIO_BDEPTH-1:0] filter_audio_out;
    wire                           filter_valid_out;
    
    reg [FILTER_SEQUENCE_SIZE-1:0] current_state;
    reg [FILTER_SEQUENCE_SIZE-1:0] next_state;
    
    reg signed [AUDIO_BDEPTH-1:0]  next_audio_out;
    reg                            next_valid_out;
    
    wire signed [AUDIO_BDEPTH-1:0] audio_accum_in;
    reg signed [AUDIO_BDEPTH-1:0]  audio_accum_reg;
    wire signed [AUDIO_BDEPTH-1:0] audio_accum_out;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_address <= 0;
            current_state   <= 0;
            coef_k          <= 0;
            coef_a1         <= 0;
            coef_a2         <= 0;
            coef_b0         <= 0;
            coef_b1         <= 0;
            coef_b2         <= 0;
            valid_out       <= 0;
            audio_out       <= 0;
        end
        else begin
            current_address <= next_address;
            current_state   <= next_state;
            valid_out       <= next_valid_out;
            audio_out       <= next_audio_out;

            if (current_state == 0) begin
                latched_audio_in <= audio_in;
            end
            
            // latch in coefficients
            case(current_state[2:0])
            3'h0: begin coef_k  <= filter_out; end
            3'h1: begin coef_a1 <= filter_out; end
            3'h2: begin coef_a2 <= filter_out; end
            3'h3: begin coef_b0 <= filter_out; end
            3'h4: begin coef_b1 <= filter_out; end
            3'h5: begin coef_b2 <= filter_out; end
            3'h6: begin end
            3'h7: begin end
            endcase
        end
    end

    always @(*) begin
        filter_valid_in = 0;
        next_valid_out  = 0;
        next_audio_out  = audio_out;
        next_address    = current_address;

        // if we're waiting for the first event
        if (current_state == 0) begin
            if (valid_in) next_state = current_state + 1;
            else          next_state = current_state;
        end
        else begin
            if (current_state >= FILTER_SEQUENCE_LENGTH) begin
                next_state     = 0;
                next_valid_out = 1;
                next_audio_out = audio_accum_out;
            end
            else begin
                next_state = current_state + 1;
            end
            
        end
        
        case(current_state[2:0])
        3'h0: begin
            if (current_state == 0) begin
                if (valid_in) next_address = 1;
                else          next_address = 0;
            end
            else begin
                next_address = current_address + 1;
            end
        end
        3'h1: begin next_address = current_address + 1; filter_valid_in = 1; end
        3'h2: begin next_address = current_address + 1; end
        3'h3: begin next_address = current_address + 1; end
        3'h4: begin next_address = current_address + 1; end
        3'h5: begin next_address = current_address + 1; end
        3'h6: begin end
        3'h7: begin end
        endcase

        // handle disabled (bipassed) case
        if (!filter_enabled) begin
            next_address   = 0;
            next_state     = 0;
            next_valid_out = valid_in;
            next_audio_out = audio_in;
        end
    end

    //===========================================================================================
    // filter components
    
    filter_biquad_section #(
        .AUDIO_BDEPTH ( AUDIO_BDEPTH ),
        .COEF_BDEPTH  ( 16 )
    ) filter_inst (
        .clk      ( clk ),

        .audio_in ( latched_audio_in ),
        .valid_in ( filter_valid_in ),

        .k        ( coef_k  ),
        .a1       ( coef_a1 ),
        .a2       ( coef_a2 ),
        .b0       ( coef_b0 ),
        .b1       ( coef_b1 ),
        .b2       ( coef_b2 ),

        .audio_out( filter_audio_out ),
        .valid_out( filter_valid_out ),

        .sat_gain (  ),
        .sat_accum(  )
    );

    integer gainsel_i;
    always @(posedge clk) begin
        gain <= 0;
        for (gainsel_i = 0; gainsel_i < FILTER_COUNT; gainsel_i = gainsel_i + 1) begin
            if (current_state[FILTER_SEQUENCE_SIZE-1:3] == gainsel_i) gain <= filter_gains[gainsel_i];
        end
    end

    reg [AUDIO_BDEPTH-1:0] filter_audio_out_1;
    reg                    filter_valid_out_1;
    always @(posedge clk) begin
        filter_audio_out_1 <= filter_audio_out;
        filter_valid_out_1 <= filter_valid_out;
    end
    
    saturation_signed_multiply #(
        .AS    ( AUDIO_BDEPTH ),
        .BS    ( 16           ),
        .OFFSET( 16-1         ),
        .OUTS  ( AUDIO_BDEPTH )
    ) mult_inst (
        .a  ( filter_audio_out_1 ),
        .b  ( gain ),
        .out( audio_accum_in ),
        .sat( )
    );
    
    saturated_signed_adder #(
        .AS  ( AUDIO_BDEPTH ),
        .BS  ( AUDIO_BDEPTH ),
        .OUTS( AUDIO_BDEPTH )
    ) add_inst_1 
       (
        .a   ( audio_accum_in  ),
        .b   ( audio_accum_reg ),
        .out ( audio_accum_out ),
        .sat ( )
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin // reset on initial start as well
            audio_accum_reg <= 0;
        end
        else begin
            if (current_state == 1) audio_accum_reg <= 0;
            else if (filter_valid_out_1) audio_accum_reg <= audio_accum_out;
        end
    end
    
        
endmodule    

    
