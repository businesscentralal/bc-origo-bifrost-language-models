namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>
/// Test.LanguageModel.Chat - runs one Bifrost Chat turn against the named language model through the same path the
/// chat control add-in uses: "LangModel Chat Provider ori".SendChatMessage, then, for every tool_calls answer, each tool
/// through Foundation's "MCP Tool Server ori".CallTool and "LangModel Chat Provider ori".ContinueWithToolResults, until
/// the model replies or maxToolRounds is reached. The model is chosen through "Bifrost LangModel Test Ctx ori" (as the
/// card's Test Connection does), so no user setup is changed. Request: { "code", "prompt" or "messages", "recordContext"
/// (object, optional), "maxToolRounds" (default 8, at most 20) }. Answer: { status, code, chatProvider, reply, rounds,
/// toolCalls: [ { round, name, isError, resultChars } ], usage }. Each tool round is committed first, as each round of
/// the add-in is its own request; the tools run as the caller. Test app only; refused in SaaS production.
/// </summary>
codeunit 96026 "Test LangModel Chat Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Tools: Codeunit "LangModel Test Tools";
        MissingCodeErr: Label 'Send "code", the language model to chat with.', Locked = true;
        UnknownCodeErr: Label 'Language model "%1" was not found.', Comment = '%1 = code', Locked = true;
        MissingPromptErr: Label 'Send "prompt" (text) or "messages" (the conversation as an array of {role, content}).', Locked = true;
        ProviderErrorErr: Label 'The language model answered with an error: %1', Comment = '%1 = provider error', Locked = true;
        UnexpectedAnswerErr: Label 'The language model returned an answer that is neither a reply nor tool calls: %1', Comment = '%1 = answer', Locked = true;
        RoundsExceededErr: Label 'The model still asked for tools after %1 rounds.', Comment = '%1 = rounds', Locked = true;

    /// <summary>
    /// Reports that this test-only message type is enabled.
    /// </summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>
    /// Returns the language model table number used by this test-only message type.
    /// </summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Bifrost Language Model ori");
    end;

    /// <summary>
    /// Describes the test-only language model chat operation.
    /// </summary>
    procedure GetDescription(): Text[250]
    begin
        exit('TEST ONLY: runs one Bifrost Chat turn against a language model, tool calls included, through the same path as the chat add-in.');
    end;

    /// <summary>
    /// Returns Outbound for this test-only message type.
    /// </summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>
    /// Runs a language model chat turn with bounded tool rounds after refusing production execution.
    /// </summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        LanguageModel: Record "Bifrost Language Model ori";
        TestCtx: Codeunit "Bifrost LangModel Test Ctx ori";
        RequestJson: JsonObject;
        ModelCode: Text;
        MaxRounds: Integer;
    begin
        if not Tools.AssertNotProduction(Argument) then
            exit;

        RequestJson := Argument.GetRequestJson();
        ModelCode := UpperCase(Tools.GetText(RequestJson, 'code'));
        if ModelCode = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingCodeErr, 'code', '', 'a language model code', '');
            exit;
        end;
        if (StrLen(ModelCode) > MaxStrLen(LanguageModel.Code)) or not LanguageModel.Get(CopyStr(ModelCode, 1, MaxStrLen(LanguageModel.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownCodeErr, ModelCode), 'code', ModelCode, 'the code of a language model', 'Create it with Test.LanguageModel.Set.');
            exit;
        end;
        if not (Tools.Has(RequestJson, 'prompt') or Tools.Has(RequestJson, 'messages')) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingPromptErr, 'prompt', '', 'a prompt or a messages array', '');
            exit;
        end;

        MaxRounds := 8;
        if Tools.Has(RequestJson, 'maxToolRounds') then
            MaxRounds := RequestJson.GetInteger('maxToolRounds');
        if MaxRounds < 1 then
            MaxRounds := 1;
        if MaxRounds > 20 then
            MaxRounds := 20;

        TestCtx.SetLanguageModel(LanguageModel.Code);
        RunTurn(Argument, LanguageModel, BuildPayload(RequestJson), MaxRounds);
        TestCtx.ClearLanguageModel();
    end;

    local procedure RunTurn(var Argument: Record "Message Argument ori"; var LanguageModel: Record "Bifrost Language Model ori"; PayloadJson: Text; MaxRounds: Integer)
    var
        ChatProvider: Codeunit "LangModel Chat Provider ori";
        Answer: JsonObject;
        ToolTrace: JsonArray;
        AnswerText: Text;
        ToolResultsJson: Text;
        Round: Integer;
    begin
        AnswerText := ChatProvider.SendChatMessage(PayloadJson);
        Round := 0;
        while true do begin
            if not Answer.ReadFrom(AnswerText) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(UnexpectedAnswerErr, CopyStr(AnswerText, 1, 500)), 'code', LanguageModel.Code, 'a reply or tool calls', '');
                exit;
            end;
            if Tools.Has(Answer, 'error') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ProviderErrorErr, Tools.GetText(Answer, 'error')), 'code', LanguageModel.Code, 'a reply from the language model', 'Check the endpoint, model and API key of the language model.');
                exit;
            end;
            if Tools.GetText(Answer, 'type') <> 'tool_calls' then begin
                RespondWithReply(Argument, LanguageModel, Answer, ToolTrace, Round);
                exit;
            end;
            Round += 1;
            if Round > MaxRounds then begin
                Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, StrSubstNo(RoundsExceededErr, MaxRounds), 'maxToolRounds', Format(MaxRounds, 0, 9), 'a higher maxToolRounds (at most 20)', '');
                exit;
            end;
            ToolResultsJson := RunToolCalls(Answer, Round, ToolTrace);
            AnswerText := ChatProvider.ContinueWithToolResults(Tools.GetText(Answer, 'conversationState'), ToolResultsJson);
        end;
    end;

    local procedure RunToolCalls(Answer: JsonObject; Round: Integer; var ToolTrace: JsonArray) ToolResultsJson: Text
    var
        ToolServer: Codeunit "MCP Tool Server ori";
        CallsToken: JsonToken;
        CallToken: JsonToken;
        ArgumentsToken: JsonToken;
        CallObject: JsonObject;
        Arguments: JsonObject;
        ToolResult: JsonObject;
        TraceEntry: JsonObject;
        ToolResults: JsonArray;
        ResultText: Text;
        IsError: Boolean;
    begin
        // Each round of the chat add-in is its own request; a tool runs its message type with Codeunit.Run, which
        // needs a committed transaction (the provider may have written its request log).
        Commit();
        if Answer.Get('toolCalls', CallsToken) and CallsToken.IsArray() then
            foreach CallToken in CallsToken.AsArray() do begin
                CallObject := CallToken.AsObject();
                Clear(Arguments);
                if CallObject.Get('arguments', ArgumentsToken) and ArgumentsToken.IsObject() then
                    Arguments := ArgumentsToken.AsObject();
                Clear(ResultText);
                ToolServer.CallTool(Tools.GetText(CallObject, 'name'), Arguments, ResultText, IsError);

                Clear(ToolResult);
                ToolResult.Add('id', Tools.GetText(CallObject, 'id'));
                ToolResult.Add('result', ResultText);
                ToolResults.Add(ToolResult);

                Clear(TraceEntry);
                TraceEntry.Add('round', Round);
                TraceEntry.Add('name', Tools.GetText(CallObject, 'name'));
                TraceEntry.Add('isError', IsError);
                TraceEntry.Add('resultChars', StrLen(ResultText));
                ToolTrace.Add(TraceEntry);
            end;
        ToolResults.WriteTo(ToolResultsJson);
    end;

    local procedure RespondWithReply(var Argument: Record "Message Argument ori"; var LanguageModel: Record "Bifrost Language Model ori"; Answer: JsonObject; ToolTrace: JsonArray; Rounds: Integer)
    var
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('code', LanguageModel.Code);
        ResponseJson.Add('chatProvider', Enum::"Bifrost LangModel Prov. ori".Names().Get(Enum::"Bifrost LangModel Prov. ori".Ordinals().IndexOf(LanguageModel."Chat Provider".AsInteger())));
        ResponseJson.Add('reply', Tools.GetText(Answer, 'reply'));
        ResponseJson.Add('rounds', Rounds);
        ResponseJson.Add('toolCalls', ToolTrace);
        // Copilot runs its tool loop inside the provider and reports it as toolTrace.
        if Answer.Get('toolTrace', Token) then
            ResponseJson.Add('providerToolTrace', Token);
        if Answer.Get('usage', Token) then
            ResponseJson.Add('usage', Token);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildPayload(RequestJson: JsonObject) PayloadJson: Text
    var
        Payload: JsonObject;
        Messages: JsonArray;
        UserMessage: JsonObject;
        Token: JsonToken;
    begin
        if RequestJson.Get('messages', Token) and Token.IsArray() then
            Messages := Token.AsArray()
        else begin
            UserMessage.Add('role', 'user');
            UserMessage.Add('content', Tools.GetText(RequestJson, 'prompt'));
            Messages.Add(UserMessage);
        end;
        Payload.Add('messages', Messages);
        if RequestJson.Get('recordContext', Token) and Token.IsObject() then
            Payload.Add('recordContext', Token);
        Payload.WriteTo(PayloadJson);
    end;
}
