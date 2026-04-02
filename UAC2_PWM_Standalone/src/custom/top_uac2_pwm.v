module top_uac2_pwm
(
    input          CLK_IN,

    inout          USB_DXP_IO,
    inout          USB_DXN_IO,
    input          USB_RXDP_I,
    input          USB_RXDN_I,
    output         USB_PULLUP_EN_O,
    inout          USB_TERM_DP_IO,
    inout          USB_TERM_DN_IO,

    output         AUDIO_PWM_O
);

localparam  CLOCK_SOURCE_ID          = 8'h05;
localparam  AUDIO_CONTROL_UNIT_ID    = 8'h03;
localparam  CLOCK_SELECTOR_ID        = 8'h28;
localparam  AUDIO_IT_ENDPOINT        = 8'h82;
localparam  AUDIO_OT_ENDPOINT        = 8'h01;
localparam  AUDIO_IT_FB_ENDPOINT     = 8'h81;
localparam  DOP_PACKET_CODE0         = 8'h05;
localparam  DOP_PACKET_CODE1         = 8'hFA;

wire        mute;
wire [15:0] ch0_volume;
wire [15:0] ch1_volume;
wire [15:0] ch2_volume;
wire [31:0] sample_rate;
wire [7:0]  tx_data_bits;
wire [7:0]  rx_data_bits;

wire [1:0]  phy_xcvrselect;
wire        phy_termselect;
wire [1:0]  phy_opmode;
wire [1:0]  phy_linestate;
wire        phy_txvalid;
wire        phy_txready;
wire        phy_rxvalid;
wire        phy_rxactive;
wire        phy_rxerror;
wire [7:0]  phy_datain;
wire [7:0]  phy_dataout;
wire        phy_clkout;
wire        phy_reset;

wire [15:0] descrom_raddr;
wire [7:0]  desc_index;
wire [7:0]  desc_type;
wire [7:0]  descrom_rdat;
wire [15:0] desc_dev_addr;
wire [15:0] desc_dev_len;
wire [15:0] desc_qual_addr;
wire [15:0] desc_qual_len;
wire [15:0] desc_fscfg_addr;
wire [15:0] desc_fscfg_len;
wire [15:0] desc_hscfg_addr;
wire [15:0] desc_hscfg_len;
wire [15:0] desc_oscfg_addr;
wire [15:0] desc_hidrpt_addr;
wire [15:0] desc_hidrpt_len;
wire [15:0] desc_strlang_addr;
wire [15:0] desc_strvendor_addr;
wire [15:0] desc_strvendor_len;
wire [15:0] desc_strproduct_addr;
wire [15:0] desc_strproduct_len;
wire [15:0] desc_strserial_addr;
wire [15:0] desc_strserial_len;
wire        descrom_have_strings;

wire        usb_busreset;
wire        usb_highspeed;
wire        usb_suspend;
wire        usb_online;
wire        usb_txval;
wire [7:0]  usb_txdat;
wire [7:0]  uac_txdat;
wire [11:0] usb_txdat_len;
wire [11:0] uac_txdat_len;
wire        uac_txcork;
wire        usb_txcork;
wire        usb_txpop;
wire        usb_txact;
wire        usb_txpktfin;
wire [7:0]  usb_rxdat;
wire        usb_rxval;
wire        usb_rxact;
wire        usb_rxpktval;
wire        usb_setup;
wire [3:0]  usb_endpt_sel;
wire        usb_sof;
wire [7:0]  interface_alter_i;
wire [7:0]  interface_alter_o;
wire [7:0]  interface_sel;
wire        interface_update;

wire        fifo_alempty;
wire        fifo_alfull;

wire        audio_tx_dval;
wire [7:0]  audio_tx_data;
wire        audio_rx_dval;
wire [7:0]  audio_rx_data;
wire [11:0] audio_pkt_max;
wire [11:0] audio_pkt_nor;
wire [11:0] audio_pkt_min;

wire        ep_usb_txcork;
wire [11:0] ep_usb_txlen;
wire [7:0]  ep_usb_txdat;
wire        usb_tx_fifo_full;

wire        fclk_480m;
wire        pll_locked;
wire        reset;

