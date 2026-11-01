namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>Private LM98 diagnostics. Results describe observations, never imply an acceptance pass.</summary>
codeunit 96051 "LM98 Probe ori"
{
    Access = Public;

    var
        ToolServer: Codeunit "MCP Tool Server ori";
        Tools: Codeunit "LangModel Test Tools";

    /// <summary>Executes Bootstrap and a nested Codeunit.Run-backed tool without committing.</summary>
    procedure NestedTool() Result: JsonObject
    var
        Arguments: JsonObject;
        Response: Text;
        Prompt: Text;
        IsError: Boolean;
    begin
        Prompt := ToolServer.Bootstrap('');
        ToolServer.CallTool('who_am_i', Arguments, Response, IsError);
        Result.Add('status', 'Observed');
        Result.Add('bootstrapChars', StrLen(Prompt));
        Result.Add('nestedToolError', IsError);
        // This path never calls a provider; preserve the BC transaction/permission error for R1.
        if IsError then
            Result.Add('bcError', Response);
    end;

    /// <summary>Uses the public dispatcher for either transaction mode. Run each cell in a fresh BC session.</summary>
    procedure TransactionCell(OmitCommit: Boolean; CachedBootstrap: Boolean) Result: JsonObject
    var
        Setup: Record "Setup ori";
        Response: Text;
        WarmPrompt: Text;
        Worked: Boolean;
    begin
        Result.Add('omitCommit', OmitCommit);
        Result.Add('cachedBootstrap', CachedBootstrap);
        Result.Add('requestDebugMode', Setup.GetRequestDebugMode());
        if CachedBootstrap then
            if not TryWarmBootstrap(WarmPrompt) then begin
                Result.Add('warmBootstrapFailed', true);
                Result.Add('bcError', GetLastErrorText());
                exit;
            end;
        ClearLastError();
        Worked := TryDispatch(OmitCommit, Response);
        Result.Add('dispatcherReturned', Worked);
        if not Worked then begin
            Result.Add('bcError', GetLastErrorText());
            exit;
        end;
        Result.Add('response', Response);
        Result.Add('warmBootstrapChars', StrLen(WarmPrompt));
    end;

    [TryFunction]
    local procedure TryWarmBootstrap(var Prompt: Text)
    begin
        Prompt := ToolServer.Bootstrap('');
    end;

    /// <summary>Reads a sanitized native-harness receipt; never accesses raw model content.</summary>
    procedure Receipt(ReceiptKey: Text) Result: JsonObject
    begin
        OnReadReceipt(ReceiptKey, Result);
        if Result.Keys().Count() = 0 then
            Error('LM98 receipt unavailable; install the matching native harness and inspect its execution.');
    end;

    [IntegrationEvent(false, false)]
    local procedure OnReadReceipt(ReceiptKey: Text; var Result: JsonObject)
    begin
    end;

    [TryFunction]
    local procedure TryDispatch(OmitCommit: Boolean; var Response: Text)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
    begin
        RequestContent.AddText('{"operation":"r1"}');
        // Execute delegates to EnqueueAndProcess; its Boolean overload is public on the released baseline.
        Dispatcher.Execute(Enum::"Message Type ori"::"Test.LanguageModel.AskProbe", Enum::"Message Version ori"::"1.0",
            '', 'LM98 probe', 'text/json', RequestContent, ResponseContent, ContentType, OmitCommit);
        ResponseContent.GetSubText(Response, 1);
    end;

    /// <summary>Finds the real cached Bootstrap block, replaces it, and exposes only the header and clock line.</summary>
    procedure SessionTime() Result: JsonObject
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        BeforePrompt: Text;
        AfterPrompt: Text;
        FreshBlock: Text;
        NowUtc: DateTime;
        Header: Text;
        NowLine: Text;
    begin
        BeforePrompt := ToolServer.Bootstrap('');
        Sleep(1100);
        NowUtc := CurrentDateTime();
        FreshBlock := Proxy.BuildSessionTimeBlock(NowUtc, 0, '', WorkDate());
        AfterPrompt := ReplaceTimeBlock(BeforePrompt, FreshBlock);
        Result.Add('status', 'Observed');
        Result.Add('beforeBlockCount', CountTimeBlocks(BeforePrompt));
        Result.Add('afterBlockCount', CountTimeBlocks(AfterPrompt));
        Result.Add('bootstrapStillCached', ToolServer.Bootstrap('') = BeforePrompt);
        Result.Add('clockSampleUtc', Format(NowUtc, 0, 9));
        Header := FirstLine(FreshBlock);
        NowLine := ClockLine(FreshBlock);
        Result.Add('header', Header);
        Result.Add('nowUtcLine', NowLine);
        Result.Add('blockChanged', AfterPrompt <> BeforePrompt);
    end;

    /// <summary>Replaces exactly one SESSION TIME block to the first empty line; refuses ambiguous input.</summary>
    procedure ReplaceTimeBlock(Prompt: Text; Replacement: Text): Text
    var
        Normalized: Text;
        Lines: List of [Text];
        Line: Text;
        Builder: TextBuilder;
        InBlock: Boolean;
        Found: Boolean;
        Cr: Char;
        Lf: Char;
    begin
        if CountTimeBlocks(Prompt) <> 1 then
            Error('LM98 requires exactly one source SESSION TIME block.');
        Cr := 13;
        Lf := 10;
        Normalized := Prompt.Replace(Format(Cr), '');
        Lines := Normalized.Split(Format(Lf));
        foreach Line in Lines do
            if not Found and Line.StartsWith('SESSION TIME (') then begin
                Builder.Append(Replacement);
                Builder.AppendLine();
                InBlock := true;
                Found := true;
            end else
                if InBlock then begin
                    if Line = '' then
                        InBlock := false;
                end else
                    Builder.AppendLine(Line);
        exit(Builder.ToText());
    end;

    /// <summary>Counts line-start headers rather than arbitrary quoted occurrences.</summary>
    procedure CountTimeBlocks(Prompt: Text) Count: Integer
    var
        Line: Text;
        Cr: Char;
        Lf: Char;
    begin
        Cr := 13;
        Lf := 10;
        foreach Line in Prompt.Replace(Format(Cr), '').Split(Format(Lf)) do
            if Line.StartsWith('SESSION TIME (') then
                Count += 1;
    end;

    local procedure FirstLine(Value: Text): Text
    var
        Cr: Char;
        Lf: Char;
    begin
        Cr := 13;
        Lf := 10;
        exit(Value.Replace(Format(Cr), '').Split(Format(Lf)).Get(1));
    end;

    local procedure ClockLine(Block: Text): Text
    var
        Cr: Char;
        Lf: Char;
        Line: Text;
    begin
        Cr := 13;
        Lf := 10;
        foreach Line in Block.Replace(Format(Cr), '').Split(Format(Lf)) do
            if Line.StartsWith('- Now UTC: ') then
                exit(Line);
        exit('');
    end;

    /// <summary>Observes blob isolation using two synthetic session blobs; wildcard is tested only in an otherwise empty store.</summary>
    procedure Blobs() Result: JsonObject
    var
        ChatRef: Text;
        RunRef: Text;
        Refs: List of [Text];
    begin
        if TryBlobs(Result, ChatRef, RunRef) then
            exit;
        // Retain partial observations, then clean only identities created before the failure.
        Refs := BlobRefs();
        if (RunRef <> '') and Refs.Contains(RunRef) then
            DeleteRef(RunRef);
        if (ChatRef <> '') and Refs.Contains(ChatRef) then
            DeleteRef(ChatRef);
        Refs := BlobRefs();
        Result.Remove('status');
        Result.Add('status', 'Failed');
        Result.Remove('ownedRefsAbsent');
        Result.Add('ownedRefsAbsent', not Refs.Contains(ChatRef) and not Refs.Contains(RunRef));
    end;

    [TryFunction]
    local procedure TryBlobs(var Result: JsonObject; var ChatRef: Text; var RunRef: Text)
    var
        Arguments: JsonObject;
        Response: Text;
        IsError: Boolean;
        InitialRefs: List of [Text];
        Refs: List of [Text];
    begin
        InitialRefs := BlobRefs();
        if InitialRefs.Count() <> 0 then begin
            Result.Add('status', 'NotRun');
            Result.Add('reason', 'Use a fresh isolated session; existing blobs must not be touched.');
            exit;
        end;
        // Warm Bootstrap before creating the simulated open-chat blob: its cold path clears the store.
        Response := ToolServer.Bootstrap('');
        ChatRef := StoreBlob('LM98 synthetic chat sentinel');
        RunRef := StoreBlob('LM98 synthetic run sentinel');
        Refs := BlobRefs();
        Result.Add('listBlobsShowsBoth', Refs.Contains(ChatRef) and Refs.Contains(RunRef));
        DeleteRef(RunRef);
        Arguments.Add('ref', ChatRef);
        ToolServer.CallTool('get_blob', Arguments, Response, IsError);
        Result.Add('scopedCleanupPreservesChat', not IsError and (Response = 'LM98 synthetic chat sentinel'));
        Refs := BlobRefs();
        Result.Add('runBlobRemoved', not Refs.Contains(RunRef));
        // Never issue '*' if a foreign blob appeared during the check.
        if (Refs.Count() = 1) and Refs.Contains(ChatRef) then begin
            Clear(Arguments);
            Arguments.ReadFrom('{"refs":["*"]}');
            ToolServer.CallTool('delete_blobs', Arguments, Response, IsError);
            Refs := BlobRefs();
            Result.Add('wildcardDeletesChatToo', (not IsError) and not Refs.Contains(ChatRef));
        end else begin
            Result.Add('wildcardNotRun', true);
            DeleteRef(ChatRef);
        end;
        Refs := BlobRefs();
        Result.Add('ownedRefsAbsent', not Refs.Contains(ChatRef) and not Refs.Contains(RunRef));
        Result.Add('status', 'Observed');
    end;

    local procedure StoreBlob(Content: Text): Text
    var
        Arguments: JsonObject;
        Response: JsonObject;
        ResponseText: Text;
        IsError: Boolean;
    begin
        Arguments.Add('content', Content);
        Arguments.Add('contentType', 'text/plain');
        ToolServer.CallTool('set_blob', Arguments, ResponseText, IsError);
        if IsError or not Response.ReadFrom(ResponseText) then
            Error('LM98 synthetic blob could not be created.');
        exit(Response.GetText('blobRef'));
    end;

    local procedure DeleteRef(Ref: Text)
    var
        Arguments: JsonObject;
        Refs: JsonArray;
        Response: Text;
        IsError: Boolean;
    begin
        if Ref = '' then
            exit;
        Refs.Add(Ref);
        Arguments.Add('refs', Refs);
        ToolServer.CallTool('delete_blobs', Arguments, Response, IsError);
        if IsError then
            Error('LM98 owned blob cleanup failed.');
    end;

    local procedure BlobRefs() Refs: List of [Text]
    var
        Arguments: JsonObject;
        Response: JsonObject;
        Entry: JsonToken;
        Entries: JsonToken;
        ResponseText: Text;
        IsError: Boolean;
    begin
        ToolServer.CallTool('list_blobs', Arguments, ResponseText, IsError);
        if IsError or not Response.ReadFrom(ResponseText) then
            Error('LM98 could not inspect session blob ownership.');
        if Response.Get('blobs', Entries) then
            foreach Entry in Entries.AsArray() do
                Refs.Add(Entry.AsObject().GetText('ref'));
    end;

    /// <summary>Lists registry tool names only. This is not evidence of an outgoing provider request.</summary>
    procedure ToolNames() Result: JsonObject
    var
        Registry: JsonArray;
        Names: JsonArray;
        Entry: JsonToken;
    begin
        ToolServer.ListTools(Registry);
        foreach Entry in Registry do
            Names.Add(Entry.AsObject().GetText('name'));
        Result.Add('registryNames', Names);
        Result.Add('outgoingRequestVerified', false);
        Result.Add('status', 'Observed');
    end;

    /// <summary>Extracts only tool names from an actual masked outgoing request, using Foundation's creator-isolated reader.</summary>
    procedure RequestTools(EntryNo: BigInteger) Result: JsonObject
    var
        Reader: Codeunit "Request Log Reader ori";
        Body: JsonObject;
        Entry: JsonToken;
        Entries: JsonToken;
        FunctionToken: JsonToken;
        Names: JsonArray;
        Name: Text;
    begin
        if not Body.ReadFrom(Reader.GetRequestBody(EntryNo)) then
            Error('LM98 request log body is not JSON.');
        if not Body.Get('tools', Entries) then
            Error('LM98 outgoing request has no tools array.');
        foreach Entry in Entries.AsArray() do begin
            if Entry.AsObject().Get('function', FunctionToken) then
                Name := Tools.GetText(FunctionToken.AsObject(), 'name')
            else
                Name := Tools.GetText(Entry.AsObject(), 'name');
            // Names are configuration metadata, never copy instructions, descriptions, inputs or tool results.
            Names.Add(Name);
        end;
        Result.Add('requestLogEntryNo', EntryNo);
        Result.Add('outgoingToolNames', Names);
        Result.Add('status', 'Observed');
    end;

    /// <summary>Runs the existing split interface, without transaction commits; only synthetic customers and read tools are accepted.</summary>
    procedure Live(Request: JsonObject) Result: JsonObject
    var
        Model: Record "Bifrost Language Model ori";
        TestContext: Codeunit "Bifrost LangModel Test Ctx ori";
        ChatProvider: Codeunit "LangModel Chat Provider ori";
        LiveAllowed: Boolean;
        Payload: JsonObject;
        Message: JsonObject;
        Messages: JsonArray;
        PayloadText: Text;
        AllowedNames: JsonArray;
        CustomerNo: Text;
        ModelCode: Text;
        StartedAt: DateTime;
        Refs: List of [Text];
        OwnedRefs: List of [Text];
        Ref: Text;
    begin
        CustomerNo := Tools.GetText(Request, 'customer');
        if not (CustomerNo in ['BIFT-A', 'BIFT-B', 'BIFT-C']) then
            Error('LM98 accepts only its three isolated synthetic customer numbers.');
        ModelCode := Tools.GetText(Request, 'code');
        if (ModelCode = '') or (StrLen(ModelCode) > MaxStrLen(Model.Code)) then
            Error('LM98 requires an existing test model code.');
        Model.Get(CopyStr(ModelCode, 1, MaxStrLen(Model.Code)));
        if not (Model."Chat Provider" in [Model."Chat Provider"::OpenAI, Model."Chat Provider"::Anthropic, Model."Chat Provider"::Mock]) then
            Error('LM98 live trial is restricted to OpenAI and Anthropic; Mock is for permission probes.');
        if Model."Chat Provider" <> Model."Chat Provider"::Mock then begin
            OnAuthorizeLive(LiveAllowed);
            if not LiveAllowed then
                Error('LM98 real provider calls require the separate guarded native live harness.');
        end;
        Refs := BlobRefs();
        if Refs.Count() > 0 then
            Error('LM98 live probe requires a fresh isolated session without existing blobs.');
        Message.Add('role', 'user');
        Message.Add('content', StrSubstNo('Is customer %1 configured correctly for posting sales invoices? Check the posting groups, the VAT business posting group, the payment terms, and that the posting groups have their accounts filled. Answer with a verdict of pass, fail or unknown and list each problem with the field name.', CustomerNo));
        Messages.Add(Message);
        Payload.Add('messages', Messages);
        AllowedNames.ReadFrom('["get_records","get_record_ids","get_record_count","get_totals","get_fields","search_tables","list_message_types","describe_message_type"]');
        Payload.Add('allowedToolNames', AllowedNames);
        Payload.Add('contextSkill', 'HEADLESS TRIAL: read-only tools only. Never write or change memory. Answer as JSON with verdict (pass, fail or unknown) and problemFields (field names only).');
        Payload.WriteTo(PayloadText);
        Result.Add('providerEnum', Model."Chat Provider".AsInteger());
        Result.Add('model', Model.Model);
        StartedAt := CurrentDateTime();
        TestContext.SetLanguageModel(Model.Code);
        ClearLastError();
        if not TryLive(ChatProvider, PayloadText, CustomerNo, Result, OwnedRefs) then begin
            // Provider errors can contain response bodies: never serialize GetLastErrorText here.
            if Model."Chat Provider" = Model."Chat Provider"::Mock then
                Result.Add('mockBcError', GetLastErrorText());
            Result.Remove('stopReason');
            Result.Add('stopReason', 'runtimeError');
            Result.Add('runtimeError', true);
        end;
        TestContext.ClearLanguageModel();
        // This run acquired an empty exclusive session; discover refs even if a tool failed after storing one.
        Refs := BlobRefs();
        foreach Ref in Refs do
            if not OwnedRefs.Contains(Ref) then
                OwnedRefs.Add(Ref);
        foreach Ref in OwnedRefs do
            if Refs.Contains(Ref) then
                DeleteRef(Ref);
        Refs := BlobRefs();
        Result.Add('remainingBlobCount', Refs.Count());
        Result.Add('ownedBlobCleanupVerified', Refs.Count() = 0);
        Result.Add('durationMs', CurrentDateTime() - StartedAt);
        Result.Add('status', 'Observed');
    end;

    [TryFunction]
    local procedure TryLive(var ChatProvider: Codeunit "LangModel Chat Provider ori"; PayloadText: Text; CustomerNo: Text; var Result: JsonObject; var OwnedRefs: List of [Text])
    var
        Answer: JsonObject;
        Calls: JsonToken;
        Call: JsonToken;
        CallObject: JsonObject;
        Arguments: JsonObject;
        ArgumentsToken: JsonToken;
        ToolResult: JsonObject;
        ToolResults: JsonArray;
        Usage: JsonToken;
        UsageValue: JsonToken;
        SafeUsage: JsonObject;
        UsageKey: Text;
        TokenCount: Integer;
        Reply: JsonObject;
        AnswerText: Text;
        ToolResultText: Text;
        ResultsText: Text;
        ToolName: Text;
        ArgumentsText: Text;
        ProviderCalls: Integer;
        ToolCalls: Integer;
        ToolErrors: Integer;
        Denied: Integer;
        LargestResult: Integer;
        IsError: Boolean;
    begin
        ToolCalls := 0;
        LargestResult := 0;
        Result.Add('historyCompactionFactLoss', 'not assessed');
        Result.Add('outgoingToolFilterVerified', false);
        ProviderCalls := 1;
        RecordCounters(Result, ProviderCalls, 0, 0, 0, 0);
        AnswerText := ChatProvider.SendChatMessage(PayloadText);
        while true do begin
            Clear(Answer);
            if not Answer.ReadFrom(AnswerText) then
                Error('LM98 provider did not return JSON.');
            if Answer.Contains('error') then
                Error('LM98 provider refused the request.');
            if Tools.GetText(Answer, 'type') <> 'tool_calls' then begin
                Result.Add('stopReason', 'reply');
                if Reply.ReadFrom(Tools.GetText(Answer, 'reply')) then
                    if Tools.GetText(Reply, 'verdict') in ['pass', 'fail', 'unknown'] then
                        Result.Add('verdict', Tools.GetText(Reply, 'verdict'));
                // Do not output free-text replies or field values. Human verifier inspects findings privately.
                Result.Add('replyChars', StrLen(Tools.GetText(Answer, 'reply')));
                if Answer.Get('usage', Usage) then
                    if Usage.IsObject() then begin
                        foreach UsageKey in Usage.AsObject().Keys() do
                            if UsageKey in ['prompt_tokens', 'completion_tokens', 'total_tokens', 'input_tokens', 'output_tokens'] then
                                if Usage.AsObject().Get(UsageKey, UsageValue) then
                                    if TryTokenCount(UsageValue, TokenCount) then
                                        if TokenCount >= 0 then
                                            SafeUsage.Add(UsageKey, TokenCount);
                        Result.Add('usage', SafeUsage);
                    end;
                break;
            end;
            if (ProviderCalls >= 10) or (ToolCalls >= 15) then begin
                Result.Add('stopReason', 'cap');
                break;
            end;
            Clear(ToolResults);
            if not Answer.Get('toolCalls', Calls) then
                Error('LM98 tool response has no calls.');
            foreach Call in Calls.AsArray() do begin
                if ToolCalls >= 15 then
                    break;
                ToolCalls += 1;
                CallObject := Call.AsObject();
                ToolName := Tools.GetText(CallObject, 'name');
                Clear(Arguments);
                if CallObject.Get('arguments', ArgumentsToken) then
                    Arguments := ArgumentsToken.AsObject();
                Arguments.WriteTo(ArgumentsText);
                if PrepareTool(ToolName, Arguments, CustomerNo) and not ArgumentsText.Contains('{{blob:') then begin
                    ToolServer.CallTool(ToolName, Arguments, ToolResultText, IsError);
                    CollectBlobRefs(ToolResultText, OwnedRefs);
                end else begin
                    Denied += 1;
                    IsError := true;
                    ToolResultText := '{"error":"denied by read-only trial policy"}';
                end;
                if IsError then
                    ToolErrors += 1;
                if StrLen(ToolResultText) > LargestResult then
                    LargestResult := StrLen(ToolResultText);
                RecordCounters(Result, ProviderCalls, ToolCalls, ToolErrors, Denied, LargestResult);
                Clear(ToolResult);
                ToolResult.Add('id', Tools.GetText(CallObject, 'id'));
                ToolResult.Add('result', ToolResultText);
                ToolResults.Add(ToolResult);
            end;
            if ToolCalls >= 15 then begin
                Result.Add('stopReason', 'cap');
                break;
            end;
            ToolResults.WriteTo(ResultsText);
            ProviderCalls += 1;
            RecordCounters(Result, ProviderCalls, ToolCalls, ToolErrors, Denied, LargestResult);
            AnswerText := ChatProvider.ContinueWithToolResults(Tools.GetText(Answer, 'conversationState'), ResultsText);
        end;
        RecordCounters(Result, ProviderCalls, ToolCalls, ToolErrors, Denied, LargestResult);
    end;

    [TryFunction]
    local procedure TryTokenCount(Value: JsonToken; var Count: Integer)
    begin
        Count := Value.AsValue().AsInteger();
    end;

    local procedure RecordCounters(var Result: JsonObject; Operations: Integer; Calls: Integer; Errors: Integer; Denied: Integer; Largest: Integer)
    begin
        Result.Remove('providerOperations');
        Result.Add('providerOperations', Operations);
        Result.Remove('toolCalls');
        Result.Add('toolCalls', Calls);
        Result.Remove('toolErrors');
        Result.Add('toolErrors', Errors);
        Result.Remove('deniedToolCalls');
        Result.Add('deniedToolCalls', Denied);
        Result.Remove('largestToolResultChars');
        Result.Add('largestToolResultChars', Largest);
    end;

    local procedure PrepareTool(Name: Text; var Arguments: JsonObject; CustomerNo: Text): Boolean
    var
        RecRef: RecordRef;
        Field: FieldRef;
        TableNo: Integer;
        OwnedFilter: Text;
        ExistingFilter: Text;
        TableName: Text;
    begin
        if Name in ['get_fields', 'search_tables', 'list_message_types', 'describe_message_type'] then
            exit(true);
        if not (Name in ['get_records', 'get_record_ids', 'get_record_count', 'get_totals']) then
            exit(false);
        TableName := Tools.GetText(Arguments, 'tableName').ToLower();
        case TableName of
            'customer', '18': TableNo := 18;
            'g/l account', '15': TableNo := 15;
            'customer posting group', '92': TableNo := 92;
            'general posting setup', '252': TableNo := 252;
            'gen. business posting group', '250': TableNo := 250;
            'gen. product posting group', '251': TableNo := 251;
            'vat business posting group', '323': TableNo := 323;
            'vat product posting group', '324': TableNo := 324;
            'vat posting setup', '325': TableNo := 325;
            'payment terms', '3': TableNo := 3;
            else exit(false);
        end;
        case TableNo of
            18: OwnedFilter := CustomerNo;
            92: OwnedFilter := 'BIFT-LM98|BIFT-NOREC';
            else OwnedFilter := 'BIFT-LM98';
        end;
        RecRef.Open(TableNo);
        RecRef.SetView(Tools.GetText(Arguments, 'tableView'));
        Field := RecRef.Field(1);
        ExistingFilter := Field.GetFilter();
        if ExistingFilter <> '' then
            Field.SetFilter('(' + ExistingFilter + ')&(' + OwnedFilter + ')')
        else
            Field.SetFilter(OwnedFilter);
        if TableNo in [252, 325] then begin
            Field := RecRef.Field(2);
            Field.SetRange('BIFT-LM98');
        end;
        Arguments.Remove('tableView');
        Arguments.Add('tableView', RecRef.GetView(false));
        RecRef.Close();
        exit(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAuthorizeLive(var Allowed: Boolean)
    begin
    end;

    local procedure CollectBlobRefs(Value: Text; var Refs: List of [Text])
    var
        StartAt: Integer;
        EndAt: Integer;
        Ref: Text;
    begin
        StartAt := StrPos(Value, '{{blob:');
        while StartAt > 0 do begin
            Value := CopyStr(Value, StartAt);
            EndAt := StrPos(Value, '}}');
            if EndAt = 0 then
                exit;
            Ref := CopyStr(Value, 1, EndAt + 1);
            if not Refs.Contains(Ref) then
                Refs.Add(Ref);
            Value := CopyStr(Value, EndAt + 2);
            StartAt := StrPos(Value, '{{blob:');
        end;
    end;
}
