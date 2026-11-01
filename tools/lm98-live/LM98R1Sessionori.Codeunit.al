namespace Origo.Bifrost.LanguageModels.Test;

/// <summary>One background session per R1 cell guarantees that Bootstrap starts cold unless explicitly warmed.</summary>
codeunit 96056 "LM98 R1 Session ori"
{
    Access = Internal;
    TableNo = "LM98 Receipt ori";

    trigger OnRun()
    var
        Probe: Codeunit "LM98 Probe ori";
        Result: JsonObject;
    begin
        // No write precedes the public dispatcher in this fresh session.
        Result := Probe.TransactionCell(Rec."Omit Commit", Rec."Cached Bootstrap");
        Rec.SetReport(Result);
        Rec.Finished := true;
        Rec.Modify();
    end;
}