assign reset = !pll_locked;

// Keep EP2 path alive for compatibility with existing descriptor.
assign audio_rx_dval = 1'b0;
assign audio_rx_data = 8'd0;
assign audio_pkt_max = 12'd48;
assign audio_pkt_nor = 12'd48;
assign audio_pkt_min = 12'd48;

Gowin_rPLL u_pll (
    .clkout  (fclk_480m),
    .clkoutd (phy_clkout),
    .lock    (pll_locked),
    .clkin   (CLK_IN)
);

USB_Device_Controller_Top u_usb_device_controller_top (
    .clk_i                 (phy_clkout),
    .reset_i               (reset),
    .usbrst_o              (usb_busreset),
    .highspeed_o           (usb_highspeed),
    .suspend_o             (usb_suspend),
    .online_o              (usb_online),
    .txdat_i               (usb_txdat),
    .txval_i               (usb_txval),
    .txdat_len_i           (usb_txdat_len),
    .txcork_i              (usb_txcork),
    .txiso_pid_i           (4'b0011),
    .txpop_o               (usb_txpop),
    .txact_o               (usb_txact),
    .txpktfin_o            (usb_txpktfin),
    .rxdat_o               (usb_rxdat),
    .rxval_o               (usb_rxval),
    .rxact_o               (usb_rxact),
    .rxrdy_i               (1'b1),
    .rxpktval_o            (usb_rxpktval),
    .setup_o               (usb_setup),
    .endpt_o               (usb_endpt_sel),
    .sof_o                 (usb_sof),
    .inf_alter_i           (interface_alter_i),
    .inf_alter_o           (interface_alter_o),
    .inf_sel_o             (interface_sel),
    .inf_set_o             (interface_update),
    .descrom_rdata_i       (descrom_rdat),
    .descrom_raddr_o       (descrom_raddr),
    .desc_index_o          (desc_index),
    .desc_type_o           (desc_type),
    .desc_dev_addr_i       (desc_dev_addr),
    .desc_dev_len_i        (desc_dev_len),
    .desc_qual_addr_i      (desc_qual_addr),
    .desc_qual_len_i       (desc_qual_len),
    .desc_fscfg_addr_i     (desc_fscfg_addr),
    .desc_fscfg_len_i      (desc_fscfg_len),
    .desc_hscfg_addr_i     (desc_hscfg_addr),
    .desc_hscfg_len_i      (desc_hscfg_len),
    .desc_oscfg_addr_i     (desc_oscfg_addr),
    .desc_hidrpt_addr_i    (desc_hidrpt_addr),
    .desc_hidrpt_len_i     (desc_hidrpt_len),
    .desc_strlang_addr_i   (desc_strlang_addr),
    .desc_strvendor_addr_i (desc_strvendor_addr),
    .desc_strvendor_len_i  (desc_strvendor_len),
    .desc_strproduct_addr_i(desc_strproduct_addr),
    .desc_strproduct_len_i (desc_strproduct_len),
    .desc_strserial_addr_i (desc_strserial_addr),
    .desc_strserial_len_i  (desc_strserial_len),
    .desc_bos_addr_i       (16'd0),
    .desc_bos_len_i        (16'd0),
    .desc_have_strings_i   (descrom_have_strings),
    .utmi_dataout_o        (phy_dataout),
    .utmi_txvalid_o        (phy_txvalid),
    .utmi_txready_i        (phy_txready),
    .utmi_datain_i         (phy_datain),
    .utmi_rxactive_i       (phy_rxactive),
    .utmi_rxvalid_i        (phy_rxvalid),
    .utmi_rxerror_i        (phy_rxerror),
    .utmi_linestate_i      (phy_linestate),
    .utmi_opmode_o         (phy_opmode),
    .utmi_xcvrselect_o     (phy_xcvrselect),
    .utmi_termselect_o     (phy_termselect),
    .utmi_reset_o          (phy_reset)
);

usb_desc #(
    .VENDORID              (16'h33AB),
    .PRODUCTID             (16'h0202),
    .VERSIONBCD            (16'h0201),
    .HSSUPPORT             (1),
    .SELFPOWERED           (0),
    .CLOCK_SOURCE_ID       (CLOCK_SOURCE_ID),
    .AUDIO_CONTROL_UNIT_ID (AUDIO_CONTROL_UNIT_ID),
    .CLOCK_SELECTOR_ID     (CLOCK_SELECTOR_ID),
    .AUDIO_IT_ENDPOINT     (AUDIO_IT_ENDPOINT),
    .AUDIO_OT_ENDPOINT     (AUDIO_OT_ENDPOINT),
    .AUDIO_IT_FB_ENDPOINT  (AUDIO_IT_FB_ENDPOINT)
) u_usb_desc (
    .CLK                    (phy_clkout),
    .RESET                  (reset),
    .i_descrom_raddr        (descrom_raddr),
    .o_descrom_rdat         (descrom_rdat),
    .i_desc_index_o         (desc_index),
    .i_desc_type_o          (desc_type),
    .o_desc_dev_addr        (desc_dev_addr),
    .o_desc_dev_len         (desc_dev_len),
    .o_desc_qual_addr       (desc_qual_addr),
    .o_desc_qual_len        (desc_qual_len),
    .o_desc_fscfg_addr      (desc_fscfg_addr),
    .o_desc_fscfg_len       (desc_fscfg_len),
    .o_desc_hscfg_addr      (desc_hscfg_addr),
    .o_desc_hscfg_len       (desc_hscfg_len),
    .o_desc_oscfg_addr      (desc_oscfg_addr),
    .o_desc_hidrpt_addr     (desc_hidrpt_addr),
    .o_desc_hidrpt_len      (desc_hidrpt_len),
    .o_desc_strlang_addr    (desc_strlang_addr),
    .o_desc_strvendor_addr  (desc_strvendor_addr),
    .o_desc_strvendor_len   (desc_strvendor_len),
    .o_desc_strproduct_addr (desc_strproduct_addr),
    .o_desc_strproduct_len  (desc_strproduct_len),
    .o_desc_strserial_addr  (desc_strserial_addr),
    .o_desc_strserial_len   (desc_strserial_len),
    .o_descrom_have_strings (descrom_have_strings)
);

USB2_0_SoftPHY_Top u_usb_softphy_top (
    .clk_i             (phy_clkout),
    .rst_i             (phy_reset),
    .fclk_i            (fclk_480m),
    .pll_locked_i      (pll_locked),
    .utmi_data_out_i   (phy_dataout),
    .utmi_txvalid_i    (phy_txvalid),
    .utmi_op_mode_i    (phy_opmode),
    .utmi_xcvrselect_i (phy_xcvrselect),
    .utmi_termselect_i (phy_termselect),
    .utmi_data_in_o    (phy_datain),
    .utmi_txready_o    (phy_txready),
    .utmi_rxvalid_o    (phy_rxvalid),
    .utmi_rxactive_o   (phy_rxactive),
    .utmi_rxerror_o    (phy_rxerror),
    .utmi_linestate_o  (phy_linestate),
    .usb_dxp_io        (USB_DXP_IO),
    .usb_dxn_io        (USB_DXN_IO),
    .usb_rxdp_i        (USB_RXDP_I),
    .usb_rxdn_i        (USB_RXDN_I),
    .usb_pullup_en_o   (USB_PULLUP_EN_O),
    .usb_term_dp_io    (USB_TERM_DP_IO),
    .usb_term_dn_io    (USB_TERM_DN_IO)
);

usb_fifo u_usb_fifo (
    .i_clk            (phy_clkout),
    .i_reset          (usb_busreset),
    .i_usb_endpt      (usb_endpt_sel),
    .i_usb_rxact      (usb_rxact),
    .i_usb_rxval      (usb_rxval),
    .i_usb_rxpktval   (usb_rxpktval),
    .i_usb_rxdat      (usb_rxdat),
    .o_usb_rxrdy      (),
    .i_usb_txact      (usb_txact),
    .i_usb_txpop      (usb_txpop),
    .i_usb_txpktfin   (usb_txpktfin),
    .i_interface_sel  (interface_sel),
    .i_interface_alter(interface_alter_o),
    .o_usb_txcork     (ep_usb_txcork),
    .o_usb_txdat      (ep_usb_txdat),
    .o_usb_txlen      (ep_usb_txlen),
    .usb_tx_fifo_full (usb_tx_fifo_full),
    .tx_data_bits     (tx_data_bits),
    .i_ep1_rx_clk     (phy_clkout),
    .i_ep1_rx_rdy     (1'b1),
    .o_ep1_rx_dval    (audio_tx_dval),
    .o_ep1_rx_data    (audio_tx_data),
    .i_ep2_tx_clk     (phy_clkout),
    .i_ep2_tx_max     (audio_pkt_max),
    .i_ep2_tx_nor     (audio_pkt_nor),
    .i_ep2_tx_min     (audio_pkt_min),
    .i_ep2_tx_dval    (audio_rx_dval),
    .i_ep2_tx_data    (audio_rx_data)
);

uac_ctrl #(
    .CLOCK_SOURCE_ID      (CLOCK_SOURCE_ID),
    .AUDIO_CONTROL_UNIT_ID(AUDIO_CONTROL_UNIT_ID),
    .CLOCK_SELECTOR_ID    (CLOCK_SELECTOR_ID),
    .DOP_PACKET_CODE0     (DOP_PACKET_CODE0),
    .DOP_PACKET_CODE1     (DOP_PACKET_CODE1),
    .AUDIO_IT_FB_ENDPOINT (AUDIO_IT_FB_ENDPOINT)
) uac_ctrl_inst (
    .PHY_CLKOUT        (phy_clkout),
    .RESET             (reset),
    .XMCLK             (phy_clkout),
    .I_USB_HIGHSPEED   (1'b1),
    .I_USB_SETUP       (usb_setup),
    .I_USB_ENDPT_SEL   (usb_endpt_sel),
    .I_USB_RXPKTVAL    (usb_rxpktval),
    .I_USB_SOF         (usb_sof),
    .I_USB_RXACT       (usb_rxact),
    .I_USB_RXVAL       (usb_rxval),
    .I_USB_RXDAT       (usb_rxdat),
    .I_USB_TXACT       (usb_txact),
    .I_USB_TXPOP       (usb_txpop),
    .O_USB_TXVAL       (usb_txval),
    .O_USB_TXDAT       (uac_txdat),
    .O_USB_TXDAT_LEN   (uac_txdat_len),
    .O_USB_TXCORK      (uac_txcork),
    .I_INTERFACE_ALTER (interface_alter_o),
    .O_INTERFACE_ALTER (interface_alter_i),
    .I_INTERFACE_SEL   (interface_sel),
    .I_INTERFACE_UPDATE(interface_update),
    .I_FIFO_ALEMPTY    (fifo_alempty),
    .I_FIFO_ALFULL     (fifo_alfull),
    .O_DSD_EN          (),
    .O_DOP_EN          (),
    .O_MUTE            (mute),
    .O_CH0_VOLUME      (ch0_volume),
    .O_CH1_VOLUME      (ch1_volume),
    .O_CH2_VOLUME      (ch2_volume),
    .O_SAMPLE_RATE     (sample_rate),
    .O_TX_DATA_BITS    (tx_data_bits),
    .O_RX_DATA_BITS    (rx_data_bits)
);

usb_audio_pwm_player u_pwm_player (
    .clk           (phy_clkout),
    .reset         (reset),
    .i_audio_dval  (audio_tx_dval),
    .i_audio_data  (audio_tx_data),
    .i_sample_rate (sample_rate),
    .i_rx_data_bits(tx_data_bits),
    .i_mute        (mute),
    .o_fifo_alempty(fifo_alempty),
    .o_fifo_alfull (fifo_alfull),
    .o_pwm         (AUDIO_PWM_O)
);

assign usb_txdat_len = (usb_endpt_sel == AUDIO_IT_ENDPOINT[3:0]) ? ep_usb_txlen : uac_txdat_len;
assign usb_txcork    = (usb_endpt_sel == AUDIO_IT_ENDPOINT[3:0]) ? ep_usb_txcork : uac_txcork;
assign usb_txdat     = (usb_endpt_sel == AUDIO_IT_ENDPOINT[3:0]) ? ep_usb_txdat : uac_txdat;

endmodule
