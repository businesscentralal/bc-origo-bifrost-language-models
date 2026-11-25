namespace Origo.Bifrost.LanguageModels;

using System.Threading;

/// <summary>Atomically replaces old call detail with daily totals, optionally retaining the user.</summary>
codeunit 10035445 "LLM Usage Compression ori"
{
    Access = Internal;
    TableNo = "Job Queue Entry";
    Permissions = tabledata "LLM Usage Log ori" = RD,
                  tabledata "LLM Usage Daily ori" = RIM;

    trigger OnRun()
    begin
        Compress();
    end;

    /// <summary>Compresses strictly older days and never commits between aggregation and deletion.</summary>
    procedure Compress()
    var
        Setup: Record "LLM Usage Setup ori";
        UsageLog: Record "LLM Usage Log ori";
        CutoffDate: Date;
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup."Compress After Days" := 30;
        end;
        Setup.TestField("Compress After Days");
        // Usage is dated by the actual call, independent of the accounting work date.
        CutoffDate := Today() - Setup."Compress After Days";
        UsageLog.LockTable();
        UsageLog.ReadIsolation := IsolationLevel::UpdLock;
        UsageLog.SetFilter("Call Date", '<%1', CutoffDate);
        if UsageLog.FindSet(true) then
            repeat
                AddDaily(UsageLog, Setup."Keep User in Daily Totals");
                UsageLog.Delete();
            until UsageLog.Next() = 0;
    end;

    local procedure AddDaily(UsageLog: Record "LLM Usage Log ori"; KeepUser: Boolean)
    var
        Daily: Record "LLM Usage Daily ori";
        UserID: Guid;
    begin
        if KeepUser then
            UserID := UsageLog."User Security ID";
        Daily.LockTable();
        Daily.ReadIsolation := IsolationLevel::UpdLock;
        Daily.SetRange("Call Date", UsageLog."Call Date");
        Daily.SetRange(Company, UsageLog.Company);
        Daily.SetRange("Language Model Code", UsageLog."Language Model Code");
        Daily.SetRange(Provider, UsageLog.Provider);
        Daily.SetRange("Model ID", UsageLog."Model ID");
        Daily.SetRange("Invocation Source", UsageLog."Invocation Source");
        Daily.SetRange("User Security ID", UserID);
        Daily.SetRange("Currency Code", UsageLog."Currency Code");
        if not Daily.FindFirst() then begin
            Daily.Init();
            Daily."Call Date" := UsageLog."Call Date";
            Daily.Company := UsageLog.Company;
            Daily."Language Model Code" := UsageLog."Language Model Code";
            Daily.Provider := UsageLog.Provider;
            Daily."Model ID" := UsageLog."Model ID";
            Daily."Invocation Source" := UsageLog."Invocation Source";
            Daily."User Security ID" := UserID;
            Daily."Currency Code" := UsageLog."Currency Code";
            Daily.Insert(true);
        end;
        Daily."Call Count" += 1;
        if not UsageLog.Success then
            Daily."Error Count" += 1;
        Daily."Input Tokens" += UsageLog."Input Tokens";
        Daily."Output Tokens" += UsageLog."Output Tokens";
        Daily."Cached Tokens" += UsageLog."Cached Tokens";
        Daily."Reasoning Tokens" += UsageLog."Reasoning Tokens";
        Daily."Cache Creation Tokens" += UsageLog."Cache Creation Tokens";
        Daily.Cost += UsageLog.Cost;
        Daily.Modify(true);
    end;

    /// <summary>Reads detail plus daily totals for the current month, keeping currencies separate.</summary>
    procedure MonthTotals(ModelCode: Code[20]; CurrencyCode: Code[10]; var InputTokens: BigInteger; var OutputTokens: BigInteger; var Cost: Decimal)
    var
        UsageLog: Record "LLM Usage Log ori";
        Daily: Record "LLM Usage Daily ori";
        FirstDay: Date;
        LastDay: Date;
    begin
        // Report the actual calendar month, not the user's accounting work date.
        FirstDay := CalcDate('<-CM>', Today());
        LastDay := CalcDate('<CM>', Today());
        UsageLog.SetRange("Language Model Code", ModelCode);
        UsageLog.SetRange("Currency Code", CurrencyCode);
        UsageLog.SetRange("Call Date", FirstDay, LastDay);
        UsageLog.CalcSums("Input Tokens", "Output Tokens", Cost);
        Daily.SetRange("Language Model Code", ModelCode);
        Daily.SetRange("Currency Code", CurrencyCode);
        Daily.SetRange("Call Date", FirstDay, LastDay);
        Daily.CalcSums("Input Tokens", "Output Tokens", Cost);
        InputTokens := UsageLog."Input Tokens" + Daily."Input Tokens";
        OutputTokens := UsageLog."Output Tokens" + Daily."Output Tokens";
        Cost := UsageLog.Cost + Daily.Cost;
    end;
}
