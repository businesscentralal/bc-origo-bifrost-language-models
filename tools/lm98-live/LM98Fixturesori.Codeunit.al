namespace Origo.Bifrost.LanguageModels.Test;

using Microsoft.Sales.Customer;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.PaymentTerms;

/// <summary>Creates only new synthetic LM98 records and deletes only the recorded SystemIds.</summary>
codeunit 96054 "LM98 Fixtures ori"
{
    Access = Internal;

    var
        OwnedRecords: List of [RecordId];
        OwnedIds: List of [Guid];
        OwnedModifiedAt: List of [DateTime];

    /// <summary>Creates a complete posting setup and the three deliberately different customer fixtures.</summary>
    procedure Create()
    var
        Customer: Record Customer;
        Account: Record "G/L Account";
        GenBusiness: Record "Gen. Business Posting Group";
        GenProduct: Record "Gen. Product Posting Group";
        VatBusiness: Record "VAT Business Posting Group";
        VatProduct: Record "VAT Product Posting Group";
        GeneralPosting: Record "General Posting Setup";
        VatPosting: Record "VAT Posting Setup";
        CustomerPosting: Record "Customer Posting Group";
        PaymentTerms: Record "Payment Terms";
        Index: Integer;
        CustomerNo: Code[20];
    begin
        // Preflight all keys before the first write. Never borrow or edit CRONUS fixtures.
        for Index := 1 to 3 do begin
            CustomerNo := CustomerCode(Index);
            if Customer.Get(CustomerNo) then
                Error('LM98 customer fixture collision.');
        end;
        if Account.Get('BIFT-LM98') or GenBusiness.Get('BIFT-LM98') or GenProduct.Get('BIFT-LM98') or
           VatBusiness.Get('BIFT-LM98') or VatProduct.Get('BIFT-LM98') or PaymentTerms.Get('BIFT-LM98') or
           CustomerPosting.Get('BIFT-LM98') or CustomerPosting.Get('BIFT-NOREC') or
           GeneralPosting.Get('BIFT-LM98', 'BIFT-LM98') or VatPosting.Get('BIFT-LM98', 'BIFT-LM98') then
            Error('LM98 posting setup fixture collision.');
        Account.Init();
        Account."No." := 'BIFT-LM98';
        Account.Name := 'LM98 synthetic posting account';
        Account."Direct Posting" := true;
        Account.Insert(false);
        Track(Account.RecordId(), Account.SystemId);
        GenBusiness.Init();
        GenBusiness.Code := 'BIFT-LM98';
        GenBusiness.Insert(false);
        Track(GenBusiness.RecordId(), GenBusiness.SystemId);
        GenProduct.Init();
        GenProduct.Code := 'BIFT-LM98';
        GenProduct.Insert(false);
        Track(GenProduct.RecordId(), GenProduct.SystemId);
        VatBusiness.Init();
        VatBusiness.Code := 'BIFT-LM98';
        VatBusiness.Insert(false);
        Track(VatBusiness.RecordId(), VatBusiness.SystemId);
        VatProduct.Init();
        VatProduct.Code := 'BIFT-LM98';
        VatProduct.Insert(false);
        Track(VatProduct.RecordId(), VatProduct.SystemId);
        GeneralPosting.Init();
        GeneralPosting."Gen. Bus. Posting Group" := 'BIFT-LM98';
        GeneralPosting."Gen. Prod. Posting Group" := 'BIFT-LM98';
        GeneralPosting."Sales Account" := Account."No.";
        GeneralPosting."Sales Credit Memo Account" := Account."No.";
        GeneralPosting."Sales Line Disc. Account" := Account."No.";
        GeneralPosting."Sales Inv. Disc. Account" := Account."No.";
        GeneralPosting."Sales Pmt. Disc. Debit Acc." := Account."No.";
        GeneralPosting."Sales Pmt. Disc. Credit Acc." := Account."No.";
        GeneralPosting."COGS Account" := Account."No.";
        GeneralPosting."COGS Account (Interim)" := Account."No.";
        GeneralPosting."Purch. Account" := Account."No.";
        GeneralPosting."Purch. Line Disc. Account" := Account."No.";
        GeneralPosting."Purch. Inv. Disc. Account" := Account."No.";
        GeneralPosting."Purch. Pmt. Disc. Credit Acc." := Account."No.";
        GeneralPosting."Inventory Adjmt. Account" := Account."No.";
        GeneralPosting."Purch. Credit Memo Account" := Account."No.";
        GeneralPosting."Purch. Pmt. Disc. Debit Acc." := Account."No.";
        GeneralPosting."Sales Pmt. Tol. Debit Acc." := Account."No.";
        GeneralPosting."Sales Pmt. Tol. Credit Acc." := Account."No.";
        GeneralPosting."Purch. Pmt. Tol. Debit Acc." := Account."No.";
        GeneralPosting."Purch. Pmt. Tol. Credit Acc." := Account."No.";
        GeneralPosting."Sales Prepayments Account" := Account."No.";
        GeneralPosting."Purch. Prepayments Account" := Account."No.";
        GeneralPosting."Purch. FA Disc. Account" := Account."No.";
        GeneralPosting."Invt. Accrual Acc. (Interim)" := Account."No.";
        GeneralPosting."Direct Cost Non-Inv. App. Acc." := Account."No.";
        GeneralPosting."Direct Cost Applied Account" := Account."No.";
        GeneralPosting."Overhead Applied Account" := Account."No.";
        GeneralPosting."Purchase Variance Account" := Account."No.";
        GeneralPosting.Insert(false);
        Track(GeneralPosting.RecordId(), GeneralPosting.SystemId);
        VatPosting.Init();
        VatPosting."VAT Bus. Posting Group" := 'BIFT-LM98';
        VatPosting."VAT Prod. Posting Group" := 'BIFT-LM98';
        VatPosting."VAT %" := 20;
        VatPosting."Sales VAT Account" := Account."No.";
        VatPosting."Purchase VAT Account" := Account."No.";
        VatPosting."Reverse Chrg. VAT Acc." := Account."No.";
        VatPosting."Sales VAT Unreal. Account" := Account."No.";
        VatPosting."Purch. VAT Unreal. Account" := Account."No.";
        VatPosting."Reverse Chrg. VAT Unreal. Acc." := Account."No.";
        VatPosting."Non-Ded. Purchase VAT Account" := Account."No.";
        VatPosting.Insert(false);
        Track(VatPosting.RecordId(), VatPosting.SystemId);
        PaymentTerms.Init();
        PaymentTerms.Code := 'BIFT-LM98';
        Evaluate(PaymentTerms."Due Date Calculation", '<30D>');
        PaymentTerms.Insert(false);
        Track(PaymentTerms.RecordId(), PaymentTerms.SystemId);
        CustomerPosting.Init();
        CustomerPosting.Code := 'BIFT-LM98';
        CustomerPosting."Receivables Account" := Account."No.";
        CustomerPosting."Service Charge Acc." := Account."No.";
        CustomerPosting."Payment Disc. Debit Acc." := Account."No.";
        CustomerPosting."Payment Disc. Credit Acc." := Account."No.";
        CustomerPosting."Interest Account" := Account."No.";
        CustomerPosting."Additional Fee Account" := Account."No.";
        CustomerPosting."Debit Curr. Appln. Rndg. Acc." := Account."No.";
        CustomerPosting."Credit Curr. Appln. Rndg. Acc." := Account."No.";
        CustomerPosting."Debit Rounding Account" := Account."No.";
        CustomerPosting."Credit Rounding Account" := Account."No.";
        CustomerPosting."Invoice Rounding Account" := Account."No.";
        CustomerPosting."Payment Tolerance Debit Acc." := Account."No.";
        CustomerPosting."Payment Tolerance Credit Acc." := Account."No.";
        CustomerPosting."Add. Fee per Line Account" := Account."No.";
        CustomerPosting.Insert(false);
        Track(CustomerPosting.RecordId(), CustomerPosting.SystemId);
        CustomerPosting.Code := 'BIFT-NOREC';
        CustomerPosting."Receivables Account" := '';
        CustomerPosting.Insert(false);
        Track(CustomerPosting.RecordId(), CustomerPosting.SystemId);
        for Index := 1 to 3 do begin
            Customer.Init();
            Customer."No." := CustomerCode(Index);
            Customer.Name := 'LM98 synthetic customer';
            Customer."Gen. Bus. Posting Group" := 'BIFT-LM98';
            Customer."VAT Bus. Posting Group" := 'BIFT-LM98';
            Customer."Customer Posting Group" := 'BIFT-LM98';
            Customer."Payment Terms Code" := 'BIFT-LM98';
            if Index = 2 then
                Customer."Gen. Bus. Posting Group" := '';
            if Index = 3 then
                Customer."Customer Posting Group" := 'BIFT-NOREC';
            Customer.Insert(false);
            Track(Customer.RecordId(), Customer.SystemId);
        end;
    end;

    local procedure Track(Id: RecordId; SystemId: Guid)
    var
        RecRef: RecordRef;
        ModifiedAt: DateTime;
    begin
        OwnedRecords.Add(Id);
        OwnedIds.Add(SystemId);
        RecRef.Open(Id.TableNo());
        RecRef.GetBySystemId(SystemId);
        ModifiedAt := RecRef.Field(RecRef.SystemModifiedAtNo()).Value;
        OwnedModifiedAt.Add(ModifiedAt);
        RecRef.Close();
    end;

    /// <summary>Captures exact owned identities before fixture writes are committed, for crash recovery.</summary>
    procedure Manifest() Rows: JsonArray
    var
        Row: JsonObject;
        Index: Integer;
    begin
        for Index := 1 to OwnedIds.Count() do begin
            Clear(Row);
            Row.Add('tableNo', OwnedRecords.Get(Index).TableNo());
            Row.Add('systemId', Format(OwnedIds.Get(Index), 0, 4));
            Row.Add('modifiedAt', Format(OwnedModifiedAt.Get(Index), 0, 9));
            Rows.Add(Row);
        end;
    end;

    /// <summary>Deletes in reverse dependency order and confirms every owned SystemId is absent.</summary>
    procedure Cleanup(): Integer
    var
        RecRef: RecordRef;
        Index: Integer;
        Deleted: Integer;
        ModifiedAt: DateTime;
    begin
        for Index := OwnedRecords.Count() downto 1 do begin
            RecRef.Open(OwnedRecords.Get(Index).TableNo());
            if RecRef.GetBySystemId(OwnedIds.Get(Index)) then begin
                if RecRef.RecordId() <> OwnedRecords.Get(Index) then
                    Error('LM98 fixture changed identity; retain for its owner.');
                ModifiedAt := RecRef.Field(RecRef.SystemModifiedAtNo()).Value;
                if ModifiedAt <> OwnedModifiedAt.Get(Index) then
                    Error('LM98 owned fixture was subsequently modified; retain it for custody reconciliation.');
                RecRef.Delete(false);
                Deleted += 1;
            end;
            if RecRef.GetBySystemId(OwnedIds.Get(Index)) then
                Error('LM98 owned fixture cleanup was not verified.');
            RecRef.Close();
        end;
        exit(Deleted);
    end;

    /// <summary>Maps the three fixed synthetic customer scenarios.</summary>
    procedure CustomerCode(Index: Integer): Code[20]
    begin
        case Index of
            1:
                exit('BIFT-A');
            2:
                exit('BIFT-B');
            3:
                exit('BIFT-C');
        end;
        Error('LM98 unknown customer scenario.');
    end;
}
