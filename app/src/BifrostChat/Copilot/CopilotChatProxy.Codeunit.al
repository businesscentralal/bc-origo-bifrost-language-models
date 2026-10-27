namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.AI;
using System.Text;

/// <summary>
/// Runs the Copilot agentic tool loop. Calls Azure OpenAI via System.AI,
/// dispatches tool calls via the Core MCP Tool Server, feeds results back,
/// and repeats until the model produces a final answer.
/// </summary>
codeunit 10035393 "Copilot Chat Proxy ori"
{
    Access = Internal;

    var
        ToolServer: Codeunit "MCP Tool Server ori";
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        TurnGuard: Codeunit "LangModel Turn Guard ori";
        RequestLogger: Codeunit "Request Logger ori";
        UnexpectedErrorLbl: Label 'An unexpected error occurred while calling the Copilot model.', Comment = 'is-IS=Óvænt villa kom upp við kall á Copilot-líkanið.';
        MissingMessagesLbl: Label 'Payload must contain a messages array with at least one entry.', Comment = 'is-IS=Inntak verður að innihalda skilaboðalista með að minnsta kosti einu atriði.';
        SessionTimeMarker: Text const 'SESSION TIME';

    /// <summary>
    /// Runs a Copilot chat turn with bounded MCP tool iterations and returns reply or error JSON.
    /// </summary>
    [NonDebuggable]
    procedure SendChatMessage(PayloadJson: Text): Text
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        AOAIDeployments: Codeunit "AOAI Deployments";
        AOAIChatMessages: Codeunit "AOAI Chat Messages";
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
        PayloadObject: JsonObject;
        ToolTrace: JsonArray;
        SystemPrompt: Text;
        Reply: Text;
        ResponseJson: Text;
        Iteration: Integer;
        MaxIterations: Integer;
        StartTime: DateTime;
        FiguresVerified: Boolean;
    begin
        StartTime := CurrentDateTime();

        if not PayloadObject.ReadFrom(PayloadJson) then
            exit(BuildErrorResponse('Invalid payload JSON.'));

        if not HasMessages(PayloadObject) then
            exit(BuildErrorResponse(MissingMessagesLbl));

        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::"Bifrost Chat ori");
        AzureOpenAI.SetManagedResourceAuthorization(Enum::"AOAI Model Type"::"Chat Completions", AOAIDeployments.GetGPT41Latest());

        SystemPrompt := BuildSystemPrompt(PayloadObject);
        AOAIChatMessages.SetPrimarySystemMessage(SystemPrompt);
        ParseMessages(PayloadObject, AOAIChatMessages);
        AddToolDefinitions(AOAIChatMessages);
        // AOAI Chat Messages sends only the last 10 messages by default, which drops the question in a turn with several
        // tool calls; the history is kept for the whole loop instead (#40).
        AOAIChatMessages.SetHistoryLength(CopilotHistoryLength());
        AOAIChatCompletionParams.SetMaxTokens(4096);

        MaxIterations := 25;
        for Iteration := 1 to MaxIterations do begin
            AzureOpenAI.GenerateChatCompletion(AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);

            if not AOAIOperationResponse.IsSuccess() then begin
                ResponseJson := BuildErrorResponse(GetErrorOrFallback(AOAIOperationResponse));
                LogRequest('ChatCompletion', SystemPrompt, ResponseJson, false, GetErrorOrFallback(AOAIOperationResponse), StartTime);
                exit(ResponseJson);
            end;

            if not AOAIOperationResponse.IsFunctionCall() then begin
                Reply := AOAIChatMessages.GetLastMessage();
                // Figures stated without a tool call in this turn get one follow-up asking the model to verify them (#40).
                if (ToolTrace.Count() = 0) and (not FiguresVerified) and TurnGuard.ContainsFigures(Reply) then begin
                    FiguresVerified := true;
                    AOAIChatMessages.AddUserMessage(TurnGuard.GetVerifyFiguresPrompt());
                    continue;
                end;
                ResponseJson := BuildSuccessResponse(Reply, ToolTrace);
                LogRequest('ChatCompletion', SystemPrompt, ResponseJson, true, '', StartTime);
                exit(ResponseJson);
            end;

            ExecuteToolCalls(AOAIOperationResponse, AOAIChatMessages, ToolTrace);
        end;

        Reply := AOAIChatMessages.GetLastMessage();
        ResponseJson := BuildSuccessResponse(Reply, ToolTrace);
        LogRequest('ChatCompletion', SystemPrompt, ResponseJson, true, '', StartTime);
        exit(ResponseJson);
    end;

    local procedure BuildSystemPrompt(PayloadObject: JsonObject) SystemPrompt: Text
    var
        PromptBuilder: TextBuilder;
        BootstrapPrompt: Text;
        RecordContextToken: JsonToken;
        RecordContext: Text;
        UserSkill: Text;
    begin
        BootstrapPrompt := ToolServer.Bootstrap('');
        PromptBuilder.Append(BootstrapPrompt);

        // The block is rebuilt on every request (#85). It is added only when Foundation's Bootstrap does not
        // carry it already, so one session never sees two blocks (paired core story adds it to Bootstrap later).
        if StrPos(BootstrapPrompt, SessionTimeMarker) = 0 then begin
            PromptBuilder.AppendLine();
            PromptBuilder.Append(BuildSessionTimeBlock(CurrentDateTime(), UtcOffsetSeconds(), GetTimezone(), WorkDate()));
        end;

        if PayloadObject.Get('recordContext', RecordContextToken) then begin
            RecordContextToken.WriteTo(RecordContext);
            if RecordContext <> '' then begin
                PromptBuilder.AppendLine();
                PromptBuilder.AppendLine();
                PromptBuilder.AppendLine('RECORD CONTEXT:');
                PromptBuilder.AppendLine(RecordContext);
                PromptBuilder.AppendLine('When the user refers to the current page record, use its tableId and recordSystemId with get_records to fetch data.');
            end;
        end;

        // The user's own prompt is not appended here: Foundation's Bootstrap carries it once, under USER INSTRUCTIONS (#40, core#157).

        UserSkill := GetTextProperty(PayloadObject, 'contextSkill');
        if UserSkill <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine('SKILL REFERENCE:');
            PromptBuilder.Append(UserSkill);
        end;

        SystemPrompt := PromptBuilder.ToText();
    end;

    /// <summary>
    /// Builds the SESSION TIME block from explicit inputs so tests never depend on the wall clock (#85).
    /// The label text is a model instruction, not user-facing: English only, no XLF entry (story AC11).
    /// </summary>
    procedure BuildSessionTimeBlock(NowUtc: DateTime; UtcOffset: Duration; TimeZoneName: Text; WorkDate: Date) Block: Text
    var
        BlockBuilder: TextBuilder;
        LocalDateTime: DateTime;
        TodayDate: Date;
        NowLocal: Text;
    begin
        TodayDate := LocalToday(NowUtc, UtcOffset);
        BlockBuilder.AppendLine(SessionTimeMarker + ' (as of this request; use it for every relative date, never guess today):');
        BlockBuilder.AppendLine('- Now UTC: ' + Format(NowUtc, 0, 0, 0, 0, 0, 0, 9) + 'Z');
        if TimeZoneName <> '' then begin
            LocalDateTime := NowUtc + UtcOffset;
            TodayDate := LocalDateOf(LocalDateTime);
            NowLocal := Format(LocalDateTime, 0, 0, 0, 0, 0, 0, 9);
            BlockBuilder.AppendLine(Format('- Now user time (%1, %2): %3', [TimeZoneName, IsoUtcOffset(UtcOffset), NowLocal]));
            BlockBuilder.AppendLine(Format('- Today: %1 %2', [Format(TodayDate, 0, 0, 0, 0, 0, 0, 9), WeekdayName(TodayDate)]));
        end else
            BlockBuilder.AppendLine(Format('- Today: %1 %2 (UTC; the user''s time zone is unknown)', [Format(TodayDate, 0, 0, 0, 0, 0, 0, 9), WeekdayName(TodayDate)]));
        if WorkDate <> TodayDate then
            BlockBuilder.AppendLine(Format('- Work date: %1 (differs from today; use it for posting dates the user did not specify)', [Format(WorkDate, 0, 0, 0, 0, 0, 0, 9)]));
        BlockBuilder.AppendLine('- Weeks start on Monday. This week = most recent Monday through today. Last N days = N days ending today, inclusive (today minus N-1 through today). This month = the 1st of the current month through today. Last month = the whole previous calendar month. State the exact dates you used in your answer.');
        BlockBuilder.AppendLine('- Use ISO dates from this block when you build tableView date filters. Do not call a tool to learn today''s date.');
        Block := BlockBuilder.ToText();
    end;

    /// <summary>
    /// Today's date in the user's local time zone for a UTC instant and offset (#85).
    /// </summary>
    local procedure LocalToday(NowUtc: DateTime; UtcOffset: Duration) Today: Date
    begin
        exit(LocalDateOf(NowUtc + UtcOffset));
    end;

    /// <summary>
    /// The calendar date of a local (non-UTC) date-time value (#85).
    /// </summary>
    local procedure LocalDateOf(LocalDateTime: DateTime) Day: Date
    var
        LocalYear: Integer;
        LocalMonth: Integer;
        LocalDate: Integer;
    begin
        Date2DMY(LocalDateTime, LocalYear, LocalMonth, LocalDate);
        exit(DMY2Date(LocalDate, LocalMonth, LocalYear));
    end;

    /// <summary>
    /// English weekday name, fixed list indexed by Date2DWY day-of-week (1 = Sunday); never a culture-dependent
    /// Format, so the block is identical at lcid 1033 and 1039 (#85).
    /// </summary>
    local procedure WeekdayName(Day: Date) Name: Text
    var
        WeekdayNo: Integer;
    begin
        Date2DWY(Day, 0, WeekdayNo);
        if WeekdayNo = 1 then
            exit('Sunday');
        if WeekdayNo = 2 then
            exit('Monday');
        if WeekdayNo = 3 then
            exit('Tuesday');
        if WeekdayNo = 4 then
            exit('Wednesday');
        if WeekdayNo = 5 then
            exit('Thursday');
        if WeekdayNo = 6 then
            exit('Friday');
        exit('Saturday');
    end;

    /// <summary>
    /// Numeric UTC offset such as +01:00 or -05:00, built from minutes so it is locale-independent (#85).
    /// </summary>
    local procedure IsoUtcOffset(UtcOffset: Duration) OffsetText: Text
    var
        TotalMinutes: Integer;
        AbsMinutes: Integer;
        Sign: Text;
    begin
        TotalMinutes := UtcOffset.Minutes;
        Sign := '+';
        if TotalMinutes < 0 then begin
            Sign := '-';
            AbsMinutes := -TotalMinutes;
        end else
            AbsMinutes := TotalMinutes;
        exit(Format('%1%2%3', [Sign, Format(DivRound(AbsMinutes, 60), 0, 0, 0, 0, 0, 2, 0), Format(AbsMinutes mod 60, 0, 0, 0, 0, 0, 2, 0)]));
    end;

    /// <summary>
    /// The UTC offset of the current session time zone in seconds; 0 when the zone is unknown (#85).
    /// </summary>
    local procedure UtcOffsetSeconds(): Duration
    var
        Zone: Text;
        Offset: Duration;
    begin
        Zone := GetTimezone();
        if Zone = '' then
            exit(CreateDuration(0, 0, 0, 0));
        exit(Offset := CurrentUtcOffset());
    end;

    local procedure CopilotHistoryLength(): Integer
    begin
        exit(100);
    end;

    local procedure AddToolDefinitions(var AOAIChatMessages: Codeunit "AOAI Chat Messages")
    var
        ServerTools: JsonArray;
        ToolToken: JsonToken;
        ToolObject: JsonObject;
        SchemaToken: JsonToken;
        EmptySchema: JsonObject;
        ToolName: Text;
        ToolDescription: Text;
        ToolCount: Integer;
    begin
        ToolCount := 0;
        AOAIChatMessages.SetToolInvokePreference(Enum::"AOAI Tool Invoke Preference"::Manual);
        ToolServer.ListTools(ServerTools);
        foreach ToolToken in ServerTools do begin
            if ToolCount >= MaxToolsPerRequest() then
                break;
            ToolObject := ToolToken.AsObject();
            ToolName := GetTextProperty(ToolObject, 'name');
            ToolDescription := GetTextProperty(ToolObject, 'description');

            Clear(EmptySchema);
            if ToolObject.Get('inputSchema', SchemaToken) then
                if SchemaToken.IsObject() then
                    EmptySchema := SchemaToken.AsObject();

            RegisterTool(AOAIChatMessages, ToolName, ToolDescription, EmptySchema);
            ToolCount += 1;
        end;
    end;

    local procedure RegisterTool(var AOAIChatMessages: Codeunit "AOAI Chat Messages"; ToolName: Text; ToolDescription: Text; Schema: JsonObject)
    var
        ToolImpl: Codeunit "Copilot AOAI Func Impl ori";
    begin
        ToolImpl.SetToolData(ToolName, ToolDescription, Schema);
        AOAIChatMessages.AddTool(ToolImpl);
    end;

    local procedure ExecuteToolCalls(var AOAIOperationResponse: Codeunit "AOAI Operation Response"; var AOAIChatMessages: Codeunit "AOAI Chat Messages"; var ToolTrace: JsonArray)
    var
        AOAIFunctionResponse: Codeunit "AOAI Function Response";
        FunctionName: Text;
        Arguments: JsonObject;
        ArgumentsText: Text;
        ToolCallId: Text;
        ToolResult: Text;
        IsError: Boolean;
        TraceEntry: JsonObject;
    begin
        foreach AOAIFunctionResponse in AOAIOperationResponse.GetFunctionResponses() do begin
            FunctionName := AOAIFunctionResponse.GetFunctionName();
            Arguments := AOAIFunctionResponse.GetArguments();
            ToolCallId := AOAIFunctionResponse.GetFunctionId();

            ToolServer.CallTool(FunctionName, Arguments, ToolResult, IsError);
            ToolResult := ChatUtils.TruncateContent(ToolResult, 0);
            AOAIChatMessages.AddToolMessage(ToolCallId, FunctionName, ToolResult);

            Arguments.WriteTo(ArgumentsText);
            Clear(TraceEntry);
            TraceEntry.Add('tool', FunctionName);
            TraceEntry.Add('input', ArgumentsText);
            TraceEntry.Add('output', ShortenForTrace(ToolResult));
            ToolTrace.Add(TraceEntry);
        end;
    end;

    local procedure ParseMessages(PayloadObject: JsonObject; var AOAIChatMessages: Codeunit "AOAI Chat Messages")
    var
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
        MessageObject: JsonObject;
        Role: Text;
        Content: Text;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit;
        if not MessagesToken.IsArray() then
            exit;

        foreach MessageToken in MessagesToken.AsArray() do begin
            MessageObject := MessageToken.AsObject();
            Role := GetTextProperty(MessageObject, 'role');
            Content := GetTextProperty(MessageObject, 'content');
            case Role of
                'user':
                    AOAIChatMessages.AddUserMessage(Content);
                'assistant':
                    AOAIChatMessages.AddAssistantMessage(Content);
            end;
        end;
    end;

    local procedure BuildSuccessResponse(Reply: Text; ToolTrace: JsonArray): Text
    var
        Response: JsonObject;
    begin
        Response.Add('type', 'reply');
        Response.Add('reply', Reply);
        if ToolTrace.Count() > 0 then
            Response.Add('toolTrace', ToolTrace);
        exit(JsonToText(Response));
    end;

    local procedure BuildErrorResponse(ErrorMessage: Text): Text
    var
        Response: JsonObject;
    begin
        Response.Add('error', ErrorMessage);
        exit(JsonToText(Response));
    end;

    local procedure LogRequest(Operation: Text[50]; RequestBody: Text; ResponseBody: Text; IsSuccess: Boolean; ErrorText: Text; StartTime: DateTime)
    var
        Setup: Record "Setup ori";
    begin
        if not Setup.GetRequestDebugMode() then
            exit;

        RequestLogger.Log(
            Operation,
            'POST',
            'copilot://managed/chat-completions',
            'Copilot',
            200,
            CurrentDateTime() - StartTime,
            IsSuccess,
            ErrorText,
            RequestBody,
            ResponseBody,
            Enum::"Request Log Type ori"::"Copilot");
        RequestLogger.Insert();
    end;

    local procedure MaxToolsPerRequest(): Integer
    begin
        exit(20);
    end;

    local procedure GetErrorOrFallback(var AOAIOperationResponse: Codeunit "AOAI Operation Response"): Text
    var
        ErrorText: Text;
    begin
        ErrorText := AOAIOperationResponse.GetError();
        if ErrorText = '' then begin
            ErrorText := GetLastErrorText();
            if ErrorText = '' then
                exit(UnexpectedErrorLbl);
        end;
        exit(ErrorText);
    end;

    local procedure GetTextProperty(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ShortenForTrace(Value: Text): Text
    begin
        if StrLen(Value) <= 500 then
            exit(Value);
        exit(CopyStr(Value, 1, 497) + '...');
    end;

    local procedure JsonToText(Source: JsonObject): Text
    var
        Result: Text;
    begin
        Source.WriteTo(Result);
        exit(Result);
    end;

    local procedure HasMessages(PayloadObject: JsonObject): Boolean
    var
        MessagesToken: JsonToken;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit(false);
        if not MessagesToken.IsArray() then
            exit(false);
        exit(MessagesToken.AsArray().Count() > 0);
    end;
}
