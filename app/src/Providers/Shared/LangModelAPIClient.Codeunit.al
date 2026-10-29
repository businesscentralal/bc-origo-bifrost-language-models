namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;
using System.Text;
using System.Utilities;

/// <summary>
/// Thin HTTP client shared by the OpenAI-compatible chat providers: posts a Chat
/// Completions-shaped request to an explicit endpoint and lists models from an
/// explicit endpoint, both with a caller-supplied auth header and API key.
/// Buffers the last call for debug-mode request logging via LogLastRequest.
/// </summary>
codeunit 10035411 "LangModel API Client ori"
{
    Access = Internal;

    var
        LastOperation: Text[50];
        LastHttpMethod: Text[10];
        LastRequestUrl: Text;
        LastRequestText: Text;
        LastResponseText: Text;
        LastErrorText: Text;
        LastHttpStatus: Integer;
        LastElapsed: Duration;
        LastIsSuccess: Boolean;
        HasPendingLog: Boolean;
        ServiceNameTok: Label 'LLM', Locked = true;
        BearerTok: Label 'Bearer %1', Locked = true;
        CallFailedErr: Label 'Could not reach the LLM API. %1', Comment = '%1 = error detail, is-IS=Náði ekki sambandi við LLM API. %1';
        ApiStatusErr: Label 'LLM API returned status %1. %2', Comment = '%1 = status code, %2 = detail, is-IS=LLM API skilaði stöðu %1. %2';
        InvalidResponseErr: Label 'Received an invalid response from the LLM API.', Comment = 'is-IS=Ógilt svar barst frá LLM API.';

    /// <summary>
    /// Writes the buffered log entry from the last API call to the shared request log.
    /// Only logs when Request Debug Mode is enabled.
    /// </summary>
    procedure LogLastRequest()
    var
        Setup: Record "Setup ori";
        Logger: Codeunit "Request Logger ori";
    begin
        if not HasPendingLog then
            exit;
        HasPendingLog := false;

        if not Setup.GetRequestDebugMode() then
            exit;

        Logger.Log(
            LastOperation, LastHttpMethod, LastRequestUrl, ServiceNameTok,
            LastHttpStatus, LastElapsed, LastIsSuccess, LastErrorText,
            LastRequestText, LastResponseText,
            Enum::"Request Log Type ori"::"LLM");
        Logger.Insert();
    end;

    /// <summary>
    /// Sends a chat completion to an explicit endpoint URL with the specified auth.
    /// </summary>
    [NonDebuggable]
    procedure SendToEndpoint(ChatUrl: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject) Response: JsonObject
    var
        HttpClientVar: HttpClient;
        HttpContent: HttpContent;
        HttpResponse: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        DefaultHeaders: HttpHeaders;
        RequestText: Text;
        ResponseText: Text;
        StartTime: DateTime;
    begin
        HasPendingLog := false;
        RequestBody.WriteTo(RequestText);
        HttpContent.WriteFrom(RequestText);
        HttpContent.GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        DefaultHeaders := HttpClientVar.DefaultRequestHeaders();
        if AuthHeaderName = 'Authorization' then
            DefaultHeaders.Add('Authorization', SecretStrSubstNo(BearerTok, ApiKey))
        else
            DefaultHeaders.Add(AuthHeaderName, ApiKey);
        HttpClientVar.Timeout(TimeoutMs);

        StartTime := CurrentDateTime();
        if not HttpClientVar.Post(ChatUrl, HttpContent, HttpResponse) then begin
            BufferLog('chat/completions', 'POST', ChatUrl, RequestText, '',
                GetLastErrorText(), 0, CurrentDateTime() - StartTime, false);
            Error(CallFailedErr, GetLastErrorText());
        end;

        HttpResponse.Content.ReadAs(ResponseText);

        if not HttpResponse.IsSuccessStatusCode() then begin
            BufferLog('chat/completions', 'POST', ChatUrl, RequestText, ResponseText,
                GetErrorDetail(ResponseText), HttpResponse.HttpStatusCode(), CurrentDateTime() - StartTime, false);
            Error(ApiStatusErr, Format(HttpResponse.HttpStatusCode()), GetErrorDetail(ResponseText));
        end;

        BufferLog('chat/completions', 'POST', ChatUrl, RequestText, ResponseText,
            '', HttpResponse.HttpStatusCode(), CurrentDateTime() - StartTime, true);

        if not Response.ReadFrom(ResponseText) then
            Error(InvalidResponseErr);
    end;

    /// <summary>Sends a one-shot prompt with safe failure metadata and no provider error text.</summary>
    [NonDebuggable]
    procedure SendPromptToEndpoint(Url: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject): JsonObject
    var
        ExtraHeaders: JsonObject;
    begin
        exit(SendPromptToEndpoint(Url, AuthHeaderName, ApiKey, TimeoutMs, RequestBody, ExtraHeaders));
    end;

    /// <summary>Sends a prompt with optional protocol headers, discarding failed response bodies before logging.</summary>
    [NonDebuggable]
    procedure SendPromptToEndpoint(Url: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject; ExtraHeaders: JsonObject) Response: JsonObject
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        ResponseText: Text;
        ProviderErrorCode: Text;
        HttpStatus: Integer;
        HttpBlocked: Boolean;
        Sent: Boolean;
    begin
        HasPendingLog := false;
        if not ProviderBase.CanSendHttpRequests() then
            exit(ProviderBase.BuildPromptError(0, true));
        if not TryPostPrompt(Url, AuthHeaderName, ApiKey, TimeoutMs, RequestBody, ExtraHeaders, Sent, HttpStatus, HttpBlocked, ResponseText, ProviderErrorCode) then begin
            ClearLastError();
            exit(ProviderBase.BuildPromptError(0, HttpBlocked));
        end;
        if HttpBlocked or not Sent then
            exit(ProviderBase.BuildPromptError(0, HttpBlocked));
        if (HttpStatus < 200) or (HttpStatus > 299) then
            exit(ProviderBase.BuildPromptError(HttpStatus, false, ProviderErrorCode));
        if not Response.ReadFrom(ResponseText) then
            exit(ProviderBase.BuildPromptError(-1, false));
        if Response.Contains('error') then
            exit(ProviderBase.BuildPromptError(-1, false, ProviderBase.SanitizeProviderErrorCode(ResponseText)));
        // Prompt calls deliberately do not buffer provider text: even a nominally
        // successful provider body may contain authentication diagnostics.
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TryPostPrompt(Url: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject; ExtraHeaders: JsonObject; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text; var ProviderErrorCode: Text)
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        HttpClientVar: HttpClient;
        HttpContent: HttpContent;
        HttpResponse: HttpResponseMessage;
        Headers: HttpHeaders;
        RequestText: Text;
        HeaderName: Text;
        Handled: Boolean;
        FailureText: Text;
    begin
        ProviderErrorCode := '';
        OnBeforePromptPost(Url, RequestBody, Handled, Sent, HttpStatus, HttpBlocked, ResponseText);
        if Handled then begin
            KeepOnlySafeProviderCode(HttpStatus, ResponseText, ProviderErrorCode);
            exit;
        end;
        RequestBody.WriteTo(RequestText);
        HttpContent.WriteFrom(RequestText);
        HttpContent.GetHeaders(Headers);
        Headers.Remove('Content-Type');
        Headers.Add('Content-Type', 'application/json');
        Headers := HttpClientVar.DefaultRequestHeaders();
        if AuthHeaderName = 'Authorization' then
            Headers.Add(AuthHeaderName, SecretStrSubstNo(BearerTok, ApiKey))
        else
            Headers.Add(AuthHeaderName, ApiKey);
        foreach HeaderName in ExtraHeaders.Keys() do
            Headers.Add(HeaderName, ExtraHeaders.GetText(HeaderName));
        HttpClientVar.Timeout(TimeoutMs);
        Sent := HttpClientVar.Post(Url, HttpContent, HttpResponse);
        HttpBlocked := HttpResponse.IsBlockedByEnvironment();
        if not Sent then
            exit;
        HttpStatus := HttpResponse.HttpStatusCode();
        if HttpResponse.IsSuccessStatusCode() then
            HttpResponse.Content.ReadAs(ResponseText)
        else begin
            // Read only long enough to keep a sanitised error code. The body itself is discarded.
            HttpResponse.Content.ReadAs(FailureText);
            ProviderErrorCode := ProviderBase.SanitizeProviderErrorCode(FailureText);
            ResponseText := '';
        end;
    end;

    [NonDebuggable]
    local procedure KeepOnlySafeProviderCode(HttpStatus: Integer; var ResponseText: Text; var ProviderErrorCode: Text)
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        if (HttpStatus < 200) or (HttpStatus > 299) then begin
            ProviderErrorCode := ProviderBase.SanitizeProviderErrorCode(ResponseText);
            ResponseText := '';
        end;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePromptPost(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
    end;

    /// <summary>Uploads one file to a provider Files endpoint and returns the provider file object or a safe error.</summary>
    [NonDebuggable]
    procedure UploadProviderFile(FilesUrl: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; FileName: Text; MimeType: Text; ContentBase64: Text) Response: JsonObject
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        ResponseText: Text;
        ProviderErrorCode: Text;
        FileId: Text;
        HttpStatus: Integer;
        HttpBlocked: Boolean;
        Sent: Boolean;
    begin
        if not ProviderBase.CanSendHttpRequests() then
            exit(ProviderBase.BuildPromptError(0, true));
        if not TryUploadProviderFile(FilesUrl, AuthHeaderName, ApiKey, TimeoutMs, FileName, MimeType, ContentBase64, Sent, HttpStatus, HttpBlocked, ResponseText, ProviderErrorCode) then begin
            ClearLastError();
            exit(ProviderBase.BuildPromptError(0, HttpBlocked));
        end;
        if HttpBlocked or not Sent then
            exit(ProviderBase.BuildPromptError(0, HttpBlocked));
        if (HttpStatus < 200) or (HttpStatus > 299) then
            exit(ProviderBase.BuildPromptError(HttpStatus, false, ProviderErrorCode));
        if not Response.ReadFrom(ResponseText) then
            exit(StoredWithoutIdError(ProviderBase));
        if Response.Contains('error') then
            exit(ProviderBase.BuildPromptError(HttpStatus, false, ProviderBase.SanitizeProviderErrorCode(ResponseText)));
        if not TryReadUploadedFileId(Response, FileId) then
            exit(StoredWithoutIdError(ProviderBase));
    end;

    /// <summary>Deletes one previously uploaded provider file. The caller records a cleanup failure and keeps the prompt reply.</summary>
    [NonDebuggable]
    procedure DeleteProviderFile(FileUrl: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer): JsonObject
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        ResponseText: Text;
        ProviderErrorCode: Text;
        HttpStatus: Integer;
        HttpBlocked: Boolean;
        Sent: Boolean;
    begin
        if not ProviderBase.CanSendHttpRequests() then
            exit(ProviderBase.BuildPromptError(0, true));
        if not TryDeleteProviderFile(FileUrl, AuthHeaderName, ApiKey, TimeoutMs, Sent, HttpStatus, HttpBlocked, ResponseText, ProviderErrorCode) then begin
            ClearLastError();
            exit(ProviderBase.BuildPromptError(0, false));
        end;
        if HttpBlocked or not Sent then
            exit(ProviderBase.BuildPromptError(0, HttpBlocked));
        if (HttpStatus < 200) or (HttpStatus > 299) then
            exit(ProviderBase.BuildPromptError(HttpStatus, false, ProviderErrorCode));
    end;

    /// <summary>Writes a multipart file upload body. Purpose is written before the file bytes.</summary>
    [NonDebuggable]
    procedure WriteProviderFileUpload(FileName: Text; MimeType: Text; ContentBase64: Text; var Boundary: Text; var Body: Codeunit "Temp Blob")
    var
        Base64Convert: Codeunit "Base64 Convert";
        FileBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        FileOut: OutStream;
        FileIn: InStream;
        NewLine: Text[2];
        Preamble: Text;
        Ending: Text;
    begin
        NewLine[1] := 13;
        NewLine[2] := 10;
        Boundary := 'BifrostLM' + DelChr(Format(CreateGuid()), '=', '{}-');
        FileBlob.CreateOutStream(FileOut);
        Base64Convert.FromBase64(ContentBase64, FileOut);
        FileBlob.CreateInStream(FileIn);
        Preamble :=
            '--' + Boundary + NewLine +
            'Content-Disposition: form-data; name="purpose"' + NewLine + NewLine +
            'assistants' + NewLine +
            '--' + Boundary + NewLine +
            'Content-Disposition: form-data; name="file"; filename="' + SanitizeUploadFileName(FileName) + '"' + NewLine +
            'Content-Type: ' + SanitizeUploadMimeType(MimeType) + NewLine + NewLine;
        Ending := NewLine + '--' + Boundary + '--' + NewLine;
        Body.CreateOutStream(OutStream);
        OutStream.WriteText(Preamble);
        CopyStream(OutStream, FileIn);
        OutStream.WriteText(Ending);
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TryUploadProviderFile(FilesUrl: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; FileName: Text; MimeType: Text; ContentBase64: Text; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text; var ProviderErrorCode: Text)
    var
        Body: Codeunit "Temp Blob";
        HttpClientVar: HttpClient;
        HttpContent: HttpContent;
        HttpResponse: HttpResponseMessage;
        Headers: HttpHeaders;
        BodyIn: InStream;
        Boundary: Text;
        Handled: Boolean;
    begin
        ProviderErrorCode := '';
        OnBeforeFileUpload(FilesUrl, FileName, MimeType, ContentBase64, Handled, Sent, HttpStatus, HttpBlocked, ResponseText);
        if Handled then begin
            KeepOnlySafeProviderCode(HttpStatus, ResponseText, ProviderErrorCode);
            exit;
        end;
        WriteProviderFileUpload(FileName, MimeType, ContentBase64, Boundary, Body);
        Body.CreateInStream(BodyIn);
        HttpContent.WriteFrom(BodyIn);
        HttpContent.GetHeaders(Headers);
        if Headers.Contains('Content-Type') then
            Headers.Remove('Content-Type');
        Headers.Add('Content-Type', 'multipart/form-data; boundary=' + Boundary);
        AddAuthHeader(HttpClientVar, AuthHeaderName, ApiKey);
        HttpClientVar.Timeout(TimeoutMs);
        Sent := HttpClientVar.Post(FilesUrl, HttpContent, HttpResponse);
        HttpBlocked := HttpResponse.IsBlockedByEnvironment();
        if not Sent then
            exit;
        HttpStatus := HttpResponse.HttpStatusCode();
        ReadProviderResponse(HttpResponse, ResponseText, ProviderErrorCode);
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TryDeleteProviderFile(FileUrl: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text; var ProviderErrorCode: Text)
    var
        HttpClientVar: HttpClient;
        HttpResponse: HttpResponseMessage;
        Handled: Boolean;
    begin
        ProviderErrorCode := '';
        OnBeforeFileDelete(FileUrl, Handled, Sent, HttpStatus, HttpBlocked, ResponseText);
        if Handled then begin
            KeepOnlySafeProviderCode(HttpStatus, ResponseText, ProviderErrorCode);
            exit;
        end;
        AddAuthHeader(HttpClientVar, AuthHeaderName, ApiKey);
        HttpClientVar.Timeout(TimeoutMs);
        Sent := HttpClientVar.Delete(FileUrl, HttpResponse);
        HttpBlocked := HttpResponse.IsBlockedByEnvironment();
        if not Sent then
            exit;
        HttpStatus := HttpResponse.HttpStatusCode();
        ReadProviderResponse(HttpResponse, ResponseText, ProviderErrorCode);
    end;

    [NonDebuggable]
    local procedure AddAuthHeader(var HttpClientVar: HttpClient; AuthHeaderName: Text; ApiKey: SecretText)
    var
        Headers: HttpHeaders;
    begin
        Headers := HttpClientVar.DefaultRequestHeaders();
        if AuthHeaderName = 'Authorization' then
            Headers.Add(AuthHeaderName, SecretStrSubstNo(BearerTok, ApiKey))
        else
            Headers.Add(AuthHeaderName, ApiKey);
    end;

    [NonDebuggable]
    local procedure ReadProviderResponse(HttpResponse: HttpResponseMessage; var ResponseText: Text; var ProviderErrorCode: Text)
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        FailureText: Text;
    begin
        if HttpResponse.IsSuccessStatusCode() then
            HttpResponse.Content.ReadAs(ResponseText)
        else begin
            HttpResponse.Content.ReadAs(FailureText);
            ProviderErrorCode := ProviderBase.SanitizeProviderErrorCode(FailureText);
            ResponseText := '';
        end;
    end;

    local procedure StoredWithoutIdError(var ProviderBase: Codeunit "LangModel Prov. Base ori") Response: JsonObject
    begin
        Response := ProviderBase.BuildPromptError(-1, false);
        Response.Add('storedWithoutId', true);
    end;

    [NonDebuggable]
    local procedure TryReadUploadedFileId(Response: JsonObject; var FileId: Text): Boolean
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        IdToken: JsonToken;
    begin
        FileId := '';
        if not Response.Get('id', IdToken) then
            exit(false);
        if not IdToken.IsValue() or IdToken.AsValue().IsNull() then
            exit(false);
        FileId := ProviderBase.NormalizeProviderFileId(IdToken.AsValue().AsText());
        exit(FileId <> '');
    end;

    local procedure SanitizeUploadFileName(FileName: Text): Text
    var
        Index: Integer;
        Character: Char;
        Result: Text;
    begin
        for Index := 1 to StrLen(FileName) do begin
            Character := FileName[Index];
            if IsUploadNameCharacter(Character) then
                Result += Character;
            if StrLen(Result) >= 80 then
                break;
        end;
        if (Result = '') or (Result = '.') or (Result = '..') then
            exit('document.bin');
        exit(Result);
    end;

    local procedure IsUploadNameCharacter(Character: Char): Boolean
    begin
        exit(((Character >= 'a') and (Character <= 'z')) or ((Character >= 'A') and (Character <= 'Z')) or
            ((Character >= '0') and (Character <= '9')) or (Character = '.') or (Character = '-') or (Character = '_'));
    end;

    local procedure SanitizeUploadMimeType(MimeType: Text): Text
    var
        Normalized: Text;
        Index: Integer;
        Character: Char;
        SlashCount: Integer;
    begin
        Normalized := LowerCase(MimeType);
        if (StrLen(Normalized) < 3) or (StrLen(Normalized) > 80) then
            exit('application/octet-stream');
        for Index := 1 to StrLen(Normalized) do begin
            Character := Normalized[Index];
            if Character = '/' then
                SlashCount += 1
            else
                if not (((Character >= 'a') and (Character <= 'z')) or ((Character >= '0') and (Character <= '9')) or (Character = '+') or (Character = '.') or (Character = '-')) then
                    exit('application/octet-stream');
        end;
        if SlashCount <> 1 then
            exit('application/octet-stream');
        exit(Normalized);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeFileUpload(Url: Text; FileName: Text; MimeType: Text; ContentBase64: Text; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeFileDelete(Url: Text; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
    end;

    /// <summary>
    /// Lists models from an explicit endpoint URL with the specified auth.
    /// </summary>
    [NonDebuggable]
    procedure ListModelsFromEndpoint(ModelsUrl: Text; AuthHeaderName: Text; ApiKey: SecretText) Models: JsonArray
    var
        HttpClientVar: HttpClient;
        HttpResponse: HttpResponseMessage;
        DefaultHeaders: HttpHeaders;
        Response: JsonObject;
        DataToken: JsonToken;
        ResponseText: Text;
    begin
        DefaultHeaders := HttpClientVar.DefaultRequestHeaders();
        if AuthHeaderName = 'Authorization' then
            DefaultHeaders.Add('Authorization', SecretStrSubstNo(BearerTok, ApiKey))
        else
            DefaultHeaders.Add(AuthHeaderName, ApiKey);

        if not HttpClientVar.Get(ModelsUrl, HttpResponse) then
            Error(CallFailedErr, GetLastErrorText());

        HttpResponse.Content.ReadAs(ResponseText);

        if not HttpResponse.IsSuccessStatusCode() then
            Error(ApiStatusErr, Format(HttpResponse.HttpStatusCode()), GetErrorDetail(ResponseText));

        if not Response.ReadFrom(ResponseText) then
            Error(InvalidResponseErr);

        if Response.Get('data', DataToken) then
            if DataToken.IsArray() then
                Models := DataToken.AsArray();
    end;

    /// <summary>
    /// Extracts the assistant text from an OpenAI-compatible chat completions response.
    /// </summary>
    procedure ExtractText(Response: JsonObject) ResultText: Text
    var
        ChoicesToken: JsonToken;
        FirstChoice: JsonToken;
        MessageToken: JsonToken;
        ContentToken: JsonToken;
    begin
        if not Response.Get('choices', ChoicesToken) then
            exit('');
        if not ChoicesToken.IsArray() then
            exit('');
        if ChoicesToken.AsArray().Count() = 0 then
            exit('');

        ChoicesToken.AsArray().Get(0, FirstChoice);
        if not FirstChoice.AsObject().Get('message', MessageToken) then
            exit('');
        if not MessageToken.AsObject().Get('content', ContentToken) then
            exit('');
        if ContentToken.IsValue() then
            if not ContentToken.AsValue().IsNull() then
                ResultText := ContentToken.AsValue().AsText();
    end;

    local procedure GetErrorDetail(ResponseText: Text): Text
    var
        ErrorObject: JsonObject;
        ErrorToken: JsonToken;
        MessageToken: JsonToken;
    begin
        if ErrorObject.ReadFrom(ResponseText) then
            if ErrorObject.Get('error', ErrorToken) then begin
                if ErrorToken.IsValue() then
                    exit(ErrorToken.AsValue().AsText());
                if ErrorToken.IsObject() then
                    if ErrorToken.AsObject().Get('message', MessageToken) then
                        if MessageToken.IsValue() then
                            exit(MessageToken.AsValue().AsText());
            end;
        exit(CopyStr(ResponseText, 1, 1000));
    end;

    local procedure BufferLog(Operation: Text[50]; HttpMethod: Text[10]; RequestUrl: Text; RequestText: Text; ResponseText: Text; ErrorText: Text; HttpStatus: Integer; Elapsed: Duration; IsSuccess: Boolean)
    begin
        LastOperation := Operation;
        LastHttpMethod := HttpMethod;
        LastRequestUrl := RequestUrl;
        LastRequestText := RequestText;
        LastResponseText := ResponseText;
        LastErrorText := ErrorText;
        LastHttpStatus := HttpStatus;
        LastElapsed := Elapsed;
        LastIsSuccess := IsSuccess;
        HasPendingLog := true;
    end;
}
