module top (
    input  pin_clk,

    inout  pin_usbp,
    inout  pin_usbn,
    output pin_pu,

    output pin_led,

    //input  pin_29_miso,
    //output pin_30_cs,
    //output pin_31_mosi,
    //output pin_32_sck,

    output pin_1,
    output pin_2,
             
    output pin_14,
    output pin_15,
    output pin_16,
    output pin_17,
    output pin_18,
    output pin_19,
    output pin_20,
    output pin_21,
    output pin_22
    );

    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////
    ////////
    //////// generate 48 mhz clock
    ////////
    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////
    wire clk_48mhz;
    wire clk_locked;
    SB_PLL40_CORE #(
        .DIVR(4'b0000),
        .DIVF(7'b0101111),
        .DIVQ(3'b100),
        .FILTER_RANGE(3'b001),
        .FEEDBACK_PATH("SIMPLE"),
        .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
        .FDA_FEEDBACK(4'b0000),
        .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
        .FDA_RELATIVE(4'b0000),
        .SHIFTREG_DIV_MODE(2'b00),
        .PLLOUT_SELECT("GENCLK"),
        .ENABLE_ICEGATE(1'b0)
    ) usb_pll_inst (
        .REFERENCECLK(pin_clk),
        .PLLOUTCORE(clk_48mhz),
        .PLLOUTGLOBAL(),
        .EXTFEEDBACK(),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .LATCHINPUTVALUE(),
        .LOCK(clk_locked),
        .SDI(),
        .SDO(),
        .SCLK()
    );

    

    
    localparam TEXT_LEN = 13;

    assign pin_led = 1;

    
    // Generate reset signal
    // Generate reset signal
    reg [5:0] reset_cnt = 0;
    wire reset = ~reset_cnt[5];
    always @(posedge clk_48mhz)
        if ( clk_locked )
            reset_cnt <= reset_cnt + reset;

    reg        clk_24mhz = 0;
    always @(posedge clk_48mhz) clk_24mhz <= ~clk_24mhz;

    reg        clk_12mhz = 0;
    always @(posedge clk_24mhz) clk_12mhz <= ~clk_12mhz;

    wire clk;
    wire rst;
    assign clk = clk_12mhz;
    assign rst = reset;
    
    //---------------------------------------------------------------
    // Wishbone arbitration connections
    reg [7:0] data_in;
    wire      ack;
    
    reg [7:0] led_data;
    reg       led_ack;
    
    wire [7:0] mem_data;
    wire       mem_ack;
    
    wire [7:0] sid1_data;
    wire       sid1_ack;

    assign ack = |{led_ack, sid1_ack, mem_ack};
    
    always @(*) begin
        if      (led_ack)  begin  data_in = led_data;  end
        else if (mem_ack)  begin  data_in = mem_data;  end
        else if (sid1_ack) begin  data_in = sid1_data; end
        else               begin  data_in = 8'd0;      end
    end
    
    // the blocking mechanism is pretty simple. If any device is
    // currently using the bus, block everything else
    wire        cycle;
    reg [15:0]  adr;
    reg [7:0]   data;
    reg         we;
    reg [0:0]   sel;
    reg         stb;
    reg [2:0]   cti;
    
    wire        rs232_cycle;
    wire        rs232_cycle_in;
    wire [15:0] rs232_adr;
    wire [7:0]  rs232_data;
    wire        rs232_we;
    wire        rs232_sel;
    wire        rs232_stb;
    wire [2:0]  rs232_cti;
    
    wire        synth_cycle;
    wire        synth_cycle_in;
    wire [15:0] synth_adr;
    wire [7:0]  synth_data;
    wire        synth_we;
    wire        synth_sel;
    wire        synth_stb;
    wire [2:0]  synth_cti;
    
    //wire        test_cycle;
    //wire        test_cycle_in;
    //wire [15:0] test_adr;
    //wire [7:0]  test_data;
    //wire        test_we;
    //wire        test_sel;
    //wire        test_stb;
    //wire [2:0]  test_cti;

    assign rs232_cycle_in = synth_cycle;// | test_cycle;
    assign synth_cycle_in = rs232_cycle;// | test_cycle;
    //assign test_cycle_in  = rs232_cycle | synth_cycle;

    assign cycle = rs232_cycle | synth_cycle;// | test_cycle;
    
    always @(*) begin
        if      (rs232_cycle) begin  adr = rs232_adr;  data = rs232_data;  we = rs232_we;  sel = rs232_sel;  stb = rs232_stb;  cti = rs232_cti;  end
        else if (synth_cycle) begin  adr = synth_adr;  data = synth_data;  we = synth_we;  sel = synth_sel;  stb = synth_stb;  cti = synth_cti;  end
        //else if (test_cycle)  begin  adr =  test_adr;  data =  test_data;  we =  test_we;  sel =  test_sel;  stb =  test_stb;  cti =  test_cti;  end
        else                  begin  adr =     16'd0;  data =       8'd0;  we =        0;  sel =         0;  stb =         0;  cti =      3'd0;  end
    end

    
    //---------------------------------------------------------------
    assign synth_cycle = 0;
    assign synth_adr   = 0;
    assign synth_data  = 0;
    assign synth_we    = 0;
    assign synth_sel   = 0;
    assign synth_stb   = 0;
    assign synth_cti   = 0;
    
    //assign test_cycle = 0;
    //assign test_adr   = 0;
    //assign test_data  = 0;
    //assign test_we    = 0;
    //assign test_sel   = 0;
    //assign test_stb   = 0;
    //assign test_cti   = 0;
    
    
    wishbone_memory #(
        .ADDRESS_WIDTH (16),
        .DATA_WIDTH    (8),
        .DATA_BYTES    (1),
        .BASE_ADDRESS  (16'h0200),
        .MEMORY_SIZE   (1024)
    ) memory_inst (
        .rst_i ( rst ),
        .clk_i ( clk ),
        .adr_i ( adr ),
        .dat_i ( data ),
        .dat_o ( mem_data ),
        .we_i  ( we ),
        .sel_i ( sel ),
        .stb_i ( stb ),
        .cyc_i ( cycle ),
        .ack_o ( mem_ack ),
        .cti_i ( cti )
    );
    

    sid_chip #(
        .ADDRESS_WIDTH (16),
        .DATA_WIDTH    (8),
        .DATA_BYTES    (1),
        .BASE_ADDRESS  (16'h0100),
    ) sid1_inst (
        .rst_i ( rst ),
        .clk_i ( clk ),
        .adr_i ( adr ),
        .dat_i ( data ),
        .dat_o ( sid1_data ),
        .we_i  ( we ),
        .sel_i ( sel ),
        .stb_i ( stb ),
        .cyc_i ( cycle ),
        .ack_o ( sid1_ack ),
        .cti_i ( cti ),

        .audio_p ( pin_1 ),
        .audio_n ( pin_2 )
    );

    reg [4:0]                leds;
    reg [4:0]                next_leds;
    // simple LED module to check the wishbone interface
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            leds <= 5'b01010;
        end
        else begin
            leds <= next_leds;
        end
    end
    always @(*) begin
        led_data  = 8'd0;
        next_leds = leds;
        led_ack   = 1'd0;
        
        if (cycle && adr == 16'd0) begin
            led_data = { 3'd0, leds };
            led_ack = 1'b1;
            if (we) begin
                next_leds = data[4:0];
            end
        end
    end

    //---------------------------------------------------------------
    // uart and protocol
    
    

    wire [7:0] uart_in_data;
    wire       uart_in_valid;
    wire       uart_in_ready;
    wire [7:0] uart_out_data;
    wire       uart_out_valid;
    wire       uart_out_ready;


    protocol #(
        .ADDRESS_WIDTH (16),
        .DATA_WIDTH    (8 ),
        .DATA_BYTES    (1 ),
        .MAX_WAIT      (8 ),
        .MAX_PAYLOAD   (4 )
    ) protocol_inst (
        // Wishbone interface
        .rst_i     ( rst ),
        .clk_i     ( clk ),
        .clk_48mhz ( clk_48mhz ),

        .adr_o ( rs232_adr      ),
        .dat_i ( data_in        ),
        .dat_o ( rs232_data     ),
        .we_o  ( rs232_we       ),
        .sel_o ( rs232_sel      ),
        .stb_o ( rs232_stb      ),
        .cyc_i ( rs232_cycle_in ),
        .cyc_o ( rs232_cycle    ),
        .ack_i ( ack            ),
        .cti_o ( rs232_cti      ),
        
        // Uart interfaces
        .rx_byte       ( uart_out_data ),
        .rx_byte_valid ( uart_out_valid ),
        .rx_ready      ( uart_out_ready ),

        .tx_byte       ( uart_in_data ),
        .tx_byte_valid ( uart_in_valid ),
        .tx_ready      ( uart_in_ready ), 
    );

    
    // usb uart
    usb_uart_core uart (
        .clk_48mhz     ( clk_48mhz      ),
        .reset         ( reset          ),
     
        .usb_p_tx      ( usb_p_tx       ),
        .usb_n_tx      ( usb_n_tx       ),
        .usb_p_rx      ( usb_p_rx       ),
        .usb_n_rx      ( usb_n_rx       ),
        .usb_tx_en     ( usb_tx_en      ),
     
        // uart pipeline in (out of the device, into the host)
        .uart_in_data  ( uart_in_data   ),
        .uart_in_valid ( uart_in_valid  ),
        .uart_in_ready ( uart_in_ready  ),
     
        // uart pipeline out (into the device, out of the host)
        .uart_out_data ( uart_out_data  ),
        .uart_out_valid( uart_out_valid ),
        .uart_out_ready( uart_out_ready ),
     
        .debug(  )
    );
    assign pin_14 = uart_in_data[0];
    assign pin_15 = uart_in_valid;
    assign pin_16 = uart_in_ready;
    assign pin_17 = uart_out_data[0];
    assign pin_18 = uart_out_valid;
    assign pin_19 = uart_out_ready;
    
    wire usb_p_tx;
    wire usb_n_tx;
    wire usb_p_rx;
    wire usb_n_rx;
    wire usb_tx_en;
    wire usb_p_in;
    wire usb_n_in;

    assign pin_pu = 1'b1;
    
    assign usb_p_rx = usb_tx_en ? 1'b1 : usb_p_in;
    assign usb_n_rx = usb_tx_en ? 1'b0 : usb_n_in;
    
    SB_IO #(
        .PIN_TYPE(6'b 1010_01), // PIN_OUTPUT_TRISTATE - PIN_INPUT
        .PULLUP(1'b 0)
    ) 
    iobuf_usbp 
    (
        .PACKAGE_PIN(pin_usbp),
        .OUTPUT_ENABLE(usb_tx_en),
        .D_OUT_0(usb_p_tx),
        .D_IN_0(usb_p_in)
    );

    SB_IO #(
        .PIN_TYPE(6'b 1010_01), // PIN_OUTPUT_TRISTATE - PIN_INPUT
        .PULLUP(1'b 0)
    ) 
    iobuf_usbn 
    (
        .PACKAGE_PIN(pin_usbn),
        .OUTPUT_ENABLE(usb_tx_en),
        .D_OUT_0(usb_n_tx),
        .D_IN_0(usb_n_in)
    );

endmodule
