namespace Origo.Bifrost.LanguageModels;

/// <summary>
/// Shared prompt-file policy for every file-accepting language-model provider.
/// PNG and JPEG stay inline. Other image types and oversize files are refused
/// before HTTP. A document that cannot be sent inline is uploaded to the named
/// provider's file store, referenced by file id, and deleted after the call
/// (STE-0002: customer bytes leave Business Central only for that provider, and
/// only for the duration of the prompt).
/// </summary>
codeunit 10035429 "LangModel File Handling ori"
{
    Access = Internal;
    InherentPermissions = X;

    var
        ProviderFileCleanupTok: Label 'ORI-LM-0093', Locked = true;
        ProviderFileCleanupMsg: Label 'Language model provider file cleanup failed.', Locked = true;
        FilesPathTok: Label '/v1/files', Locked = true;
        DataUriTok: Label 'data:%1;base64,%2', Locked = true;
        IdUnreadOutcomeTok: Label 'id unread', Locked = true;

    /// <summary>Default decoded size cap, 20 MB, before any provider HTTP call.</summary>
    procedure MaxDecodedFileBytes(): Integer
    begin
        exit(20971520);
    end;

    /// <summary>True when the MIME type is sent inline as an image under the shared policy.</summary>
    procedure IsInlineImageMime(MimeType: Text): Boolean
    var
        Normalized: Text;
    begin
        Normalized := LowerCase(MimeType);
        exit((Normalized = 'image/png') or (Normalized = 'image/jpeg'));
    end;

    /// <summary>True when the MIME type is an image the shared policy refuses before HTTP.</summary>
    procedure IsRefusedImageMime(MimeType: Text): Boolean
    begin
        exit(LowerCase(MimeType).StartsWith('image/') and not IsInlineImageMime(MimeType));
    end;

    /// <summary>True when decoded file bytes exceed the resolved language-model size limit.</summary>
    [NonDebuggable]
    procedure IsOversize(ContentBase64: Text): Boolean
    var
        MaxBytes: Integer;
        Length: Integer;
        MinimumDecoded: Integer;
    begin
        MaxBytes := ResolvedMaxDecodedFileBytes();
        Length := StrLen(ContentBase64);
        if Length = 0 then
            exit(false);
        // Past this length the decoded count cannot fit in an Integer and is over any resolved cap.
        if Length > 700000000 then
            exit(true);
        // Minimum decoded size for this Base64 length, allowing two padding characters.
        // Compare with the resolved cap so a raised OnResolveMaxDecodedFileBytes override is honoured.
        MinimumDecoded := (Length * 3) div 4 - 2;
        if MinimumDecoded > MaxBytes then
            exit(true);
        exit(DecodedByteCount(ContentBase64) > MaxBytes);
    end;

    /// <summary>Decoded byte count of a Base64 payload, without writing the bytes.</summary>
    [NonDebuggable]
    procedure DecodedByteCount(ContentBase64: Text): Integer
    var
        Length: Integer;
        Padding: Integer;
    begin
        Length := StrLen(ContentBase64);
        if Length = 0 then
            exit(0);
        if Length > 700000000 then
            exit(2147483647);
        if CopyStr(ContentBase64, Length, 1) = '=' then
            Padding += 1;
        if (Length > 1) and (CopyStr(ContentBase64, Length - 1, 1) = '=') then
            Padding += 1;
        exit((Length * 3) div 4 - Padding);
    end;

    /// <summary>
    /// Shared pre-HTTP gate for every file-accepting provider.
    /// Refuses a non-PNG/JPEG image and an oversize file. Does not upload.
    /// </summary>
    [NonDebuggable]
    procedure AcceptFiles(PayloadObject: JsonObject; var ResultText: Text): Boolean
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        UnsupportedMime: Text;
    begin
        UnsupportedMime := FindUnsupportedImageMime(PayloadObject);
        if UnsupportedMime <> '' then begin
            ProviderBase.BuildUnsupportedImageRefusal(UnsupportedMime).WriteTo(ResultText);
            exit(false);
        end;
        if FindOversizeFile(PayloadObject) then begin
            ProviderBase.BuildOversizeRefusal().WriteTo(ResultText);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Adds inline images and uploaded document references to a Responses-style content array.
    /// Refuses unsupported images and oversize files before any HTTP call.
    /// </summary>
    [NonDebuggable]
    procedure AddResponseFiles(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadObject: JsonObject; var ContentArray: JsonArray; var UploadedFileIds: JsonArray; var ResultText: Text; ProviderName: Text; AuthHeaderName: Text; DefaultBaseUrl: Text): Boolean
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        ApiClient: Codeunit "LangModel API Client ori";
        FilesToken: JsonToken;
        FileToken: JsonToken;
        FileObj: JsonObject;
        FileBlock: JsonObject;
        UploadResponse: JsonObject;
        MimeType: Text;
        FileId: Text;
        BaseUrl: Text;
    begin
        if not AcceptFiles(PayloadObject, ResultText) then
            exit(false);
        if not PayloadObject.Get('files', FilesToken) then
            exit(true);
        if not FilesToken.IsArray() then
            exit(true);

        BaseUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrl);
        foreach FileToken in FilesToken.AsArray() do begin
            if not FileToken.IsObject() then
                continue;
            FileObj := FileToken.AsObject();
            MimeType := GetJsonText(FileObj, 'mimeType');
            Clear(FileBlock);
            if IsInlineImageMime(MimeType) then begin
                FileBlock.Add('type', 'input_image');
                FileBlock.Add('image_url', StrSubstNo(DataUriTok, LowerCase(MimeType), GetJsonText(FileObj, 'data')));
            end else begin
                UploadResponse := ApiClient.UploadProviderFile(
                    ProviderBase.JoinEndpointUrl(BaseUrl, FilesPathTok),
                    AuthHeaderName, Argument.GetApiKey(), ProviderBase.GetTimeoutMs(Argument, 120000),
                    GetJsonText(FileObj, 'fileName'), MimeType, GetJsonText(FileObj, 'data'));
                if UploadResponse.Contains('storedWithoutId') then
                    LogFileCleanupIssue(ProviderName, IdUnreadOutcomeTok, '', '');
                if UploadResponse.Contains('error') then begin
                    UploadResponse.WriteTo(ResultText);
                    exit(false);
                end;
                FileId := ProviderBase.NormalizeProviderFileId(GetJsonText(UploadResponse, 'id'));
                if FileId = '' then begin
                    LogFileCleanupIssue(ProviderName, IdUnreadOutcomeTok, '', '');
                    ProviderBase.BuildPromptError(-1, false).WriteTo(ResultText);
                    exit(false);
                end;
                UploadedFileIds.Add(FileId);
                FileBlock.Add('type', 'input_file');
                FileBlock.Add('file_id', FileId);
            end;
            ContentArray.Add(FileBlock);
        end;
        exit(true);
    end;

    /// <summary>Deletes uploaded provider files after the prompt. A cleanup failure is recorded and the prompt reply is kept.</summary>
    [NonDebuggable]
    procedure DeleteUploadedFiles(var Argument: Record "Bifrost Chat Argument ori" temporary; UploadedFileIds: JsonArray; ProviderName: Text; AuthHeaderName: Text; DefaultBaseUrl: Text)
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        ApiClient: Codeunit "LangModel API Client ori";
        DeleteResponse: JsonObject;
        IdToken: JsonToken;
        FileId: Text;
        BaseUrl: Text;
    begin
        if UploadedFileIds.Count() = 0 then
            exit;
        BaseUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrl);
        foreach IdToken in UploadedFileIds do begin
            if not IdToken.IsValue() then
                continue;
            FileId := ProviderBase.NormalizeProviderFileId(IdToken.AsValue().AsText());
            if FileId = '' then
                continue;
            DeleteResponse := ApiClient.DeleteProviderFile(
                ProviderBase.JoinEndpointUrl(BaseUrl, FilesPathTok + '/' + FileId),
                AuthHeaderName, Argument.GetApiKey(), ProviderBase.GetTimeoutMs(Argument, 120000));
            if DeleteResponse.Contains('error') then
                LogFileCleanupIssue(FileId, DeleteResponse, ProviderName);
        end;
    end;

    /// <summary>
    /// Records a failed provider-file cleanup without the file name, MIME type, prompt or provider body.
    /// </summary>
    [NonDebuggable]
    procedure LogFileCleanupIssue(Provider: Text; HttpOutcome: Text; ProviderErrorCode: Text; FileId: Text)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('provider', Provider);
        CustomDimensions.Add('httpOutcome', HttpOutcome);
        CustomDimensions.Add('providerErrorCode', ProviderErrorCode);
        CustomDimensions.Add('fileId', FileId);
        Session.LogMessage(ProviderFileCleanupTok, ProviderFileCleanupMsg, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
        OnProviderFileCleanupIssue(Provider, HttpOutcome, ProviderErrorCode, FileId);
    end;

    local procedure LogFileCleanupIssue(FileId: Text; DeleteResponse: JsonObject; ProviderName: Text)
    var
        HttpOutcome: Text;
        ProviderErrorCode: Text;
    begin
        HttpOutcome := ProviderFileDeleteOutcome(DeleteResponse);
        ProviderErrorCode := SafeLoggedProviderErrorCode(DeleteResponse);
        LogFileCleanupIssue(ProviderName, HttpOutcome, ProviderErrorCode, FileId);
    end;

    local procedure ProviderFileDeleteOutcome(DeleteResponse: JsonObject): Text
    var
        HttpStatus: Integer;
        HttpBlocked: Boolean;
    begin
        HttpBlocked := false;
        HttpStatus := 0;
        if DeleteResponse.Contains('httpBlocked') then
            HttpBlocked := DeleteResponse.GetBoolean('httpBlocked');
        if HttpBlocked then
            exit('blocked');
        if DeleteResponse.Contains('providerStatus') then
            HttpStatus := DeleteResponse.GetInteger('providerStatus');
        if (HttpStatus >= 100) and (HttpStatus <= 599) then
            exit(Format(HttpStatus, 0, 9));
        exit('not sent');
    end;

    local procedure SafeLoggedProviderErrorCode(DeleteResponse: JsonObject): Text
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        Candidate: Text;
    begin
        if not DeleteResponse.Contains('providerErrorCode') then
            exit('');
        Candidate := DeleteResponse.GetText('providerErrorCode');
        if Candidate.Contains('"') or Candidate.Contains('\') then
            exit('');
        exit(ProviderBase.SanitizeProviderErrorCode('{"code":"' + Candidate + '"}'));
    end;

    [NonDebuggable]
    local procedure FindUnsupportedImageMime(PayloadObject: JsonObject): Text
    var
        FilesToken: JsonToken;
        FileToken: JsonToken;
        FileObj: JsonObject;
        MimeType: Text;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit('');
        if not FilesToken.IsArray() then
            exit('');
        foreach FileToken in FilesToken.AsArray() do begin
            if not FileToken.IsObject() then
                continue;
            FileObj := FileToken.AsObject();
            MimeType := GetJsonText(FileObj, 'mimeType');
            if IsRefusedImageMime(MimeType) then
                exit(MimeType);
        end;
    end;

    [NonDebuggable]
    local procedure FindOversizeFile(PayloadObject: JsonObject): Boolean
    var
        FilesToken: JsonToken;
        FileToken: JsonToken;
        FileObj: JsonObject;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit(false);
        if not FilesToken.IsArray() then
            exit(false);
        foreach FileToken in FilesToken.AsArray() do begin
            if not FileToken.IsObject() then
                continue;
            FileObj := FileToken.AsObject();
            if IsOversize(GetJsonText(FileObj, 'data')) then
                exit(true);
        end;
    end;

    local procedure ResolvedMaxDecodedFileBytes(): Integer
    var
        MaxBytes: Integer;
    begin
        MaxBytes := MaxDecodedFileBytes();
        OnResolveMaxDecodedFileBytes(MaxBytes);
        if MaxBytes < 1 then
            exit(MaxDecodedFileBytes());
        exit(MaxBytes);
    end;

    local procedure GetJsonText(JObject: JsonObject; PropertyName: Text): Text
    var
        JToken: JsonToken;
    begin
        if JObject.Get(PropertyName, JToken) then
            if JToken.IsValue() then
                exit(JToken.AsValue().AsText());
    end;

    [IntegrationEvent(false, false)]
    local procedure OnProviderFileCleanupIssue(Provider: Text; HttpOutcome: Text; ProviderErrorCode: Text; FileId: Text)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnResolveMaxDecodedFileBytes(var MaxBytes: Integer)
    begin
    end;
}
