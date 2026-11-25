namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>Answers only the reserved X168 example.invalid fixture endpoint without any outbound request.</summary>
codeunit 96085 "LLM 168 MCP Fixture"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforePromptPost', '', false, false)]
    local procedure Prompt(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
        if not Url.StartsWith('https://example.invalid/x168-fixture/') then
            exit;
        Handled := true;
        Sent := true;
        HttpStatus := 200;
        HttpBlocked := false;
        ResponseText := Body();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforeChatPostWithStatus', '', false, false)]
    local procedure Chat(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var HttpStatus: Integer; var ResponseText: Text)
    begin
        if not Url.StartsWith('https://example.invalid/x168-fixture/') then
            exit;
        Handled := true;
        HttpStatus := 200;
        ResponseText := Body();
    end;

    local procedure Body(): Text
    begin
        exit('{"choices":[{"message":{"role":"assistant","content":"X168 fixture complete."},"finish_reason":"stop"}],"usage":{"prompt_tokens":100,"completion_tokens":25,"prompt_tokens_details":{"cached_tokens":3},"completion_tokens_details":{"reasoning_tokens":2}}}');
    end;
}
