namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>Nonshipping probe. Preserves transaction mode, never returns provider or customer content.</summary>
codeunit 96050 "LM98 Probe Impl ori" implements "Msg Interface ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Runs one explicitly selected diagnostic; no implicit commit repairs are made.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Tools: Codeunit "LangModel Test Tools";
        Probe: Codeunit "LM98 Probe ori";
        Request: JsonObject;
        Result: JsonObject;
    begin
        if not Tools.AssertNotProduction(Argument) then
            exit;
        Request := Argument.GetRequestJson();
        case Tools.GetText(Request, 'operation') of
            'r1':
                Result := Probe.NestedTool();
            'time':
                Result := Probe.SessionTime();
            'blobs':
                Result := Probe.Blobs();
            'tools':
                Result := Probe.ToolNames();
            'requestTools':
                Result := Probe.RequestTools(Request.GetBigInteger('logEntryNo'));
            'receipt':
                Result := Probe.Receipt(Tools.GetText(Request, 'receipt'));
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'Unknown probe operation.', 'operation', '', 'r1, time, blobs, tools, requestTools or receipt', 'Choose one documented diagnostic.');
                exit;
            end;
        end;
        Argument.SetResponseJson(Result);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Declares only nonlive diagnostic selectors; no model or credential parameter exists.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('operation', 'string', true, 'r1, time, blobs, tools, requestTools or receipt.'));
        Parameters.Add(Contract.Parameter('receipt', 'string', false, 'Native receipt key: LM98-LIVE or R1-debug-omit-cache, where each flag is 0 or 1.'));
        Parameters.Add(Contract.Parameter('logEntryNo', 'integer', false, 'For requestTools: exact creator-owned request log entry. Only the tool names are returned.'));
        exit(true);
    end;

    /// <summary>The message writes diagnostic queue/log state and synthetic session blobs; the separate native live batch is not a message operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Test-only queued messages and synthetic session blob fixtures. No external calls and no explicit commits inside this message implementation.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', '');
        exit(true);
    end;

    /// <summary>Uses the standard test envelope and strict unknown-parameter behavior.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Tools: Codeunit "LangModel Test Tools";
    begin
        exit(Tools.TestEnvelope(Envelope));
    end;

    /// <summary>Returns diagnostic metadata only; never a raw prompt, answer, tool result or key.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes this nonshipping diagnostic.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('TEST ONLY LM98: nonlive transaction, session-time, blob and sanitized native-receipt diagnostics.');
    end;

    /// <summary>Diagnoses external provider effects through the inbound test route.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Uses no record subject.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>The test extension registers this nonshipping diagnostic.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Describes the test-only operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>No additional target chapter is provided by this private probe.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional errors chapter is provided by this private probe.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional metering chapter is provided by this private probe.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional related chapter is provided by this private probe.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional workflow chapter is provided by this private probe.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional examples chapter is provided by this private probe.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional notes chapter is provided by this private probe.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Private nonshipping diagnostic; results are observations, not acceptance passes.';
        exit(true);
    end;
}
