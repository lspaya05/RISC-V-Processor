
module RSCntrl #(
    parameter int NUM_SLOTS = 8,
) ( 
    input logic [NUM_SLOTS - 1 : 0] rvSlot_busy,
    output logic [NUM_SLOTS - 1 : 0] rsSlot_wr,
    output logic rs_full
); 
    //Assigns the Instruction to a Slot
    int i;
    always_comb begin
        slotToChoose = '1;

        for (i = 0; i < NUM_SLOTS; i++) begin
            if (!rvSlot_busy[i]) begin
                slotToChoose = i;
                break;
            end
        end
    end

    //Status Signal:
    assign rs_full = &rvSlot_busy; 

    // Write Enable Signal to all Slots:
    Demux #(.BIT_WIDTH(1), .NUM_VECTORS(NUM_SLOTS)) rsSlot_WrEn (
        .in(~rs_full), .sel(slotToChoose), .out(rsSlot_wr)
    );

endmodule