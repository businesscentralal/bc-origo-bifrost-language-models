namespace Origo.Bifrost.LanguageModels;

using System.Utilities;

/// <summary>
/// Shared rules of one chat turn for every provider path (#40): the history budget derived from the language
/// model's context size, the repair of tool messages whose partner was trimmed away, and the check that catches a
/// final reply stating figures although no tool was called in the turn. The turn is the last plain user message and
/// everything after it, the same turn Foundation's TrimMessageHistory protects. It reads the three message formats
/// the providers send: Chat Completions (role tool, assistant tool_calls), Responses (function_call and
/// function_call_output items) and Anthropic Messages (tool_use and tool_result content blocks).
/// </summary>
codeunit 10035425 "LangModel Turn Guard ori"
{
    Access = Internal;

    var
        VerifyFiguresPromptTxt: Label 'You stated figures without fetching data in this turn. Verify them with a tool, or say that you cannot verify them.', Locked = true;

    /// <summary>
    /// The character budget for the conversation history of one request: what is left of the model's context after the
    /// reply (MaxTokens) and the tool definitions, converted at 3.5 characters per token, minus a 10 % margin.
    /// </summary>
    /// <param name="ContextTokens">The model's context size in tokens; 0 or less uses 32,000.</param>
    /// <param name="MaxTokens">The tokens reserved for the reply.</param>
    /// <param name="ToolDefinitions">The tool definitions sent with the request.</param>
    /// <returns>The budget in characters, never below the budget of 2,000 tokens.</returns>
    procedure HistoryBudgetChars(ContextTokens: Integer; MaxTokens: Integer; ToolDefinitions: JsonArray): Integer
    var
        ToolsText: Text;
        AvailableTokens: Integer;
    begin
        if ContextTokens <= 0 then
            ContextTokens := FallbackContextTokens();
        AvailableTokens := ContextTokens - MaxTokens;
        if ToolDefinitions.Count() > 0 then begin
            ToolDefinitions.WriteTo(ToolsText);
            AvailableTokens -= Round(StrLen(ToolsText) / 3.5, 1, '>');
        end;
        if AvailableTokens < MinimumHistoryTokens() then
            AvailableTokens := MinimumHistoryTokens();
        exit(Round(AvailableTokens * 3.5 * 0.9, 1, '<'));
    end;

    /// <summary>
    /// The context size used when neither the language model nor its provider names one.
    /// </summary>
    procedure FallbackContextTokens(): Integer
    begin
        exit(32000);
    end;

    /// <summary>
    /// Removes Chat Completions tool messages that lost their partner: a tool message whose tool_call_id no earlier
    /// assistant tool_calls entry carries, and the tool_calls of an assistant message whose results are gone (the
    /// assistant message is kept when it has text, otherwise it is removed). Strict gateways refuse such a request.
    /// </summary>
    /// <param name="Messages">The Chat Completions messages, changed in place.</param>
    procedure RemoveOrphanedToolMessages(var Messages: JsonArray)
    var
        CalledIds: List of [Text];
        AnsweredIds: List of [Text];
        Kept: JsonArray;
        MessageToken: JsonToken;
        MessageObject: JsonObject;
        Role: Text;
    begin
        CollectChatToolIds(Messages, CalledIds, AnsweredIds);
        foreach MessageToken in Messages do begin
            MessageObject := MessageToken.AsObject();
            Role := GetText(MessageObject, 'role');
            case true of
                Role = 'tool':
                    if CalledIds.Contains(GetText(MessageObject, 'tool_call_id')) then
                        Kept.Add(MessageToken);
                (Role = 'assistant') and MessageObject.Contains('tool_calls'):
                    if AllToolCallsAnswered(MessageObject, AnsweredIds) then
                        Kept.Add(MessageToken)
                    else
                        if GetText(MessageObject, 'content') <> '' then begin
                            MessageObject.Remove('tool_calls');
                            Kept.Add(MessageObject);
                        end;
                else
                    Kept.Add(MessageToken);
            end;
        end;
        Messages := Kept;
    end;

    /// <summary>
    /// Removes Responses input items that lost their partner: a function_call_output whose call_id no function_call
    /// carries, and a function_call that has no function_call_output.
    /// </summary>
    /// <param name="Input">The Responses input items, changed in place.</param>
    procedure RemoveOrphanedResponsesItems(var Input: JsonArray)
    var
        CalledIds: List of [Text];
        AnsweredIds: List of [Text];
        Kept: JsonArray;
        ItemToken: JsonToken;
        ItemObject: JsonObject;
    begin
        foreach ItemToken in Input do
            if ItemToken.IsObject() then begin
                ItemObject := ItemToken.AsObject();
                case GetText(ItemObject, 'type') of
                    'function_call':
                        CalledIds.Add(GetText(ItemObject, 'call_id'));
                    'function_call_output':
                        AnsweredIds.Add(GetText(ItemObject, 'call_id'));
                end;
            end;
        foreach ItemToken in Input do
            if not ItemToken.IsObject() then
                Kept.Add(ItemToken)
            else begin
                ItemObject := ItemToken.AsObject();
                case GetText(ItemObject, 'type') of
                    'function_call':
                        if AnsweredIds.Contains(GetText(ItemObject, 'call_id')) then
                            Kept.Add(ItemToken);
                    'function_call_output':
                        if CalledIds.Contains(GetText(ItemObject, 'call_id')) then
                            Kept.Add(ItemToken);
                    else
                        Kept.Add(ItemToken);
                end;
            end;
        Input := Kept;
    end;

    /// <summary>
    /// Tells whether a final reply needs the one verification follow-up: it states figures, no tool was called in the
    /// current turn, and the follow-up was not already sent in this turn.
    /// </summary>
    /// <param name="Messages">The conversation in any of the three formats, including the reply.</param>
    /// <param name="Reply">The text of the final reply.</param>
    procedure NeedsFigureCheck(Messages: JsonArray; Reply: Text): Boolean
    var
        TurnStart: Integer;
    begin
        if not ContainsFigures(Reply) then
            exit(false);
        TurnStart := FindTurnStart(Messages);
        if TurnUsedTools(Messages, TurnStart) then
            exit(false);
        exit(not VerifyPromptSent(Messages, TurnStart));
    end;

    /// <summary>
    /// Tells whether a reply states something that looks like an amount: a number of four or more digits, or a number
    /// with a thousands or decimal separator (1.234 / 1,234 / 12,50).
    /// </summary>
    /// <param name="Reply">The reply text.</param>
    procedure ContainsFigures(Reply: Text): Boolean
    var
        Regex: Codeunit Regex;
    begin
        if Reply = '' then
            exit(false);
        exit(Regex.IsMatch(Reply, '\d{4,}|\d+[.,]\d+'));
    end;

    /// <summary>
    /// The follow-up sent to the model when a reply states figures without a tool call in the turn.
    /// </summary>
    procedure GetVerifyFiguresPrompt(): Text
    begin
        exit(VerifyFiguresPromptTxt);
    end;

    /// <summary>
    /// The index of the last plain user message: role user with text content, not a carrier of tool results and not
    /// the verification follow-up. 0 when there is none.
    /// </summary>
    procedure FindTurnStart(Messages: JsonArray): Integer
    var
        MessageToken: JsonToken;
        MessageObject: JsonObject;
        Index: Integer;
    begin
        for Index := Messages.Count() - 1 downto 0 do begin
            Messages.Get(Index, MessageToken);
            if MessageToken.IsObject() then begin
                MessageObject := MessageToken.AsObject();
                if IsPlainUserMessage(MessageObject) then
                    exit(Index);
            end;
        end;
        exit(0);
    end;

    /// <summary>
    /// Tells whether any tool was called from TurnStart on: a tool message, assistant tool_calls, a Responses
    /// function_call or function_call_output, or an Anthropic tool_use or tool_result block.
    /// </summary>
    procedure TurnUsedTools(Messages: JsonArray; TurnStart: Integer): Boolean
    var
        MessageToken: JsonToken;
        MessageObject: JsonObject;
        Index: Integer;
    begin
        for Index := TurnStart to Messages.Count() - 1 do begin
            Messages.Get(Index, MessageToken);
            if MessageToken.IsObject() then begin
                MessageObject := MessageToken.AsObject();
                if GetText(MessageObject, 'role') = 'tool' then
                    exit(true);
                if MessageObject.Contains('tool_calls') then
                    exit(true);
                if GetText(MessageObject, 'type') in ['function_call', 'function_call_output'] then
                    exit(true);
                if HasContentBlock(MessageObject, 'tool_use') or HasContentBlock(MessageObject, 'tool_result') then
                    exit(true);
            end;
        end;
        exit(false);
    end;

    local procedure VerifyPromptSent(Messages: JsonArray; TurnStart: Integer): Boolean
    var
        MessageToken: JsonToken;
        Index: Integer;
    begin
        for Index := TurnStart to Messages.Count() - 1 do begin
            Messages.Get(Index, MessageToken);
            if MessageToken.IsObject() then
                if IsVerifyPrompt(MessageToken.AsObject()) then
                    exit(true);
        end;
        exit(false);
    end;

    local procedure IsPlainUserMessage(MessageObject: JsonObject): Boolean
    begin
        if GetText(MessageObject, 'role') <> 'user' then
            exit(false);
        if HasContentBlock(MessageObject, 'tool_result') then
            exit(false);
        exit(not IsVerifyPrompt(MessageObject));
    end;

    local procedure IsVerifyPrompt(MessageObject: JsonObject): Boolean
    begin
        if GetText(MessageObject, 'role') <> 'user' then
            exit(false);
        exit(GetText(MessageObject, 'content') = VerifyFiguresPromptTxt);
    end;

    local procedure HasContentBlock(MessageObject: JsonObject; BlockType: Text): Boolean
    var
        ContentToken: JsonToken;
        BlockToken: JsonToken;
    begin
        if not MessageObject.Get('content', ContentToken) then
            exit(false);
        if not ContentToken.IsArray() then
            exit(false);
        foreach BlockToken in ContentToken.AsArray() do
            if BlockToken.IsObject() then
                if GetText(BlockToken.AsObject(), 'type') = BlockType then
                    exit(true);
        exit(false);
    end;

    local procedure CollectChatToolIds(Messages: JsonArray; var CalledIds: List of [Text]; var AnsweredIds: List of [Text])
    var
        MessageToken: JsonToken;
        MessageObject: JsonObject;
        CallsToken: JsonToken;
        CallToken: JsonToken;
    begin
        foreach MessageToken in Messages do begin
            MessageObject := MessageToken.AsObject();
            if GetText(MessageObject, 'role') = 'tool' then
                AnsweredIds.Add(GetText(MessageObject, 'tool_call_id'));
            if MessageObject.Get('tool_calls', CallsToken) then
                if CallsToken.IsArray() then
                    foreach CallToken in CallsToken.AsArray() do
                        if CallToken.IsObject() then
                            CalledIds.Add(GetText(CallToken.AsObject(), 'id'));
        end;
    end;

    local procedure AllToolCallsAnswered(MessageObject: JsonObject; AnsweredIds: List of [Text]): Boolean
    var
        CallsToken: JsonToken;
        CallToken: JsonToken;
    begin
        MessageObject.Get('tool_calls', CallsToken);
        if not CallsToken.IsArray() then
            exit(true);
        foreach CallToken in CallsToken.AsArray() do
            if CallToken.IsObject() then
                if not AnsweredIds.Contains(GetText(CallToken.AsObject(), 'id')) then
                    exit(false);
        exit(true);
    end;

    local procedure MinimumHistoryTokens(): Integer
    begin
        exit(2000);
    end;

    local procedure GetText(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Source.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
