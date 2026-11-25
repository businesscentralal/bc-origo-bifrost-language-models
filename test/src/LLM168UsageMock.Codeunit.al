namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>Intercepts every supported provider transport; no credentials or external requests.</summary>
codeunit 96084 "LLM 168 Usage Mock"
{
    Access = Internal;
    EventSubscriberInstance = Manual;
    var
        ResponseBody: Text;
        ResponseStatus: Integer;
        ThrowTransport: Boolean;
        Calls: Integer;

    /// <summary>Configures the synthetic provider response.</summary>
    procedure Configure(Body: Text; Status: Integer; ThrowError: Boolean)
    begin
        ResponseBody := Body;
        ResponseStatus := Status;
        ThrowTransport := ThrowError;
        Calls := 0;
    end;

    /// <summary>Returns the actual number of intercepted transport attempts.</summary>
    procedure GetCalls(): Integer
    begin
        exit(Calls);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel Prov. Base ori", 'OnCheckHttpClientAllowed', '', false, false)]
    local procedure AllowHttp(var Handled: Boolean; var Allowed: Boolean)
    begin
        Handled := true;
        Allowed := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforePromptPost', '', false, false)]
    local procedure Prompt(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
        Answer(Handled, HttpStatus, ResponseText);
        Sent := true;
        HttpBlocked := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforeChatPostWithStatus', '', false, false)]
    local procedure Chat(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var HttpStatus: Integer; var ResponseText: Text)
    begin
        Answer(Handled, HttpStatus, ResponseText);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Anthropic LangModel Proxy ori", 'OnBeforeMessagesPostWithStatus', '', false, false)]
    local procedure Anthropic(BaseUrl: Text; RequestBody: JsonObject; var Handled: Boolean; var HttpStatus: Integer; var ResponseText: Text)
    begin
        Answer(Handled, HttpStatus, ResponseText);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LLM Usage Copilot ori", 'OnBeforeGenerate', '', false, false)]
    local procedure Copilot(var Handled: Boolean; var Success: Boolean; var Status: Integer; var ResponseText: Text)
    begin
        Answer(Handled, Status, ResponseText);
        Success := (Status >= 200) and (Status < 300);
    end;

    local procedure Answer(var Handled: Boolean; var Status: Integer; var ResponseText: Text)
    begin
        Calls += 1;
        Handled := true;
        if ThrowTransport then
            Error('Synthetic transport failure');
        Status := ResponseStatus;
        ResponseText := ResponseBody;
    end;
}
