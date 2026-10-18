namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>Manually bound HTTP interception for issue 65; never receives provider credentials.</summary>
codeunit 96033 "LLM 65 HTTP Mock"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        Status: Integer;
        Body: Text;
        Blocked: Boolean;
        ThrowTransportError: Boolean;
        CallCount: Integer;
        LastBody: Text;
        LastUrl: Text;

    /// <summary>Configures one synthetic HTTP result and resets observations.</summary>
    procedure Configure(NewStatus: Integer; NewBody: Text; NewBlocked: Boolean; NewThrow: Boolean)
    begin
        Status := NewStatus;
        Body := NewBody;
        Blocked := NewBlocked;
        ThrowTransportError := NewThrow;
        CallCount := 0;
        LastBody := '';
        LastUrl := '';
    end;

    /// <summary>Returns the actual number of requests intercepted from the provider.</summary>
    procedure GetCallCount(): Integer
    begin
        exit(CallCount);
    end;

    /// <summary>Returns the credential-free JSON request for payload assertions.</summary>
    procedure GetRequestBody(): Text
    begin
        exit(LastBody);
    end;

    /// <summary>Returns the endpoint selected by the real provider.</summary>
    procedure GetRequestUrl(): Text
    begin
        exit(LastUrl);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforePromptPost', '', false, false)]
    local procedure OnBeforePromptPost(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
        CallCount += 1;
        LastUrl := Url;
        RequestBody.WriteTo(LastBody);
        Handled := true;
        Sent := Status <> 0;
        HttpStatus := Status;
        HttpBlocked := Blocked;
        ResponseText := Body;
        if ThrowTransportError then
            Error('Synthetic transport failure containing fake credential suffix Z9Q7');
    end;
}
