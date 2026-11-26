namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>
/// Answers only the reserved X171 example.invalid fixture endpoint without any outbound request (#171 MCP check).
/// Two tool rounds with xAI-sized usage (cost_in_usd_ticks 1.5e9 each, input 2e9 each), then a reply; on the /fail/ path
/// the second round answers HTTP 503. The first round sends tool arguments that are not a JSON object.
/// </summary>
codeunit 96087 "LLM 171 MCP Fixture"
{
    Access = Internal;

    var
        FixtureUrlTok: Label 'https://example.invalid/x171-fixture/', Locked = true;
        FailPathTok: Label 'https://example.invalid/x171-fixture/fail/', Locked = true;
        UsageTok: Label '"usage":{"prompt_tokens":2000000000,"completion_tokens":10,"cost_in_usd_ticks":1500000000}', Locked = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforePromptPost', '', false, false)]
    local procedure Prompt(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
        if not Url.StartsWith(FixtureUrlTok) then
            exit;
        Handled := true;
        Sent := true;
        HttpBlocked := false;
        Answer(Url, RequestBody, HttpStatus, ResponseText);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforeChatPostWithStatus', '', false, false)]
    local procedure Chat(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var HttpStatus: Integer; var ResponseText: Text)
    begin
        if not Url.StartsWith(FixtureUrlTok) then
            exit;
        Handled := true;
        Answer(Url, RequestBody, HttpStatus, ResponseText);
    end;

    local procedure Answer(Url: Text; RequestBody: JsonObject; var HttpStatus: Integer; var ResponseText: Text)
    var
        ToolMessages: Integer;
    begin
        HttpStatus := 200;
        ToolMessages := CountToolMessages(RequestBody);
        case true of
            ToolMessages = 0:
                ResponseText := '{"choices":[{"message":{"role":"assistant","content":null,"tool_calls":[' +
                    '{"id":"x171a","type":"function","function":{"name":"who_am_i","arguments":"[1,2]"}},' +
                    '{"id":"x171b","type":"function","function":{"name":"who_am_i","arguments":"42"}}]},"finish_reason":"tool_calls"}],' + UsageTok + '}';
            (ToolMessages = 2) and Url.StartsWith(FailPathTok):
                begin
                    HttpStatus := 503;
                    ResponseText := '{"error":{"message":"X171 fixture unavailable."}}';
                end;
            ToolMessages = 2:
                ResponseText := '{"choices":[{"message":{"role":"assistant","content":null,"tool_calls":[' +
                    '{"id":"x171c","type":"function","function":{"name":"who_am_i","arguments":"{}"}}]},"finish_reason":"tool_calls"}],' + UsageTok + '}';
            else
                ResponseText := '{"choices":[{"message":{"role":"assistant","content":"X171 fixture complete."},"finish_reason":"stop"}],' + UsageTok + '}';
        end;
    end;

    local procedure CountToolMessages(RequestBody: JsonObject) ToolMessages: Integer
    var
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
        RoleToken: JsonToken;
    begin
        if not RequestBody.Get('messages', MessagesToken) then
            exit(0);
        if not MessagesToken.IsArray() then
            exit(0);
        foreach MessageToken in MessagesToken.AsArray() do
            if MessageToken.IsObject() then
                if MessageToken.AsObject().Get('role', RoleToken) then
                    if RoleToken.IsValue() then
                        if RoleToken.AsValue().AsText() = 'tool' then
                            ToolMessages += 1;
    end;
}
