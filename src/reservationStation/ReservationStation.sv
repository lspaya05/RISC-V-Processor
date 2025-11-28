// Name: Leonard Paya
// Date: 11/20/2025

module ReservationStation#( 
    parameter int NUM_SLOTS = 8,
    parameter int NUM_FU = 4;
    parameter int BIT_WIDTH = 32,
    parameter int ALU_OP_WIDTH = 7,
    parameter int TAG_WIDTH = 8, 
    parameter int NUM_CDB = 1;
    parameter int GATE_DELAY = 0;
) (
    input logic clk, reset,

    // Input logic from Instr. decode / Reg. File:
    input logic [TAG_WIDTH - 1 : 0] rvSlot_inTag,
    input logic [ALU_OP_WIDTH - 1 : 0] rvSlot_inOp,
    input logic [TAG_WIDTH - 1 : 0] rvSlot_inQj,
    input logic [TAG_WIDTH - 1 : 0] rvSlot_inQk,
    input logic [BIT_WIDTH - 1 : 0] rvSlot_inVj,
    input logic [BIT_WIDTH - 1 : 0] rvSlot_inVk,
    input logic [ADDR_WIDTH - 1 : 0] rvSlot_inAddr, 

    // Input CBD:
    input logic [TAG_WIDTH - 1 : 0] funcUnitTags [NUM_CDB - 1 : 0],
    input logic [BIT_WIDTH - 1 : 0] funcUnitOut [NUM_CDB - 1 : 0],
    input logic [NUM_CDB - 1 : 0] valueReady,

    //From Functional Units:
    input logic [NUM_FU - 1 : 0] fu_ready,

    //To Functional Units:
    output logic [TAG_WIDTH - 1 : 0] fromDemux_tag [NUM_FU - 1 : 0],
    output logic [ALU_OP_WIDTH - 1 : 0] fromDemux_op [NUM_FU - 1 : 0],
    output logic [BIT_WIDTH - 1 : 0] fromDemux_vj [NUM_FU - 1 : 0],
    output logic [BIT_WIDTH - 1 : 0] fromDemux_vk [NUM_FU - 1 : 0], 

    //Reservation Station Status Signals.
    output logic rs_full, 
);
    // Logic for Control I/O:
    logic [NUM_SLOTS - 1 : 0] rsSlot_wr;
    logic [NUM_SLOTS - 1 : 0] rsSlot_instrRecieved;

    // Datapath Out:
    logic [TAG_WIDTH - 1 : 0] rvSlot_outTag [NUM_SLOTS - 1 : 0];
    logic [ALU_OP_WIDTH - 1 : 0] rvSlot_outOp [NUM_SLOTS - 1 : 0];
    logic [BIT_WIDTH - 1 : 0] rvSlot_outVj [NUM_SLOTS - 1 : 0];
    logic [BIT_WIDTH - 1 : 0] rvSlot_outVk [NUM_SLOTS - 1 : 0];
    logic [ADDR_WIDTH - 1 : 0] rvSlot_outAddr [NUM_SLOTS - 1 : 0];

    // Reservation Station Statuses:
    logic [NUM_SLOTS - 1 : 0] rvSlot_busy, rv_ready;

    RSCntrl #(.NUM_SLOTS(NUM_SLOTS)) ReservationSlot_Cntrl (
        .rvSlot_busy, .rsSlot_wr, .rs_full
    );

    genvar i;
    generate 
        for (i = 0; i < NUM_SLOTS; i++) begin : reservationSlot

            ReservationSlot #(.BIT_WIDTH(BIT_WIDTH), .ALU_OP_WIDTH(ALU_OP_WIDTH),
                .TAG_WIDTH(TAG_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .NUM_CDB(NUM_CDB),
                .GATE_DELAY(GATE_DELAY)
            ) rsvpSlot (
                // Control I/O:
                .wr(rsSlot_wr[i]), .instrRecieved(rsSlot_instrRecieved[i]),
                .clk, .reset,
                .busy(rvSlot_busy[i]), .ready(rvSlot_ready[i]),

                // Datapath Input:
                .inTag(rvSlot_inTag),
                .inOp(rvSlot_inOp), 
                .inQj(rvSlot_inQj), .inQk(rvSlot_inQk), 
                .inVj(rvSlot_inVj), .inVk(rvSlot_inVk), 
                .inAddr(rvSlot_inAddr),

                // Datapath Out:
                .outTag(rvSlot_outTag[i]),
                .outOp(rvSlot_outOp[i]), 
                .outVj(rvSlot_outVj[i]), .outVk(rvSlot_outVk[i]),
                .outAddr(rvSlot_outAddr[i]),

                //From CDB:
                .funcUnitTags(funcUnitTags),
                .funcUnitOut(funcUnitOut),
                .valueReady(valueReady)
            );
        end
    endgenerate


    // Mux to Demux combos
    logic [TAG_WIDTH - 1 : 0] fromMux_tag [NUM_FU - 1 : 0];
    logic [ALU_OP_WIDTH - 1 : 0] fromMux_op [NUM_FU - 1 : 0];
    logic [BIT_WIDTH - 1 : 0] fromMux_vj [NUM_FU - 1 : 0];
    logic [BIT_WIDTH - 1 : 0] fromMux_vk [NUM_FU - 1 : 0];
    
    // Control Signal:
    logic [$clog2(NUM_SLOTS) - 1 : 0] slotSelect;
    logic [$clog2(NUM_FU) - 1 : 0] fuSelect;

    genvar j;
    generate 
        for (j = 0; j < NUM_FU; j++) begin : demux2Mux
            // Muxes from Reservation Station to Demux.
            MuxVector #(.BIT_WIDTH(TAG_WIDTH), .GATE_DELAY(GATE_DELAY), .NUM_VECTORS(NUM_SLOTS)) toDemux_tag (
                .in(rvSlot_outTag), .sel(slotSelect), .out(fromMux_tag)
            );

            MuxVector #(.BIT_WIDTH(ALU_OP_WIDTH), .GATE_DELAY(GATE_DELAY), .NUM_VECTORS(NUM_SLOTS)) toDemux_op (
                .in(rvSlot_outOp), .sel(slotSelect), .out(fromMux_op)
            );

            MuxVector #(.BIT_WIDTH(BIT_WIDTH), .GATE_DELAY(GATE_DELAY), .NUM_VECTORS(NUM_SLOTS)) toDemux_vj (
                .in(rvSlot_outVj), .sel(slotSelect), .out(fromMux_vj)
            );

            MuxVector #(.BIT_WIDTH(BIT_WIDTH), .GATE_DELAY(GATE_DELAY), .NUM_VECTORS(NUM_SLOTS)) toDemux_vk (
                .in(rvSlot_outVk), .sel(slotSelect), .out(fromMux_vk)
            );

            //Demux to Functional Unit:
            Demux #(.BIT_WIDTH(BIT_WIDTH), .NUM_VECTORS(NUM_FU)) toFU_tag (
                .in(fromMux_tag[j]), .sel(fuSelect), .out(fromDemux_tag[j])
            );

            Demux #(.BIT_WIDTH(BIT_WIDTH), .NUM_VECTORS(NUM_FU)) toFU_op (
                .in(fromMux_op[j]), .sel(fuSelect), .out(fromDemux_op[j])
            );

            Demux #(.BIT_WIDTH(BIT_WIDTH), .NUM_VECTORS(NUM_FU)) toFU_vj (
                .in(fromMux_vj[j]), .sel(fuSelect), .out(fromDemux_vj[j])
            );

            Demux #(.BIT_WIDTH(BIT_WIDTH), .NUM_VECTORS(NUM_FU)) toFU_vk (
                .in(fromMux_vk[j]), .sel(fuSelect), .out(fromDemux_vk[j])
            );
        end
    endgenerate
    
    logic readyToSend;
    // Functional Unit Scheduler:
    FUCntrl #(.NUM_SLOTS(NUM_SLOTS), .NUM_FU(NUM_FU), TAG_WIDTH(TAG_WIDTH)) fuScheduler (
        .rv_ready, .fu_ready, .rvSlot_outTag, .slotSelect, .fuSelect, .valid(readyToSend)
    )
endmodule
