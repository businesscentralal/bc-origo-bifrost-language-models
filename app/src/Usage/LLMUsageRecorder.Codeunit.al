namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>Records one content-free usage row and telemetry event for each provider request.</summary>
codeunit 10035440 "LLM Usage Recorder ori"
{
    Access = Internal;
    SingleInstance = true;
    InherentPermissions = X;
    InherentEntitlements = X;

    var
        TempContext: Record "LLM Usage Log ori" temporary;
        TempPending: Record "LLM Usage Log ori" temporary;
        PendingStatuses: Dictionary of [BigInteger, Integer];
        ScopeDepth: Integer;
        SequenceNo: BigInteger;

    /// <summary>Resolves call metadata without retaining the prompt, response or credentials.</summary>
    procedure SetContext(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        LanguageModel: Record "Bifrost Language Model ori";
    begin
        Clear(TempContext);
        LanguageModel.SetLoadFields(Code, "Chat Provider", Model, "Input Price per 1M", "Output Price per 1M", "Usage Currency Code");
        if LanguageModel.GetBySystemId(Argument."Language Model SystemId") then begin
            TempContext."Language Model Code" := LanguageModel.Code;
            TempContext.Provider := LanguageModel."Chat Provider";
            TempContext."Model ID" := LanguageModel.Model;
            TempContext."Input Price per 1M" := LanguageModel."Input Price per 1M";
            TempContext."Output Price per 1M" := LanguageModel."Output Price per 1M";
            TempContext."Currency Code" := LanguageModel."Usage Currency Code";
        end else
            TempContext."Model ID" := Argument.Model;
        TempContext."Invocation Source" := Argument."Invocation Source";
        if TempContext."Invocation Source" = '' then
            if Argument."Procedure Type" = Argument."Procedure Type"::CompletePrompt then
                TempContext."Invocation Source" := 'LLM.Prompt.Complete'
            else
                TempContext."Invocation Source" := 'Chat';
    end;

    /// <summary>Snapshots metadata and price immediately before the provider call.</summary>
    procedure BeginCall(var TempEntry: Record "LLM Usage Log ori" temporary)
    var
        LanguageModel: Record "Bifrost Language Model ori";
    begin
        TempEntry := TempContext;
        TempEntry."Entry No." := 0;
        TempEntry."Called At" := CurrentDateTime();
        Evaluate(TempEntry."Call Date", CopyStr(Format(TempEntry."Called At", 0, 9), 1, 10), 9);
        TempEntry.Company := CopyStr(CompanyName(), 1, MaxStrLen(TempEntry.Company));
        TempEntry."User Security ID" := UserSecurityId();
        LanguageModel.SetLoadFields("Input Price per 1M", "Output Price per 1M", "Usage Currency Code");
        if LanguageModel.Get(TempEntry."Language Model Code") then begin
            TempEntry."Input Price per 1M" := LanguageModel."Input Price per 1M";
            TempEntry."Output Price per 1M" := LanguageModel."Output Price per 1M";
            TempEntry."Currency Code" := LanguageModel."Usage Currency Code";
        end;
    end;

    /// <summary>Persists only numeric usage and controlled failure codes; response content is never stored.</summary>
    procedure FinishCall(var TempEntry: Record "LLM Usage Log ori" temporary; Response: JsonObject; Success: Boolean; HttpStatus: Integer)
    begin
        TempEntry."Duration Ms" := CurrentDateTime() - TempEntry."Called At";
        TempEntry.Success := Success;
        TempEntry."Usage Not Reported" := true;
        if Success then
            ReadUsage(Response, TempEntry)
        else
            if HttpStatus = 0 then
                TempEntry."Error Code" := 'TRANSPORT_OR_INVALID_RESPONSE'
            else
                TempEntry."Error Code" := CopyStr('HTTP_' + Format(HttpStatus, 0, 9), 1, MaxStrLen(TempEntry."Error Code"));
        TempEntry.Cost := (TempEntry."Input Tokens" * TempEntry."Input Price per 1M" + TempEntry."Output Tokens" * TempEntry."Output Price per 1M") / 1000000;
        SequenceNo += 1;
        TempPending := TempEntry;
        TempPending."Entry No." := SequenceNo;
        TempPending.Insert();
        PendingStatuses.Add(SequenceNo, HttpStatus);
    end;

    /// <summary>Defers database writes while provider rounds and Foundation tools are still running.</summary>
    procedure BeginScope()
    begin
        if ScopeDepth = 0 then begin
            TempPending.Reset();
            TempPending.DeleteAll();
            Clear(PendingStatuses);
            SequenceNo := 0;
        end;
        ScopeDepth += 1;
    end;

    /// <summary>Persists each buffered request once, after the outermost operation finishes.</summary>
    procedure EndScope()
    var
        TempEntry: Record "LLM Usage Log ori" temporary;
    begin
        if ScopeDepth = 0 then
            exit;
        ScopeDepth -= 1;
        if ScopeDepth > 0 then
            exit;
        if TempPending.FindSet() then
            repeat
                TempEntry := TempPending;
                TempEntry."Entry No." := 0;
                Persist(TempEntry, PendingStatuses.Get(TempPending."Entry No."));
            until TempPending.Next() = 0;
        TempPending.DeleteAll();
        Clear(PendingStatuses);
    end;

    [InherentPermissions(PermissionObjectType::TableData, Database::"LLM Usage Log ori", 'I', InherentPermissionsScope::Both)]
    local procedure Persist(var TempEntry: Record "LLM Usage Log ori" temporary; HttpStatus: Integer)
    var
        UsageLog: Record "LLM Usage Log ori";
        RequestLogger: Codeunit "Request Logger ori";
        Dimensions: Dictionary of [Text, Text];
    begin
        // The correlated Request Log is metadata-only even when request debugging is enabled.
        RequestLogger.InsertLog('LLM usage', 'POST', '', 'LLM', HttpStatus, TempEntry."Duration Ms", TempEntry.Success, TempEntry."Error Code", '', '', Enum::"Request Log Type ori"::LLM);
        TempEntry."Request Log Entry No." := RequestLogger.GetLastEntryNo();
        UsageLog := TempEntry;
        UsageLog.Insert(true);
        TempEntry."Entry No." := UsageLog."Entry No.";
        Dimensions := GetTelemetryDimensions(TempEntry);
        Session.LogMessage('ORI-LM-USAGE', 'Language model call usage', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;

    /// <summary>Returns the complete allowlist of telemetry dimensions; no user or request content is included.</summary>
    procedure GetTelemetryDimensions(TempEntry: Record "LLM Usage Log ori" temporary) Dimensions: Dictionary of [Text, Text]
    begin
        Dimensions.Add('model', TempEntry."Model ID");
        Dimensions.Add('provider', Format(TempEntry.Provider.AsInteger(), 0, 9));
        Dimensions.Add('source', TempEntry."Invocation Source");
        Dimensions.Add('inputTokens', Format(TempEntry."Input Tokens", 0, 9));
        Dimensions.Add('outputTokens', Format(TempEntry."Output Tokens", 0, 9));
        Dimensions.Add('cachedTokens', Format(TempEntry."Cached Tokens", 0, 9));
        Dimensions.Add('reasoningTokens', Format(TempEntry."Reasoning Tokens", 0, 9));
        Dimensions.Add('success', Format(TempEntry.Success, 0, 9));
        Dimensions.Add('errorCode', TempEntry."Error Code");
        Dimensions.Add('usageNotReported', Format(TempEntry."Usage Not Reported", 0, 9));
    end;

    local procedure ReadUsage(Response: JsonObject; var TempEntry: Record "LLM Usage Log ori" temporary)
    var
        Token: JsonToken;
        Usage: JsonObject;
        Details: JsonObject;
    begin
        if Response.Get('usageMetadata', Token) and Token.IsObject() then begin
            Usage := Token.AsObject();
            TempEntry."Input Tokens" := Number(Usage, 'promptTokenCount');
            TempEntry."Output Tokens" := Number(Usage, 'candidatesTokenCount');
            TempEntry."Cached Tokens" := Number(Usage, 'cachedContentTokenCount');
            TempEntry."Reasoning Tokens" := Number(Usage, 'thoughtsTokenCount');
            TempEntry."Usage Not Reported" := false;
            exit;
        end;
        if not Response.Get('usage', Token) then
            exit;
        if not Token.IsObject() then
            exit;
        Usage := Token.AsObject();
        TempEntry."Usage Not Reported" := false;
        if Usage.Contains('input_tokens') then begin
            TempEntry."Input Tokens" := Number(Usage, 'input_tokens');
            TempEntry."Output Tokens" := Number(Usage, 'output_tokens');
            TempEntry."Cached Tokens" := Number(Usage, 'cache_read_input_tokens');
            TempEntry."Cache Creation Tokens" := Number(Usage, 'cache_creation_input_tokens');
        end else begin
            TempEntry."Input Tokens" := Number(Usage, 'prompt_tokens');
            TempEntry."Output Tokens" := Number(Usage, 'completion_tokens');
        end;
        if Usage.Get('prompt_tokens_details', Token) or Usage.Get('input_tokens_details', Token) then
            if Token.IsObject() then begin
                Details := Token.AsObject();
                TempEntry."Cached Tokens" := Number(Details, 'cached_tokens');
            end;
        if Usage.Get('completion_tokens_details', Token) or Usage.Get('output_tokens_details', Token) then
            if Token.IsObject() then begin
                Details := Token.AsObject();
                TempEntry."Reasoning Tokens" := Number(Details, 'reasoning_tokens');
            end;
    end;

    local procedure Number(Source: JsonObject; KeyName: Text): BigInteger
    var
        Value: BigInteger;
    begin
        if TryReadNumber(Source, KeyName, Value) then
            if Value > 0 then
                exit(Value);
        exit(0);
    end;

    [TryFunction]
    local procedure TryReadNumber(Source: JsonObject; KeyName: Text; var Value: BigInteger)
    var
        Token: JsonToken;
    begin
        Value := 0;
        if Source.Get(KeyName, Token) then
            if Token.IsValue() then
                if not Token.AsValue().IsNull() then
                    Value := Token.AsValue().AsBigInteger();
    end;
}
