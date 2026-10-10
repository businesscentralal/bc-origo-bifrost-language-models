namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Masker for Copilot request log entries. Logging only occurs in debug mode,
/// so bodies are passed through unredacted.
/// </summary>
codeunit 10035394 "Copilot Req Log Masker ori" implements "Request Log Masker ori"
{
    Access = Internal;

    /// <summary>
    /// Returns the request body unchanged because Copilot uses managed authentication.
    /// </summary>
    procedure MaskRequestBody(Body: Text; DebugMode: Boolean): Text
    begin
        exit(Body);
    end;

    /// <summary>
    /// Returns the response body unchanged because Copilot uses managed authentication.
    /// </summary>
    procedure MaskResponseBody(Body: Text; DebugMode: Boolean): Text
    begin
        exit(Body);
    end;

    /// <summary>
    /// Returns error text unchanged for request-log diagnostics.
    /// </summary>
    procedure MaskErrorText(ErrorText: Text; DebugMode: Boolean): Text
    begin
        exit(ErrorText);
    end;

    /// <summary>
    /// Returns the managed Azure OpenAI label for request logs.
    /// </summary>
    procedure GetBaseUrl(FullUrl: Text): Text
    begin
        exit('Azure OpenAI (Managed)');
    end;
}
