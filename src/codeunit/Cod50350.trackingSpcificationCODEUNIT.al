codeunit 50350 trackingSpcificationCODEUNIT
{
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Qty. to Ship', false, false)]
    local procedure MyProcedure(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    begin
        if (Rec."Qty. to Ship" > 0) and (xRec."Qty. to Ship" <> Rec."Qty. to Ship") then
            autoInsertDataIntoTrackingSpecification(Rec);
    end;

    local procedure autoInsertDataIntoTrackingSpecification(salesLine: Record "Sales Line")
    var
        TempReservEntry: Record "Reservation Entry" temporary;
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservStatus: Enum "Reservation Status";
        user: Record User;
        ReservEntry: Record "Reservation Entry";
    begin

        ReservEntry.Reset();
        ReservEntry.SetRange("Source Type", Database::"Sales Line");
        ReservEntry.SetRange("Source Subtype", salesLine."Document Type".AsInteger());
        ReservEntry.SetRange("Source ID", salesLine."Document No.");
        ReservEntry.SetRange("Source Ref. No.", salesLine."Line No.");
        if ReservEntry.FindFirst() then begin
            Message('If Called');
            ReservEntry.Validate("Quantity (Base)", salesLine."Qty. to Ship (Base)");
            ReservEntry.Modify(true);
        end
        else begin
            Message('Else Called');
            TempReservEntry.Init();
            TempReservEntry."Item No." := salesLine."No.";
            TempReservEntry."Location Code" := salesLine."Location Code";
            TempReservEntry.Validate("Quantity (Base)", salesLine."Quantity (Base)");
            TempReservEntry."Reservation Status" := TempReservEntry."Reservation Status"::Reservation;
            TempReservEntry.Description := salesLine.Description;
            TempReservEntry."Creation Date" := salesLine."Posting Date";
            TempReservEntry."Source Type" := Database::"Sales Line";
            TempReservEntry."Source Subtype" := salesLine."Document Type".AsInteger();
            TempReservEntry."Source ID" := salesLine."Document No.";
            TempReservEntry."Source Ref. No." := salesLine."Line No.";
            TempReservEntry."Shipment Date" := salesLine."Shipment Date";
            if user.Get(UserSecurityId()) then begin
                TempReservEntry."Created By" := user."User Name";
            end;
            TempReservEntry.Validate("Qty. per Unit of Measure", salesLine."Qty. per Unit of Measure");
            TempReservEntry.Quantity := salesLine."Qty. to Ship (Base)";
            TempReservEntry."Lot No." := 'AUTOLOT' + '-' + Format(salesLine."Line No.");
            TempReservEntry."Item Tracking" := TempReservEntry."Item Tracking"::"Lot No.";
            TempReservEntry.Insert();
            if TempReservEntry.FindSet() then
                repeat
                    CreateReservEntry.SetDates(0D, TempReservEntry."Expiration Date");
                    CreateReservEntry.CreateReservEntryFor(
                      Database::"Sales Line", salesLine."Document Type".AsInteger(),
                      salesLine."Document No.", '', 0, salesLine."Line No.", salesLine."Qty. per Unit of Measure",
                      TempReservEntry.Quantity, TempReservEntry.Quantity * salesLine."Qty. per Unit of Measure", TempReservEntry);
                    CreateReservEntry.CreateEntry(
                     salesLine."No.", salesLine."Variant Code", salesLine."Location Code", '', 0D, 0D, 0, ReservStatus::Surplus);
                until TempReservEntry.Next() = 0;

        end;
    end;
}