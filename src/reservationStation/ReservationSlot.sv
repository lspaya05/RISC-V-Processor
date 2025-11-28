// Name: Leonard Paya
// Date: 11/09/2025

//Comment here...

// Parameters:
//      - BIT_WIDTH: 
//      - ALU_OP_WIDTH:
//      - TAG_WIDTH:
//      - NUM_CDB: 
//      - GATE_DELAY: 
// Control IO: 
//  Inputs:
//      - wr: 1-bit signal to 'Write' to the slot. Loads up all the tags and values.
//      - instrRecieved: 1-bit signal signifying the data of an instruction has been recieved in
//              the functional unit, and tells the reservation slot that it can accept a new
//              instruction.
//      - clk: 1 bit clock signal for system.
//      - reset: 1 bit reset signal for system.
//  Outputs:
//      - busy: The slot is currently busy and cannot accept a new instruction. Can be bypassed; 
//              simply a status signal.
//      - ready: The data inside the slot is ready to be sent to a functional unit.
// Datapath IO:
//  Inputs:
//      - inTag: Bus of bit length 'TAG_WIDTH', sends the tag of the current instruction. 
//      - inOp: Bus of bit length 'ALU_OP_WIDTH', sends the Functional Unit Opcode to execute
//              the instruction.
//      - inQj, inQk: Bus of bit length 'TAG_WIDTH', sends the tags that signifies the place of
//              Reg. j and Reg. K, that aren't yet loaded. If sent data in either is 0, means that the
//              value being sent in inVj or inVk is valid.
//      - inVj, inVk: Bus of bit length 'BIT_WIDTH', sends the value of Reg. j and Reg. k if known
//              at time when loading the slot.
//  Outputs:
//      - outTag: 
//      - outOp:
//      - outVj, outVk:
// CDB IO:
//  Inputs:
//      - funcUnitTags: 
//      - funcUnitOut:
//      - valueReady:
module ReservationSlot #(
    parameter int BIT_WIDTH = 32,
    parameter int ALU_OP_WIDTH = 7,
    parameter int TAG_WIDTH = 8, 
    parameter int NUM_CDB = 8;
    parameter int GATE_DELAY = 0;
) (
    // Control I/O:
    input logic  wr, instrRecieved,
    input logic clk, reset,
    output logic busy, ready,

    // Datapath I/O:
    input logic [TAG_WIDTH - 1 : 0] inTag,
    input logic [ALU_OP_WIDTH - 1 : 0] inOp, 
    input logic [TAG_WIDTH  - 1 : 0] inQj, inQk, 
    input logic [BIT_WIDTH - 1 : 0] inVj, inVk, 
    output logic [TAG_WIDTH - 1 : 0] outTag,
    output logic [ALU_OP_WIDTH - 1 : 0] outOp, 
    output logic [BIT_WIDTH - 1 : 0] outVj, outVk,

    //From CDB:
    input logic [TAG_WIDTH - 1 : 0] funcUnitTags [NUM_CDB - 1 : 0],
    input logic [BIT_WIDTH - 1 : 0] funcUnitOut [NUM_CDB - 1 : 0],
    input logic [NUM_CDB - 1 : 0] valueReady,
);
    // Logics for storing value from CDB: 
    logic [TAG_WIDTH  - 1 : 0] Qj, Qk;
    logic [NUM_CDB - 1 : 0] comparator2Encoder_Vj;
    logic [NUM_CDB - 1 : 0] comparator2Encoder_Vk;
    logic [$clog2(NUM_CDB) - 1 : 0] encoder2Mux_Vj;
    logic [$clog2(NUM_CDB) - 1 : 0] encoder2Mux_Vk;
    logic [BIT_WIDTH - 1 : 0] muxOut_Vj;
    logic [BIT_WIDTH - 1 : 0] muxOut_Vk;

    //Status Sig. 
    always_ff @(posedge clk) begin
        if (wr) begin            // Setup Reservation Station
            busy <= 1;
            ready <= 0;

        end else if ((Qj == 0) & (Qk == 0)) begin // Check if data is ready
            ready <= 1;

        end else if (instrRecieved) begin
            busy <= 0;
        end
    end 

    // Datapath 4 all data Registers.
    always_ff @(posedge clk) begin 
        if (wr) begin // Setup Reservation Station
            outTag <= inTag;
            outOp <= inOp;
        end 

        if (wr) begin
            Qj <= inQj;
            Qk <= inQk;
            outVj <= inVj;
            outVk <= inVk;

        end else begin // Takes care of the Invalid Encoder Logic
            if (|comparator2Encoder_Vj) begin
                Qj <= 0;
                outVj <= muxOut_Vj;
            end

            if (|comparator2Encoder_Vk) begin
                Qk <= 0;
                outVk <= muxOut_Vk;
            end
        end
    end 

    // Datapath 4 all Combinational Logic:

    //Comparator Logic:
    genvar i;
    generate
        for (i = 0; i < NUM_CDB; i++) begin: tagComparator_WithValid
            comparator2Encoder_Vj[i] = valueReady[i] & (funcUnitTags[i] == Qj); 
            comparator2Encoder_Vk[i] = valueReady[i] & (funcUnitTags[i] == Qk);
        end
    endgenerate

    //Encoder Logic:
    Encoder #(.BIT_WIDTH($clog2(NUM_CDB))) sel_Qj (
        .in(comparator2Encoder_Vj), .out(encoder2Mux_Vj)
    );

    Encoder #(.BIT_WIDTH($clog2(NUM_CDB))) sel_Qk (
        .in(comparator2Encoder_Vk), .out(encoder2Mux_Vk)
    );
    
    //Mux Logic:
    MuxVector #(.BIT_WIDTH(BIT_WIDTH), .NUM_VECTORS(NUM_CDB), .GATE_DELAY(GATE_DELAY)) write2Slot_Qj (
        .in(funcUnitOut), .out(muxOut_Vj), .sel(encoder2Mux_Vj)
    );

    MuxVector #(.BIT_WIDTH(BIT_WIDTH), .NUM_VECTORS(NUM_CDB), .GATE_DELAY(GATE_DELAY)) write2Slot_Qk (
        .in(funcUnitOut), .out(muxOut_Vk), .sel(encoder2Mux_Vk)
    );


endmodule 