namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Masker for LLM API requests logged via the shared Bifrost request log.
/// Strips API keys from request bodies; passes full bodies in debug mode, redacts in normal mode.
/// </summary>
codeunit 10035409 "LLM Req Log Masker ori" implements "Request Log Masker ori"
{
    Access = Internal;

    var
        RedactedTok: Label '***REDACTED***', Locked = true;

    /// <summary>
    /// Returns the request body in debug mode and a redaction marker otherwise.
    /// </summary>
    procedure MaskRequestBody(Body: Text; DebugMode: Boolean): Text
    begin
        if DebugMode then
            exit(Body);
        exit(RedactedTok);
    end;

    /// <summary>
    /// Returns the response body in debug mode and a redaction marker otherwise.
    /// </summary>
    procedure MaskResponseBody(Body: Text; DebugMode: Boolean): Text
    begin
        if DebugMode then
            exit(Body);
        exit(RedactedTok);
    end;

    /// <summary>
    /// Returns error text unchanged for request-log diagnostics.
    /// </summary>
    procedure MaskErrorText(ErrorText: Text; DebugMode: Boolean): Text
    begin
        exit(ErrorText);
    end;

    /// <summary>
    /// Returns the scheme and host before the first path separator; preserves empty or schemeless input.
    /// </summary>
    procedure GetBaseUrl(FullUrl: Text): Text
    var
        SchemeEnd: Integer;
        DomainEnd: Integer;
        UrlAfterScheme: Text;
    begin
        if FullUrl = '' then
            exit('');
        SchemeEnd := StrPos(FullUrl, '://');
        if SchemeEnd = 0 then
            exit(FullUrl);
        UrlAfterScheme := CopyStr(FullUrl, SchemeEnd + 3);
        DomainEnd := StrPos(UrlAfterScheme, '/');
        if DomainEnd = 0 then
            exit(FullUrl);
        exit(CopyStr(FullUrl, 1, SchemeEnd + 2 + DomainEnd - 1));
    end;
}
