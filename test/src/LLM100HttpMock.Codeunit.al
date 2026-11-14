namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>Manually bound interception of the chat completions, Responses and Anthropic messages posts for issue 100; never receives credentials.</summary>
codeunit 96044 "LLM 100 HTTP Mock"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        ResponseBody: Text;
        Bodies: List of [Text];
        ResponseStatus: Integer;

    /// <summary>Configures the synthetic provider answer and clears the captured request bodies.</summary>
    procedure Configure(NewResponseBody: Text)
    begin
        ResponseBody := NewResponseBody;
        ResponseStatus := 0;
        Clear(Bodies);
    end;

    /// <summary>Answers the Anthropic messages post with this HTTP status and synthetic body (#125 AC03).</summary>
    procedure ConfigureStatus(NewStatus: Integer; NewResponseBody: Text)
    begin
        Configure(NewResponseBody);
        ResponseStatus := NewStatus;
    end;

    /// <summary>Number of requests captured since Configure.</summary>
    procedure GetCallCount(): Integer
    begin
        exit(Bodies.Count());
    end;

    /// <summary>The request body of the n-th captured request.</summary>
    procedure GetBody(Index: Integer): Text
    begin
        exit(Bodies.Get(Index));
    end;

    /// <summary>The names in the tools array of the n-th request, in order; empty when the request has no tools.</summary>
    procedure GetToolNames(Index: Integer) Names: List of [Text]
    var
        Request: JsonObject;
        ToolsToken: JsonToken;
        ToolToken: JsonToken;
        FunctionToken: JsonToken;
        NameToken: JsonToken;
    begin
        Request.ReadFrom(Bodies.Get(Index));
        if not Request.Get('tools', ToolsToken) then
            exit;
        foreach ToolToken in ToolsToken.AsArray() do begin
            // Chat completions: {type, function:{name}}; Responses and Anthropic: {name}
            if ToolToken.AsObject().Get('function', FunctionToken) then
                FunctionToken.AsObject().Get('name', NameToken)
            else
                ToolToken.AsObject().Get('name', NameToken);
            Names.Add(NameToken.AsValue().AsText());
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforeChatPost', '', false, false)]
    local procedure OnBeforeChatPost(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var ResponseText: Text)
    begin
        Capture(RequestBody, Handled, ResponseText);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Anthropic LangModel Proxy ori", 'OnBeforeMessagesPost', '', false, false)]
    local procedure OnBeforeMessagesPost(BaseUrl: Text; RequestBody: JsonObject; var Handled: Boolean; var ResponseText: Text)
    begin
        if ResponseStatus = 0 then
            Capture(RequestBody, Handled, ResponseText);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Anthropic LangModel Proxy ori", 'OnBeforeMessagesPostWithStatus', '', false, false)]
    local procedure OnBeforeMessagesPostWithStatus(BaseUrl: Text; RequestBody: JsonObject; var Handled: Boolean; var HttpStatus: Integer; var ResponseText: Text)
    begin
        if ResponseStatus = 0 then
            exit;
        Capture(RequestBody, Handled, ResponseText);
        HttpStatus := ResponseStatus;
    end;

    local procedure Capture(RequestBody: JsonObject; var Handled: Boolean; var ResponseText: Text)
    var
        BodyText: Text;
    begin
        RequestBody.WriteTo(BodyText);
        Bodies.Add(BodyText);
        Handled := true;
        ResponseText := ResponseBody;
    end;
}
