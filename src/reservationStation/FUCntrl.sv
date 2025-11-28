// Name: Leonard Paya
// Date: 11/20/2025

module FUCntrl #(
    parameter int NUM_SLOTS = 8, 
    parameter int NUM_FU = 4,
    parameter int TAG_WIDTH = 8
) (
    input logic [NUM_SLOTS - 1 : 0] rv_ready,
    input logic [NUM_FU - 1 : 0] fu_ready,
    input logic [TAG_WIDTH - 1 : 0] rvSlot_outTag [NUM_SLOTS - 1 : 0],
    output logic [$clog2(NUM_SLOTS) - 1 : 0] slotSelect,
    output logic [$clog2(NUM_FU) - 1 : 0] fuSelect,
    output logic valid
);

    int slotSelect = -1;
    int lowestValidTag = 32'h7FFF_FFFF;
    int i;

    //Control for choosing a specific Reservation Slot.
    always_comb begin
        slotSelect = '1;

        for (i = 0; i < NUM_SLOTS; i++) begin
            if (rv_ready[i] && (lowestValidTag > rvSlot_outTag[i])) begin
                slotSelect = i;
            end
        end
    end

    //Control for chossing a specific Functional Unit:
    always_comb begin
        fuSelect = '1;
        
        for (i = 0; i < NUM_FU; i++) begin
            if (fu_ready[i]) begin
                fuSelect = i;
                break;
            end
        end

    end 

    assign valid = (slotSelect != '1) & (fuSelect != '1);
endmodule