namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>Manually bound HTTP interception for issue 65 and 93; never receives provider credentials.</summary>
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
        UploadStatus: Integer;
        UploadBody: Text;
        UploadCount: Integer;
        LastUploadUrl: Text;
        LastUploadFileName: Text;
        LastUploadMime: Text;
        LastUploadBase64: Text;
        DeleteStatus: Integer;
        DeleteBody: Text;
        DeleteCount: Integer;
        LastDeleteUrl: Text;
        OperationSequence: Text;
        DeleteFailureCount: Integer;
        LastDeleteFailureProvider: Text;
        LastDeleteFailureOutcome: Text;
        LastDeleteFailureCode: Text;
        LastDeleteFailureFileId: Text;
        MaxDecodedBytesOverride: Integer;

    /// <summary>Configures one synthetic prompt result and resets file-transport observations.</summary>
    procedure Configure(NewStatus: Integer; NewBody: Text; NewBlocked: Boolean; NewThrow: Boolean)
    begin
        Status := NewStatus;
        Body := NewBody;
        Blocked := NewBlocked;
        ThrowTransportError := NewThrow;
        CallCount := 0;
        LastBody := '';
        LastUrl := '';
        UploadStatus := 200;
        UploadBody := '{"id":"file_llm65"}';
        UploadCount := 0;
        LastUploadUrl := '';
        LastUploadFileName := '';
        LastUploadMime := '';
        LastUploadBase64 := '';
        DeleteStatus := 200;
        DeleteBody := '{"deleted":true}';
        DeleteCount := 0;
        LastDeleteUrl := '';
        OperationSequence := '';
        DeleteFailureCount := 0;
        LastDeleteFailureProvider := '';
        LastDeleteFailureOutcome := '';
        LastDeleteFailureCode := '';
        LastDeleteFailureFileId := '';
        MaxDecodedBytesOverride := 0;
    end;

    /// <summary>Overrides the shared decoded file-size cap for one bound test. Zero restores the default.</summary>
    procedure ConfigureMaxDecodedBytes(NewMaxBytes: Integer)
    begin
        MaxDecodedBytesOverride := NewMaxBytes;
    end;

    /// <summary>Configures the next synthetic file-upload result.</summary>
    procedure ConfigureUpload(NewStatus: Integer; NewBody: Text)
    begin
        UploadStatus := NewStatus;
        UploadBody := NewBody;
    end;

    /// <summary>Configures the next synthetic file-delete result.</summary>
    procedure ConfigureDelete(NewStatus: Integer; NewBody: Text)
    begin
        DeleteStatus := NewStatus;
        DeleteBody := NewBody;
    end;

    /// <summary>Returns the actual number of prompt requests intercepted from the provider.</summary>
    procedure GetCallCount(): Integer
    begin
        exit(CallCount);
    end;

    /// <summary>Returns the credential-free JSON prompt request for payload assertions.</summary>
    procedure GetRequestBody(): Text
    begin
        exit(LastBody);
    end;

    /// <summary>Returns the prompt endpoint selected by the real provider.</summary>
    procedure GetRequestUrl(): Text
    begin
        exit(LastUrl);
    end;

    /// <summary>Returns how many file uploads the provider attempted.</summary>
    procedure GetUploadCount(): Integer
    begin
        exit(UploadCount);
    end;

    /// <summary>Returns how many file deletes the provider attempted.</summary>
    procedure GetDeleteCount(): Integer
    begin
        exit(DeleteCount);
    end;

    /// <summary>Returns the upload endpoint.</summary>
    procedure GetUploadUrl(): Text
    begin
        exit(LastUploadUrl);
    end;

    /// <summary>Returns the file name passed to the upload.</summary>
    procedure GetUploadFileName(): Text
    begin
        exit(LastUploadFileName);
    end;

    /// <summary>Returns the MIME type passed to the upload.</summary>
    procedure GetUploadMime(): Text
    begin
        exit(LastUploadMime);
    end;

    /// <summary>Returns the base64 content passed to the upload.</summary>
    procedure GetUploadContent(): Text
    begin
        exit(LastUploadBase64);
    end;

    /// <summary>Returns the delete endpoint.</summary>
    procedure GetDeleteUrl(): Text
    begin
        exit(LastDeleteUrl);
    end;

    /// <summary>Returns upload, prompt and delete attempts in order.</summary>
    procedure GetOperationSequence(): Text
    begin
        exit(OperationSequence);
    end;

    /// <summary>Returns how many failed provider-file deletes were signalled.</summary>
    procedure GetDeleteFailureCount(): Integer
    begin
        exit(DeleteFailureCount);
    end;

    /// <summary>Returns the provider named on the delete-failure signal.</summary>
    procedure GetDeleteFailureProvider(): Text
    begin
        exit(LastDeleteFailureProvider);
    end;

    /// <summary>Returns the HTTP outcome named on the delete-failure signal.</summary>
    procedure GetDeleteFailureOutcome(): Text
    begin
        exit(LastDeleteFailureOutcome);
    end;

    /// <summary>Returns the sanitised provider error code named on the delete-failure signal.</summary>
    procedure GetDeleteFailureCode(): Text
    begin
        exit(LastDeleteFailureCode);
    end;

    /// <summary>Returns the provider file id named on the delete-failure signal.</summary>
    procedure GetDeleteFailureFileId(): Text
    begin
        exit(LastDeleteFailureFileId);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforePromptPost', '', false, false)]
    local procedure OnBeforePromptPost(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
        CallCount += 1;
        OperationSequence += 'prompt;';
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

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforeFileUpload', '', false, false)]
    local procedure OnBeforeFileUpload(Url: Text; FileName: Text; MimeType: Text; ContentBase64: Text; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
        UploadCount += 1;
        OperationSequence += 'upload;';
        LastUploadUrl := Url;
        LastUploadFileName := FileName;
        LastUploadMime := MimeType;
        LastUploadBase64 := ContentBase64;
        Handled := true;
        Sent := UploadStatus <> 0;
        HttpStatus := UploadStatus;
        HttpBlocked := false;
        ResponseText := UploadBody;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforeFileDelete', '', false, false)]
    local procedure OnBeforeFileDelete(Url: Text; var Handled: Boolean; var Sent: Boolean; var HttpStatus: Integer; var HttpBlocked: Boolean; var ResponseText: Text)
    begin
        DeleteCount += 1;
        OperationSequence += 'delete;';
        LastDeleteUrl := Url;
        Handled := true;
        Sent := DeleteStatus <> 0;
        HttpStatus := DeleteStatus;
        HttpBlocked := false;
        ResponseText := DeleteBody;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel File Handling ori", 'OnProviderFileCleanupIssue', '', false, false)]
    local procedure OnProviderFileCleanupIssue(Provider: Text; HttpOutcome: Text; ProviderErrorCode: Text; FileId: Text)
    begin
        DeleteFailureCount += 1;
        LastDeleteFailureProvider := Provider;
        LastDeleteFailureOutcome := HttpOutcome;
        LastDeleteFailureCode := ProviderErrorCode;
        LastDeleteFailureFileId := FileId;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel File Handling ori", 'OnResolveMaxDecodedFileBytes', '', false, false)]
    local procedure OnResolveMaxDecodedFileBytes(var MaxBytes: Integer)
    begin
        if MaxDecodedBytesOverride > 0 then
            MaxBytes := MaxDecodedBytesOverride;
    end;
}
