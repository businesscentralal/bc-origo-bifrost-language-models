namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// The headless loop of LLM.Prompt.Ask (#101): sends the question, runs the read-only tool calls the model asks for
/// through Foundation's MCP Tool Server, applies the mandatory caps (D5), forces a final answer at a cap, validates an
/// optional response schema with one retry, and builds the response. No wall-clock timeout (D3), no write tools (D2),
/// and the trace is returned only, never stored (D7). The API key stamp is written once, after the loop (R1).
/// </summary>
codeunit 10035433 "LLM Ask Runner ori"
{
    Access = Internal;

    var
        AskPolicy: Codeunit "LLM Ask Tool Policy ori";
        ToolServer: Codeunit "MCP Tool Server ori";
        Provider: Interface "Bifrost LangModel Provider ori";
        CallerTools: JsonObject;
        ResponseSchema: JsonObject;
        HasSchema: Boolean;
        IncludeTrace: Boolean;
        MaxToolCalls: Integer;
        MaxRounds: Integer;
        MaxResultChars: Integer;
        Rounds: Integer;
        ToolCallCount: Integer;
        ToolErrorCount: Integer;
        DeniedCount: Integer;
        Usage: JsonObject;
        HasUsage: Boolean;
        Trace: JsonArray;
        Warnings: List of [Text];
        RunBlobRefs: List of [Text];
        AllowedToolNames: List of [Text];
        ProviderFailed: Boolean;
        ProviderFailure: JsonObject;
        DefaultMaxToolCalls: Integer;
        DefaultMaxRounds: Integer;
        DefaultMaxResultChars: Integer;
        HeadlessModeTxt: Label 'HEADLESS MODE:\No human is present in this conversation and nobody will read a question you ask. Never ask a question back. Never state that an action was done unless a tool result shows it. Answer only from tool results and the context you were given. When you are not sure, say unknown. Tool results older than the last five are shortened later, so note what you need from a result as soon as you read it. All tools are read-only.', Locked = true;
        InstructionsHeaderTxt: Label 'CALLER INSTRUCTIONS:', Locked = true;
        OutputFormatTxt: Label 'OUTPUT FORMAT:\Answer with one JSON value only, with no prose and no code fence, that matches this JSON schema:', Locked = true;
        LimitReachedTxt: Label '{"error":"limit reached: this tool call was not run. Answer now from the results you already have, without tools."}', Locked = true;
        DeniedResultTxt: Label '{"error":"%1"}', Comment = '%1 = reason', Locked = true;
        AnswerNowTxt: Label 'The tool limit of this session is reached. Answer the question now from the tool results you already have. Do not call any tool.', Locked = true;
        SchemaRetryTxt: Label 'Your answer did not match the required JSON schema: %1 Answer again with one JSON value only that matches the schema.', Comment = '%1 = validation errors', Locked = true;
        TruncatedMarkerTxt: Label '...[truncated by Bifrost: %1 of %2 characters shown]', Comment = '%1 = shown, %2 = total', Locked = true;
        SchemaTypeTxt: Label '%1 must be of type %2.', Comment = '%1 = JSON path, %2 = type', Locked = true;
        SchemaEnumTxt: Label '%1 is not one of the allowed values.', Comment = '%1 = JSON path', Locked = true;
        SchemaRequiredTxt: Label '%1.%2 is required.', Comment = '%1 = JSON path, %2 = property', Locked = true;
        QuestionHeaderTxt: Label 'QUESTION:', Locked = true;
        ContextHeaderTxt: Label 'CONTEXT:', Locked = true;

    /// <summary>
    /// Sets the provider, tools, limits, schema and trace option of the run. Limits above a cap are clamped with a warning.
    /// </summary>
    procedure Initialize(NewProvider: Interface "Bifrost LangModel Provider ori"; NewCallerTools: JsonObject; RequestedToolCalls: Integer; RequestedRounds: Integer; RequestedResultChars: Integer; NewSchema: JsonObject; NewHasSchema: Boolean; NewIncludeTrace: Boolean)
    begin
        Provider := NewProvider;
        CallerTools := NewCallerTools;
        ResponseSchema := NewSchema;
        HasSchema := NewHasSchema;
        IncludeTrace := NewIncludeTrace;
        DefaultMaxToolCalls := 15;
        DefaultMaxRounds := 10;
        DefaultMaxResultChars := 8000;
        MaxToolCalls := ClampLimit('maxToolCalls', RequestedToolCalls, DefaultMaxToolCalls, 40);
        MaxRounds := ClampLimit('maxRounds', RequestedRounds, DefaultMaxRounds, 20);
        MaxResultChars := ClampLimit('maxResultChars', RequestedResultChars, DefaultMaxResultChars, 20000);
    end;

    /// <summary>
    /// Adds a warning text to the response.
    /// </summary>
    procedure AddWarning(WarningText: Text)
    begin
        if not Warnings.Contains(WarningText) then
            Warnings.Add(WarningText);
    end;

    /// <summary>
    /// Returns the supported schema keywords; any other keyword is ignored with a warning.
    /// </summary>
    procedure CheckSchemaKeywords(Schema: JsonObject)
    var
        KeyName: Text;
        Token: JsonToken;
        PropertyToken: JsonToken;
        PropertyName: Text;
    begin
        foreach KeyName in Schema.Keys() do begin
            if not (KeyName in ['type', 'properties', 'required', 'enum', 'items', 'description', 'title', '$schema']) then
                AddWarning('schemaKeywordIgnored:' + KeyName);
            if KeyName = 'properties' then
                if Schema.Get(KeyName, Token) then
                    if Token.IsObject() then
                        foreach PropertyName in Token.AsObject().Keys() do
                            if Token.AsObject().Get(PropertyName, PropertyToken) then
                                if PropertyToken.IsObject() then
                                    CheckSchemaKeywords(PropertyToken.AsObject());
            if KeyName = 'items' then
                if Schema.Get(KeyName, Token) then
                    if Token.IsObject() then
                        CheckSchemaKeywords(Token.AsObject());
        end;
    end;

    /// <summary>
    /// Builds the system suffix: HEADLESS MODE, the caller instructions and, when a schema was sent, OUTPUT FORMAT.
    /// </summary>
    procedure BuildSystemSuffix(Instructions: Text) Suffix: Text
    var
        Builder: TextBuilder;
        SchemaText: Text;
    begin
        Builder.Append(HeadlessModeTxt.Replace('\', NewLine()));
        if Instructions <> '' then begin
            Builder.Append(NewLine() + NewLine());
            Builder.Append(InstructionsHeaderTxt + NewLine());
            Builder.Append(Instructions);
        end;
        if HasSchema then begin
            ResponseSchema.WriteTo(SchemaText);
            Builder.Append(NewLine() + NewLine());
            Builder.Append(OutputFormatTxt.Replace('\', NewLine()) + NewLine());
            Builder.Append(SchemaText);
        end;
        Suffix := Builder.ToText();
    end;

    /// <summary>
    /// Builds the user message: QUESTION and, when given, CONTEXT. The context stays out of the system text.
    /// </summary>
    procedure BuildUserMessage(Question: Text; ContextText: Text) Content: Text
    begin
        Content := QuestionHeaderTxt + NewLine() + Question;
        if ContextText <> '' then
            Content += NewLine() + NewLine() + ContextHeaderTxt + NewLine() + ContextText;
    end;

    /// <summary>
    /// Runs the loop for the prepared chat argument and returns the response. Provider failures leave ProviderFailed set.
    /// </summary>
    [NonDebuggable]
    procedure Run(var TempChatArg: Record "Bifrost Chat Argument ori" temporary; SystemSuffix: Text; UserContent: Text; RecordContext: JsonObject; HasRecordContext: Boolean; var Result: JsonObject): Boolean
    var
        ServerTools: JsonArray;
        Payload: JsonObject;
        Messages: JsonArray;
        Answer: JsonObject;
        AnswerText: Text;
        PayloadText: Text;
        ReplyText: Text;
        StopReason: Text;
        ValidationErrors: Text;
        Data: JsonToken;
        SchemaValid: Boolean;
        CapReached: Boolean;
        ToolWarnings: List of [Text];
        WarningText: Text;
    begin
        ToolServer.ListTools(ServerTools);
        AskPolicy.GetAllowedToolNames(ServerTools, CallerTools, AllowedToolNames, ToolWarnings);
        foreach WarningText in ToolWarnings do
            AddWarning(WarningText);

        AddMessage(Messages, 'user', UserContent);
        Payload := BuildPayload(Messages, SystemSuffix, RecordContext, HasRecordContext, AllowedToolNames);
        Payload.WriteTo(PayloadText);
        if not SendRound(TempChatArg, PayloadText, Answer) then
            exit(false);

        while IsToolCallAnswer(Answer) do begin
            CapReached := false;
            AnswerText := RunToolCalls(Answer, CapReached);
            if CapReached or (Rounds >= MaxRounds) then begin
                if CapReached then
                    StopReason := 'maxToolCalls'
                else
                    StopReason := 'maxRounds';
                if not ContinueRound(TempChatArg, ForceFinalState(GetText(Answer, 'conversationState')), AddAnswerNow(AnswerText), Answer) then
                    exit(false);
                if IsToolCallAnswer(Answer) then
                    // The model asked for tools after the forced final round: no answer text exists.
                    Clear(Answer);
                break;
            end;
            if not ContinueRound(TempChatArg, GetText(Answer, 'conversationState'), AnswerText, Answer) then
                exit(false);
        end;
        if StopReason = '' then
            StopReason := 'completed';
        ReplyText := GetText(Answer, 'reply');
        if ReplyText = '' then
            ReplyText := GetText(Answer, 'text');

        if HasSchema then begin
            SchemaValid := ValidateAnswer(ReplyText, Data, ValidationErrors);
            if not SchemaValid then begin
                // One retry: a new SendChatMessage carrying the question, the reply and the validation errors.
                AddMessage(Messages, 'assistant', ReplyText);
                AddMessage(Messages, 'user', StrSubstNo(SchemaRetryTxt, ValidationErrors));
                Clear(AllowedToolNames);
                Payload := BuildPayload(Messages, SystemSuffix, RecordContext, HasRecordContext, AllowedToolNames);
                Payload.WriteTo(PayloadText);
                if not SendRound(TempChatArg, PayloadText, Answer) then
                    exit(false);
                ReplyText := GetText(Answer, 'reply');
                SchemaValid := ValidateAnswer(ReplyText, Data, ValidationErrors);
                if not SchemaValid then
                    StopReason := 'schemaInvalid';
            end;
        end;

        Result.Add('status', 'Success');
        Result.Add('answer', ReplyText);
        if HasSchema then begin
            if SchemaValid then
                Result.Add('data', Data);
            Result.Add('schemaValid', SchemaValid);
        end;
        Result.Add('stopReason', StopReason);
        AddCounters(Result);
        exit(true);
    end;

    /// <summary>
    /// Adds the counters, usage, warnings and (when requested) the trace to a response.
    /// </summary>
    procedure AddCounters(var Result: JsonObject)
    var
        WarningsArray: JsonArray;
        WarningText: Text;
    begin
        Result.Add('toolCalls', ToolCallCount);
        Result.Add('toolErrors', ToolErrorCount);
        Result.Add('deniedToolCalls', DeniedCount);
        Result.Add('rounds', Rounds);
        if HasUsage then
            Result.Add('usage', Usage);
        foreach WarningText in Warnings do
            WarningsArray.Add(WarningText);
        Result.Add('warnings', WarningsArray);
        if IncludeTrace then
            Result.Add('trace', Trace);
    end;

    /// <summary>
    /// True when the last provider request failed; GetProviderFailure returns the provider error response.
    /// </summary>
    procedure HasProviderFailure(): Boolean
    begin
        exit(ProviderFailed);
    end;

    /// <summary>
    /// Returns the provider error response of a failed run, for LangModel Prov. Base ori.RespondPromptError.
    /// </summary>
    procedure GetProviderFailure(): JsonObject
    begin
        exit(ProviderFailure);
    end;

    /// <summary>
    /// Deletes the blobs this run created, by explicit id; never all blobs.
    /// </summary>
    procedure DeleteRunBlobs()
    var
        Arguments: JsonObject;
        Ids: JsonArray;
        BlobRef: Text;
        ResultText: Text;
        IsError: Boolean;
    begin
        if RunBlobRefs.Count() = 0 then
            exit;
        foreach BlobRef in RunBlobRefs do
            if BlobRef <> '*' then
                Ids.Add(BlobRef);
        if Ids.Count() = 0 then
            exit;
        Arguments.Add('ids', Ids);
        ToolServer.CallTool('delete_blobs', Arguments, ResultText, IsError);
    end;

    /// <summary>
    /// Returns the blob references the run recorded.
    /// </summary>
    procedure GetRunBlobRefs(): List of [Text]
    begin
        exit(RunBlobRefs);
    end;

    local procedure BuildPayload(Messages: JsonArray; SystemSuffix: Text; RecordContext: JsonObject; HasRecordContext: Boolean; Names: List of [Text]) Payload: JsonObject
    begin
        Payload.Add('messages', Messages.Clone());
        if SystemSuffix <> '' then
            Payload.Add('systemSuffix', SystemSuffix);
        if HasRecordContext then
            Payload.Add('recordContext', RecordContext);
        AskPolicy.WriteAllowedTools(Names, Payload);
    end;

    local procedure RunToolCalls(Answer: JsonObject; var CapReached: Boolean) ResultsText: Text
    var
        Results: JsonArray;
        ResultObject: JsonObject;
        CallsToken: JsonToken;
        CallToken: JsonToken;
        CallObject: JsonObject;
        ArgumentsToken: JsonToken;
        Arguments: JsonObject;
        ToolName: Text;
        ToolResultText: Text;
        Reason: Text;
        StartedAt: DateTime;
        IsError: Boolean;
        Denied: Boolean;
    begin
        if Answer.Get('toolCalls', CallsToken) then
            if CallsToken.IsArray() then
                foreach CallToken in CallsToken.AsArray() do
                    if CallToken.IsObject() then begin
                        CallObject := CallToken.AsObject();
                        ToolName := GetText(CallObject, 'name');
                        Clear(Arguments);
                        if CallObject.Get('arguments', ArgumentsToken) then
                            if ArgumentsToken.IsObject() then
                                Arguments := ArgumentsToken.AsObject();
                        IsError := false;
                        Denied := false;
                        StartedAt := CurrentDateTime();
                        if CapReached or (ToolCallCount >= MaxToolCalls) then begin
                            CapReached := true;
                            ToolResultText := LimitReachedTxt;
                        end else begin
                            ToolCallCount += 1;
                            if not AskPolicy.CheckToolCall(ToolName, Arguments, CallerTools, Reason) then begin
                                Denied := true;
                                IsError := true;
                                DeniedCount += 1;
                                ToolResultText := StrSubstNo(DeniedResultTxt, Reason.Replace('"', '\"'));
                            end else begin
                                ToolServer.CallTool(ToolName, Arguments, ToolResultText, IsError);
                                if not IsError then
                                    IsError := IsErrorResult(ToolResultText);
                                CollectBlobRefs(ToolResultText);
                                if IsError then
                                    ToolErrorCount += 1;
                            end;
                        end;
                        AddTrace(ToolName, Arguments, IsError, Denied, CurrentDateTime() - StartedAt, ToolResultText);
                        Clear(ResultObject);
                        ResultObject.Add('id', GetText(CallObject, 'id'));
                        ResultObject.Add('result', Truncate(ToolResultText, MaxResultChars));
                        Results.Add(ResultObject);
                    end;
        if (not CapReached) and (ToolCallCount >= MaxToolCalls) then
            CapReached := true;
        Results.WriteTo(ResultsText);
    end;

    local procedure IsErrorResult(ResultText: Text): Boolean
    var
        ResultObject: JsonObject;
    begin
        // Foundation answers some refusals (unknown table, no permission, quota) as an error body without the isError flag.
        if not ResultObject.ReadFrom(ResultText) then
            exit(false);
        if ResultObject.Contains('error') then
            exit(true);
        exit(GetText(ResultObject, 'status') = 'Error');
    end;

    local procedure ForceFinalState(StateText: Text): Text
    var
        StateObject: JsonObject;
        NoTools: List of [Text];
    begin
        if not StateObject.ReadFrom(StateText) then
            exit(StateText);
        StateObject.Remove('allowedTools');
        AskPolicy.WriteAllowedTools(NoTools, StateObject);
        StateObject.WriteTo(StateText);
        exit(StateText);
    end;

    local procedure AddAnswerNow(ResultsText: Text): Text
    var
        Results: JsonArray;
        LastToken: JsonToken;
        LastResult: JsonObject;
        ResultText: Text;
    begin
        // The instruction rides on the last tool result: a chat history accepts no other message between the calls and their results.
        if not Results.ReadFrom(ResultsText) then
            exit(ResultsText);
        if Results.Count() = 0 then
            exit(ResultsText);
        Results.Get(Results.Count() - 1, LastToken);
        LastResult := LastToken.AsObject();
        ResultText := GetText(LastResult, 'result') + ' ' + AnswerNowTxt;
        LastResult.Replace('result', ResultText);
        Results.Set(Results.Count() - 1, LastResult);
        Results.WriteTo(ResultsText);
        exit(ResultsText);
    end;

    [NonDebuggable]
    local procedure SendRound(var TempChatArg: Record "Bifrost Chat Argument ori" temporary; PayloadText: Text; var Answer: JsonObject): Boolean
    begin
        Rounds += 1;
        TempChatArg.SetPayload(PayloadText);
        TempChatArg.SetResultText('');
        TempChatArg."Procedure Type" := TempChatArg."Procedure Type"::SendChatMessage;
        exit(ExecuteRound(TempChatArg, Answer));
    end;

    [NonDebuggable]
    local procedure ContinueRound(var TempChatArg: Record "Bifrost Chat Argument ori" temporary; StateText: Text; ToolResultsText: Text; var Answer: JsonObject): Boolean
    begin
        Rounds += 1;
        TempChatArg.SetConversationState(StateText);
        TempChatArg.SetToolResults(ToolResultsText);
        TempChatArg.SetResultText('');
        TempChatArg."Procedure Type" := TempChatArg."Procedure Type"::ContinueWithToolResults;
        exit(ExecuteRound(TempChatArg, Answer));
    end;

    [NonDebuggable]
    local procedure ExecuteRound(var TempChatArg: Record "Bifrost Chat Argument ori" temporary; var Answer: JsonObject): Boolean
    var
        ErrorToken: JsonToken;
    begin
        Clear(Answer);
        if not TryExecute(TempChatArg) then begin
            ClearLastError();
            ProviderFailed := true;
            exit(false);
        end;
        if not Answer.ReadFrom(TempChatArg.GetResultText()) then begin
            ProviderFailed := true;
            exit(false);
        end;
        if Answer.Get('error', ErrorToken) then begin
            ProviderFailed := true;
            ProviderFailure := Answer;
            exit(false);
        end;
        AddUsage(Answer);
        exit(true);
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TryExecute(var TempChatArg: Record "Bifrost Chat Argument ori" temporary)
    begin
        Provider.Execute(TempChatArg);
    end;

    local procedure IsToolCallAnswer(Answer: JsonObject): Boolean
    begin
        exit(GetText(Answer, 'type') = 'tool_calls');
    end;

    local procedure AddUsage(Answer: JsonObject)
    var
        UsageToken: JsonToken;
        ValueToken: JsonToken;
        ExistingToken: JsonToken;
        KeyName: Text;
        Value: Integer;
        Existing: Integer;
    begin
        if not Answer.Get('usage', UsageToken) then
            exit;
        if not UsageToken.IsObject() then
            exit;
        foreach KeyName in UsageToken.AsObject().Keys() do
            if UsageToken.AsObject().Get(KeyName, ValueToken) then
                if TryReadInteger(ValueToken, Value) then begin
                    Existing := 0;
                    if Usage.Get(KeyName, ExistingToken) then
                        if TryReadInteger(ExistingToken, Existing) then;
                    Usage.Remove(KeyName);
                    Usage.Add(KeyName, Existing + Value);
                    HasUsage := true;
                end;
    end;

    [TryFunction]
    local procedure TryReadInteger(Token: JsonToken; var Value: Integer)
    begin
        Value := Token.AsValue().AsInteger();
    end;

    local procedure AddTrace(ToolName: Text; Arguments: JsonObject; IsError: Boolean; Denied: Boolean; Duration: Duration; ResultText: Text)
    var
        Entry: JsonObject;
        ArgumentsText: Text;
    begin
        if not IncludeTrace then
            exit;
        Arguments.WriteTo(ArgumentsText);
        Entry.Add('round', Rounds);
        Entry.Add('tool', ToolName);
        Entry.Add('args', Truncate(ArgumentsText, 500));
        Entry.Add('isError', IsError);
        Entry.Add('denied', Denied);
        Entry.Add('ms', Duration);
        Entry.Add('resultChars', StrLen(ResultText));
        Entry.Add('preview', Truncate(ResultText, 200));
        Trace.Add(Entry);
    end;

    local procedure CollectBlobRefs(Value: Text)
    var
        StartAt: Integer;
        EndAt: Integer;
        BlobRef: Text;
        BlobId: Text;
    begin
        StartAt := StrPos(Value, '{{blob:');
        while StartAt > 0 do begin
            Value := CopyStr(Value, StartAt);
            EndAt := StrPos(Value, '}}');
            if EndAt = 0 then
                exit;
            BlobRef := CopyStr(Value, 1, EndAt + 1);
            BlobId := CopyStr(BlobRef, 8, StrLen(BlobRef) - 9);
            if (BlobId <> '') and (BlobId <> '*') and (not RunBlobRefs.Contains(BlobId)) then begin
                RunBlobRefs.Add(BlobId);
                AskPolicy.RegisterRunBlob(BlobRef);
            end;
            Value := CopyStr(Value, EndAt + 2);
            StartAt := StrPos(Value, '{{blob:');
        end;
    end;

    local procedure Truncate(Value: Text; MaxChars: Integer): Text
    begin
        if (MaxChars <= 0) or (StrLen(Value) <= MaxChars) then
            exit(Value);
        exit(CopyStr(Value, 1, MaxChars) + StrSubstNo(TruncatedMarkerTxt, MaxChars, StrLen(Value)));
    end;

    local procedure ClampLimit(KeyName: Text; Requested: Integer; DefaultValue: Integer; Cap: Integer): Integer
    begin
        if Requested <= 0 then
            exit(DefaultValue);
        if Requested > Cap then begin
            AddWarning('clamped:' + KeyName);
            exit(Cap);
        end;
        exit(Requested);
    end;

    local procedure ValidateAnswer(ReplyText: Text; var Data: JsonToken; var Errors: Text): Boolean
    var
        JsonText: Text;
    begin
        Errors := '';
        Clear(Data);
        JsonText := ExtractJson(ReplyText);
        if not Data.ReadFrom(JsonText) then begin
            Errors := 'The answer is not JSON.';
            exit(false);
        end;
        ValidateNode(Data, ResponseSchema, '$', Errors);
        exit(Errors = '');
    end;

    /// <summary>
    /// Extracts the JSON value from an answer that wraps it in prose or a code fence.
    /// </summary>
    procedure ExtractJson(ReplyText: Text): Text
    var
        FenceStart: Integer;
        FenceEnd: Integer;
        FirstBrace: Integer;
        FirstBracket: Integer;
        StartAt: Integer;
        EndAt: Integer;
        Rest: Text;
    begin
        FenceStart := StrPos(ReplyText, '```');
        if FenceStart > 0 then begin
            Rest := CopyStr(ReplyText, FenceStart + 3);
            if StrPos(Rest, NewLine()) > 0 then
                Rest := CopyStr(Rest, StrPos(Rest, NewLine()) + 1);
            FenceEnd := StrPos(Rest, '```');
            if FenceEnd > 0 then
                exit(CopyStr(Rest, 1, FenceEnd - 1).Trim());
        end;
        FirstBrace := StrPos(ReplyText, '{');
        FirstBracket := StrPos(ReplyText, '[');
        StartAt := FirstBrace;
        if (FirstBracket > 0) and ((StartAt = 0) or (FirstBracket < StartAt)) then
            StartAt := FirstBracket;
        if StartAt = 0 then
            exit(ReplyText.Trim());
        if CopyStr(ReplyText, StartAt, 1) = '{' then
            EndAt := LastPos(ReplyText, '}')
        else
            EndAt := LastPos(ReplyText, ']');
        if EndAt < StartAt then
            exit(ReplyText.Trim());
        exit(CopyStr(ReplyText, StartAt, EndAt - StartAt + 1));
    end;

    local procedure LastPos(Value: Text; Character: Text): Integer
    var
        Index: Integer;
    begin
        for Index := StrLen(Value) downto 1 do
            if CopyStr(Value, Index, 1) = Character then
                exit(Index);
        exit(0);
    end;

    local procedure ValidateNode(Node: JsonToken; Schema: JsonObject; Path: Text; var Errors: Text)
    var
        TypeName: Text;
        Token: JsonToken;
        ChildToken: JsonToken;
        RequiredToken: JsonToken;
        PropertyName: Text;
        Index: Integer;
    begin
        TypeName := GetText(Schema, 'type');
        if (TypeName <> '') and (not MatchesType(Node, TypeName)) then begin
            AppendSchemaError(Errors, StrSubstNo(SchemaTypeTxt, Path, TypeName));
            exit;
        end;
        if Schema.Get('enum', Token) then
            if Token.IsArray() then
                if not EnumContains(Token.AsArray(), Node) then
                    AppendSchemaError(Errors, StrSubstNo(SchemaEnumTxt, Path));
        if Node.IsObject() then begin
            if Schema.Get('required', RequiredToken) then
                if RequiredToken.IsArray() then
                    foreach ChildToken in RequiredToken.AsArray() do
                        if ChildToken.IsValue() then
                            if not Node.AsObject().Contains(ChildToken.AsValue().AsText()) then
                                AppendSchemaError(Errors, StrSubstNo(SchemaRequiredTxt, Path, ChildToken.AsValue().AsText()));
            if Schema.Get('properties', Token) then
                if Token.IsObject() then
                    foreach PropertyName in Token.AsObject().Keys() do
                        if Node.AsObject().Get(PropertyName, ChildToken) then
                            if Token.AsObject().Get(PropertyName, RequiredToken) then
                                if RequiredToken.IsObject() then
                                    ValidateNode(ChildToken, RequiredToken.AsObject(), Path + '.' + PropertyName, Errors);
        end;
        if Node.IsArray() then
            if Schema.Get('items', Token) then
                if Token.IsObject() then
                    for Index := 0 to Node.AsArray().Count() - 1 do
                        if Node.AsArray().Get(Index, ChildToken) then
                            ValidateNode(ChildToken, Token.AsObject(), Path + '[' + Format(Index, 0, 9) + ']', Errors);
    end;

    local procedure MatchesType(Node: JsonToken; TypeName: Text): Boolean
    var
        JsonText: Text;
        DecimalValue: Decimal;
    begin
        case TypeName of
            'object':
                exit(Node.IsObject());
            'array':
                exit(Node.IsArray());
        end;
        if not Node.IsValue() then
            exit(false);
        if Node.AsValue().IsNull() then
            exit(TypeName = 'null');
        Node.WriteTo(JsonText);
        case TypeName of
            'string':
                exit(JsonText.StartsWith('"'));
            'boolean':
                exit(JsonText in ['true', 'false']);
            'number':
                exit(Evaluate(DecimalValue, JsonText, 9));
            'integer':
                exit(Evaluate(DecimalValue, JsonText, 9) and (DecimalValue = Round(DecimalValue, 1)));
            'null':
                exit(false);
        end;
        exit(true);
    end;

    local procedure EnumContains(Allowed: JsonArray; Node: JsonToken): Boolean
    var
        AllowedToken: JsonToken;
        AllowedText: Text;
        NodeText: Text;
    begin
        Node.WriteTo(NodeText);
        foreach AllowedToken in Allowed do begin
            AllowedToken.WriteTo(AllowedText);
            if AllowedText = NodeText then
                exit(true);
        end;
        exit(false);
    end;

    local procedure AppendSchemaError(var Errors: Text; ErrorText: Text)
    begin
        if Errors <> '' then
            Errors += ' ';
        Errors += ErrorText;
    end;

    local procedure AddMessage(var Messages: JsonArray; Role: Text; Content: Text)
    var
        MessageObject: JsonObject;
    begin
        MessageObject.Add('role', Role);
        MessageObject.Add('content', Content);
        Messages.Add(MessageObject);
    end;

    local procedure GetText(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
        JsonText: Text;
    begin
        if not Source.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        Token.WriteTo(JsonText);
        if not JsonText.StartsWith('"') then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure NewLine(): Text
    var
        Lf: Text[1];
    begin
        Lf[1] := 10;
        exit(Lf);
    end;
}
