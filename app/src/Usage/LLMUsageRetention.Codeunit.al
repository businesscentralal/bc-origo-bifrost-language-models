namespace Origo.Bifrost.LanguageModels;

using System.DataAdministration;

/// <summary>Registers call-date retention and creates disabled, administrator-controlled defaults.</summary>
codeunit 10035444 "LLM Usage Retention ori"
{
    Access = Internal;
    Permissions = tabledata "Retention Policy Setup" = RI,
                  tabledata "Retention Period" = RI,
                  tabledata "LLM Usage Log ori" = RD,
                  tabledata "LLM Usage Daily ori" = RD;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reten. Pol. Allowed Tables", 'OnRefreshAllowedTables', '', false, false)]
    local procedure RegisterAllowedTables()
    var
        UsageLog: Record "LLM Usage Log ori";
        Daily: Record "LLM Usage Daily ori";
        Allowed: Codeunit "Reten. Pol. Allowed Tables";
    begin
        Allowed.AddAllowedTable(Database::"LLM Usage Log ori", UsageLog.FieldNo("Called At"), 0);
        Allowed.AddAllowedTable(Database::"LLM Usage Daily ori", Daily.FieldNo("Call Date"), 0);
    end;

    /// <summary>Creates missing defaults only; an administrator's existing policy is never changed.</summary>
    procedure InstallDefaults()
    begin
        RegisterAllowedTables();
        CreateDefault(Database::"LLM Usage Log ori", 'LLM-90D', '<-90D>');
        CreateDefault(Database::"LLM Usage Daily ori", 'LLM-2Y', '<-2Y>');
    end;

    local procedure CreateDefault(TableID: Integer; PeriodCode: Code[20]; PeriodFormula: Text)
    var
        Policy: Record "Retention Policy Setup";
        Period: Record "Retention Period";
    begin
        if Policy.Get(TableID) then
            exit;
        if not Period.Get(PeriodCode) then begin
            Period.Init();
            Period.Code := PeriodCode;
            Period.Description := PeriodCode;
            Period."Retention Period" := Period."Retention Period"::Custom;
            Evaluate(Period."Ret. Period Calculation", PeriodFormula);
            Period.Validate("Ret. Period Calculation");
            Period.Insert(true);
        end;
        Policy.Init();
        Policy.Validate("Table Id", TableID);
        Policy.Validate("Retention Period", PeriodCode);
        Policy.Validate(Enabled, false);
        Policy.Insert(true);
    end;
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Apply Retention Policy", 'OnApplyRetentionPolicyIndirectPermissionRequired', '', false, false)]
    local procedure DeleteExpiredUsage(var RecRef: RecordRef; var Handled: Boolean)
    begin
        if not (RecRef.Number in [Database::"LLM Usage Log ori", Database::"LLM Usage Daily ori"]) then
            exit;
        // Preserve every filter selected by the standard retention engine.
        RecRef.DeleteAll(true);
        Handled := true;
    end;

}
