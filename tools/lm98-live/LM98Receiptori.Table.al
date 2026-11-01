namespace Origo.Bifrost.LanguageModels.Test;

/// <summary>Private spike receipt and one-shot live allowance. Retain until issue closure; never reset to retry.</summary>
table 96050 "LM98 Receipt ori"
{
    Access = Internal;
    DataClassification = SystemMetadata;
    DataPerCompany = false;
    fields
    {
        field(1; Id; Code[20]) { }
        field(2; Finished; Boolean) { }
        field(3; "HTTP Calls"; Integer) { }
        field(4; "Safe Report"; Blob) { }
        field(5; "Started At"; DateTime) { }
        field(6; "Omit Commit"; Boolean) { }
        field(7; "Cached Bootstrap"; Boolean) { }
    }
    keys
    {
        key(PK; Id) { Clustered = true; }
    }

    /// <summary>Stores only metadata assembled by the probe; callers never pass prompts or replies.</summary>
    procedure SetReport(Report: JsonObject)
    var
        Output: OutStream;
        Value: Text;
    begin
        Report.WriteTo(Value);
        "Safe Report".CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText(Value);
    end;

    /// <summary>Returns the saved sanitized report without fetching any provider request body.</summary>
    procedure GetReport() Report: JsonObject
    var
        Input: InStream;
        Value: Text;
    begin
        CalcFields("Safe Report");
        if "Safe Report".HasValue() then begin
            "Safe Report".CreateInStream(Input, TextEncoding::UTF8);
            Input.ReadText(Value);
            Report.ReadFrom(Value);
        end;
        Report.Add('allowanceConsumed', Id = 'LM98-LIVE');
        Report.Add('finished', Finished);
        Report.Add('httpCalls', "HTTP Calls");
    end;
}
