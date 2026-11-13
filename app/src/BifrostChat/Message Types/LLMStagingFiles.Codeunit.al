namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;
using System.Text;
using System.Utilities;

/// <summary>Resolves caller-owned staging attachments for both prompt types, without depending on Attachments.</summary>
codeunit 10035435 "LLM Staging Files ori"
{
    Access = Internal;

    var
        ArrayExpectedTxt: Label 'an array of objects with stagingId', Comment = 'is-IS=fylki hluta með stagingId';
        ObjectExpectedTxt: Label 'an object with stagingId GUID', Comment = 'is-IS=hlutur með stagingId GUID';
        GuidExpectedTxt: Label 'a stagingId GUID', Comment = 'is-IS=stagingId GUID';
        OwnedExpectedTxt: Label 'an unused stagingId owned by the caller', Comment = 'is-IS=ónotað stagingId í eigu kallandans';
        BytesExpectedTxt: Label 'at most %1 bytes', Comment = '%1 = model byte limit, is-IS=í mesta lagi %1 bæti';
        FormatErr: Label 'The attachment must contain one stagingId GUID.', Comment = 'is-IS=Viðhengið verður að innihalda eitt stagingId GUID.';
        UnknownErr: Label 'The attachment contains an unknown parameter.', Comment = 'is-IS=Viðhengið inniheldur óþekkta færibreytu.';
        MissingErr: Label 'The staged upload was not found.', Comment = 'is-IS=Upphlaðna skjalið fannst ekki í biðgeymslu.';
        UploadAgainTxt: Label 'Upload the file again and send its new stagingId.', Comment = 'is-IS=Hladdu skránni upp aftur og sendu nýtt stagingId hennar.';
        InvalidTypeErr: Label 'The attachment content type is not supported.', Comment = 'is-IS=Efnisgerð viðhengisins er ekki studd.';
        AllowedTypesTxt: Label 'text/*, application/pdf, image/png, image/jpeg', Locked = true;
        LimitErr: Label 'The total attachment size exceeds the language model limit.', Comment = 'is-IS=Heildarstærð viðhengja er yfir mörkum mállíkansins.';
        LimitNextTxt: Label 'Send smaller files or ask your administrator to change the model attachment limit.', Comment = 'is-IS=Sendu minni skrár eða biddu kerfisstjóra um að breyta stærðarmörkum viðhengja mállíkansins.';

    /// <summary>Validates all entry shapes before taking uploads in order in the caller transaction. No provider is called here.</summary>
    /// <param name="Argument">Receives a coded refusal without calling a provider.</param>
    /// <param name="Request">Prompt data containing optional attachments.</param>
    /// <param name="Model">Resolved model and its aggregate attachment byte limit.</param>
    /// <param name="Files">Receives provider-format files in the request order.</param>
    /// <returns>True when every attachment was resolved, otherwise false.</returns>
    [NonDebuggable]
    procedure Resolve(var Argument: Record "Message Argument ori"; Request: JsonObject; Model: Record "Bifrost Language Model ori"; var Files: JsonArray): Boolean
    var
        Staging: Codeunit "Blob Staging ori";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        FileHandling: Codeunit "LangModel File Handling ori";
        Attachments: JsonToken;
        Entry: JsonToken;
        IdToken: JsonToken;
        Item: JsonObject;
        FileObject: JsonObject;
        Ids: List of [Guid];
        StagingId: Guid;
        Input: InStream;
        KeyName: Text;
        ParameterName: Text;
        ContentType: Text;
        FileName: Text;
        Index: Integer;
        TotalBytes: BigInteger;
        LimitBytes: Integer;
    begin
        Clear(Files);
        if not Request.Get('attachments', Attachments) then
            exit(true);
        if not Attachments.IsArray() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, 'attachments', '', ArrayExpectedTxt, UploadAgainTxt);
            exit(false);
        end;
        foreach Entry in Attachments.AsArray() do begin
            Index += 1;
            ParameterName := 'attachments[' + Format(Index, 0, 9) + '].stagingId';
            if not Entry.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, ParameterName, '', ObjectExpectedTxt, UploadAgainTxt);
                exit(false);
            end;
            Item := Entry.AsObject();
            foreach KeyName in Item.Keys() do
                if KeyName <> 'stagingId' then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownErr, 'attachments[' + Format(Index, 0, 9) + '].' + KeyName, '', 'stagingId', UploadAgainTxt);
                    exit(false);
                end;
            if not Item.Get('stagingId', IdToken) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, FormatErr, ParameterName, '', GuidExpectedTxt, UploadAgainTxt);
                exit(false);
            end;
            if not IsGuid(IdToken, StagingId) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, ParameterName, '', GuidExpectedTxt, UploadAgainTxt);
                exit(false);
            end;
            if Ids.Contains(StagingId) or not Staging.Exists(StagingId) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, ParameterName, Format(StagingId, 0, 4), OwnedExpectedTxt, UploadAgainTxt);
                exit(false);
            end;
            Ids.Add(StagingId);
        end;
        LimitBytes := Model."Attachment Limit Bytes";
        if LimitBytes = 0 then
            LimitBytes := FileHandling.MaxTotalDecodedFileBytes();
        Index := 0;
        foreach StagingId in Ids do begin
            Index += 1;
            ParameterName := 'attachments[' + Format(Index, 0, 9) + '].stagingId';
            if not Staging.Take(StagingId, TempBlob, ContentType, FileName) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, ParameterName, Format(StagingId, 0, 4), OwnedExpectedTxt, UploadAgainTxt);
                exit(false);
            end;
            ContentType := FileHandling.NormalizeMimeType(ContentType);
            if not ((ContentType.StartsWith('text/') and (StrLen(ContentType) > 5)) or (ContentType in ['application/pdf', 'image/png', 'image/jpeg'])) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidTypeErr, ParameterName, ContentType, AllowedTypesTxt, UploadAgainTxt);
                exit(false);
            end;
            TotalBytes += TempBlob.Length();
            if TotalBytes > LimitBytes then begin
                Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, LimitErr, 'attachments', Format(TotalBytes, 0, 9), StrSubstNo(BytesExpectedTxt, Format(LimitBytes, 0, 9)), LimitNextTxt);
                exit(false);
            end;
            Clear(FileObject);
            TempBlob.CreateInStream(Input);
            FileObject.Add('data', Base64Convert.ToBase64(Input));
            FileObject.Add('mimeType', ContentType);
            FileObject.Add('fileName', FileName);
            Files.Add(FileObject);
        end;
        exit(true);
    end;

    /// <summary>Adds the shared staging-only attachment parameter.</summary>
    procedure AddParameter(var Parameters: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parameter: JsonObject;
        Children: JsonArray;
    begin
        Parameter := ContractMgt.Parameter('attachments', 'array', false, 'Files uploaded to Foundation staging, in order. Each entry has exactly one key, stagingId. The caller-owned upload is consumed in this transaction. Supports text/*, application/pdf, image/png and image/jpeg. Total bytes must fit the language model Attachment Limit Bytes (0 uses 100 MB). Invalid uploads never call the model or incur a provider charge. Upload again after a refusal.');
        Children.Add(ContractMgt.Parameter('stagingId', 'string', true, 'The GUID returned when the caller uploaded the file to Foundation staging.'));
        Parameter.Add('children', Children);
        Parameters.Add(Parameter);
    end;

    /// <summary>Names storage-to-staging paths only when an installed extension registers them.</summary>
    procedure AddRelated(var Related: JsonArray)
    begin
        AddRelatedFromTypes(Related, Enum::"Message Type ori".Names());
    end;

    /// <summary>Builds related help from the installed registry names; an empty registry advertises no storage type.</summary>
    procedure AddRelatedFromTypes(var Related: JsonArray; Names: List of [Text])
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TypeName: Text;
    begin
        foreach TypeName in Names do
            if TypeName in ['Storage.Upload.CommitToStaging', 'Storage.File.CopyToStaging'] then
                Related.Add(ContractMgt.RelatedEntry(TypeName, 'Put the file in Foundation staging, then send the returned stagingId in attachments.'));
    end;

    /// <summary>Describes staging refusals with the same labels as the runtime answers.</summary>
    procedure AddErrors(var Errors: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownErr, 'An attachments entry has a key other than stagingId.', UploadAgainTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, 'attachments is not an array of objects with a stagingId GUID.', UploadAgainTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, FormatErr, 'An attachments entry has no stagingId.', UploadAgainTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, MissingErr, 'An upload is unknown, owned by another user, duplicated or already consumed.', UploadAgainTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidTypeErr, 'An attachment is not text, PDF, PNG or JPEG.', UploadAgainTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, LimitErr, 'The attachments total exceeds the model attachment byte limit.', LimitNextTxt));
    end;

    local procedure IsGuid(Token: JsonToken; var Value: Guid): Boolean
    var
        JsonText: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(JsonText);
        if not JsonText.StartsWith('"') then
            exit(false);
        exit(Evaluate(Value, Token.AsValue().AsText()));
    end;
}
