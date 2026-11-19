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
        MissingErr: Label 'The staged upload was not found.', Comment = 'is-IS=Upphleðsla fannst ekki í biðgeymslu.';
        UploadAgainTxt: Label 'Upload the file again and send its new stagingId.', Comment = 'is-IS=Hladdu skránni upp aftur og sendu nýtt stagingId hennar.';
        InvalidTypeErr: Label 'The attachment content type is not supported.', Comment = 'is-IS=Efnisgerð viðhengisins er ekki studd.';
        AllowedTypesTxt: Label 'text/*, application/json, application/pdf, image/png, image/jpeg', Locked = true;
        LimitErr: Label 'The total attachment size exceeds the language model limit.', Comment = 'is-IS=Heildarstærð viðhengja er yfir mörkum mállíkansins.';
        InlineFileShapeErr: Label 'The inline file must be an object with data (Base64), mimeType and fileName.', Comment = 'is-IS=Innbyggða skráin verður að vera hlutur með data (Base64), mimeType og fileName.';
        InlineFileShapeExpectedTxt: Label 'an object with data, mimeType and fileName', Comment = 'is-IS=hlutur með data, mimeType og fileName';
        InlineFilesShapeExpectedTxt: Label 'an array of objects with data, mimeType and fileName', Comment = 'is-IS=fylki hluta með data, mimeType og fileName';
        InlineFileFixTxt: Label 'Send file or files with data, mimeType and fileName, or use attachments with a stagingId.', Comment = 'is-IS=Sendu file eða files með data, mimeType og fileName, eða notaðu attachments með stagingId.';
        InlineTypeErr: Label 'The inline file content type is not supported.', Comment = 'is-IS=Efnisgerð innbyggðu skrárinnar er ekki studd.';
        InlineTypeNextTxt: Label 'Send text, PDF, PNG or JPEG. No request was sent.', Comment = 'is-IS=Sendu texta, PDF, PNG eða JPEG. Engin beiðni var send.';
        InlineCountErr: Label 'Too many files: inline files and staged attachments together exceed the limit.', Comment = 'is-IS=Of margar skrár: innbyggðar skrár og viðhengi úr biðgeymslu eru samanlagt yfir mörkunum.';
        InlineCountExpectedTxt: Label 'at most %1 files in total', Comment = '%1 = file count limit, is-IS=í mesta lagi %1 skrár samtals';
        InlineCountNextTxt: Label 'Send fewer files. No request was sent.', Comment = 'is-IS=Sendu færri skrár. Engin beiðni var send.';
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
            if not ((ContentType.StartsWith('text/') and (StrLen(ContentType) > 5)) or (ContentType in ['application/json', 'application/pdf', 'image/png', 'image/jpeg'])) then begin
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

    /// <summary>Maximum number of files (inline and staged together) on one LLM.Prompt.Ask call.</summary>
    procedure MaxFilesPerCall(): Integer
    begin
        exit(10);
    end;

    /// <summary>
    /// Adds the optional inline file or files (#127) to the files already resolved from staging. file wins over files, as in
    /// LLM.Prompt.Complete. Refuses a bad shape, an unsupported type, too many files and a combined size over the model limit,
    /// all before any provider call. Provider uploads are made, and removed again, by the provider payload path.
    /// </summary>
    /// <param name="Argument">Receives a coded refusal without calling a provider.</param>
    /// <param name="Request">Prompt data containing optional file or files.</param>
    /// <param name="Model">Resolved model and its aggregate attachment byte limit.</param>
    /// <param name="Files">Staged files in, staged and inline files out (staged first, then inline in request order).</param>
    /// <returns>True when every inline file was accepted, otherwise false.</returns>
    [NonDebuggable]
    procedure ResolveInline(var Argument: Record "Message Argument ori"; Request: JsonObject; Model: Record "Bifrost Language Model ori"; var Files: JsonArray): Boolean
    var
        FileHandling: Codeunit "LangModel File Handling ori";
        Source: JsonToken;
        Entry: JsonToken;
        Existing: JsonToken;
        Inline: JsonArray;
        Accepted: JsonObject;
        Index: Integer;
        TotalBytes: BigInteger;
        LimitBytes: Integer;
        Single: Boolean;
        ParameterName: Text;
        ContentType: Text;
        DataText: Text;
    begin
        if Request.Get('file', Source) then begin
            if not Source.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InlineFileShapeErr, 'file', '', InlineFileShapeExpectedTxt, InlineFileFixTxt);
                exit(false);
            end;
            Inline.Add(Source);
            Single := true;
        end else
            if Request.Get('files', Source) then begin
                if not Source.IsArray() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InlineFileShapeErr, 'files', '', InlineFilesShapeExpectedTxt, InlineFileFixTxt);
                    exit(false);
                end;
                Inline := Source.AsArray();
            end;
        if Inline.Count() = 0 then
            exit(true);
        if Files.Count() + Inline.Count() > MaxFilesPerCall() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, InlineCountErr, FileParameterName(Single, 0), Format(Files.Count() + Inline.Count(), 0, 9), StrSubstNo(InlineCountExpectedTxt, Format(MaxFilesPerCall(), 0, 9)), InlineCountNextTxt);
            exit(false);
        end;
        LimitBytes := Model."Attachment Limit Bytes";
        if LimitBytes = 0 then
            LimitBytes := FileHandling.MaxTotalDecodedFileBytes();
        foreach Existing in Files do
            TotalBytes += FileHandling.DecodedByteCount(TextValue(Existing, 'data'));
        foreach Entry in Inline do begin
            Index += 1;
            ParameterName := FileParameterName(Single, Index);
            if not Entry.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InlineFileShapeErr, ParameterName, '', InlineFileShapeExpectedTxt, InlineFileFixTxt);
                exit(false);
            end;
            DataText := TextValue(Entry, 'data');
            if DataText = '' then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, InlineFileShapeErr, ParameterName + '.data', '', InlineFileShapeExpectedTxt, InlineFileFixTxt);
                exit(false);
            end;
            ContentType := FileHandling.NormalizeMimeType(TextValue(Entry, 'mimeType'));
            if not ((ContentType.StartsWith('text/') and (StrLen(ContentType) > 5)) or (ContentType in ['application/json', 'application/pdf', 'image/png', 'image/jpeg'])) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InlineTypeErr, ParameterName + '.mimeType', ContentType, AllowedTypesTxt, InlineTypeNextTxt);
                exit(false);
            end;
            TotalBytes += FileHandling.DecodedByteCount(DataText);
            if TotalBytes > LimitBytes then begin
                Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, LimitErr, 'files', Format(TotalBytes, 0, 9), StrSubstNo(BytesExpectedTxt, Format(LimitBytes, 0, 9)), LimitNextTxt);
                exit(false);
            end;
            Clear(Accepted);
            Accepted.Add('data', DataText);
            Accepted.Add('mimeType', ContentType);
            Accepted.Add('fileName', TextValue(Entry, 'fileName'));
            Files.Add(Accepted);
        end;
        exit(true);
    end;

    local procedure FileParameterName(Single: Boolean; Index: Integer): Text
    begin
        if Single then
            exit('file');
        if Index = 0 then
            exit('files');
        exit('files[' + Format(Index - 1, 0, 9) + ']');
    end;

    local procedure TextValue(Source: JsonToken; PropertyName: Text): Text
    var
        Property: JsonToken;
        JsonText: Text;
    begin
        if not Source.IsObject() then
            exit('');
        if not Source.AsObject().Get(PropertyName, Property) then
            exit('');
        if not Property.IsValue() then
            exit('');
        Property.WriteTo(JsonText);
        if not JsonText.StartsWith('"') then
            exit('');
        exit(Property.AsValue().AsText());
    end;

    /// <summary>Adds the shared staging-only attachment parameter.</summary>
    procedure AddParameter(var Parameters: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parameter: JsonObject;
        Children: JsonArray;
    begin
        Parameter := ContractMgt.Parameter('attachments', 'array', false, 'Files uploaded to Foundation staging, in order. Each entry has exactly one key, stagingId. The caller-owned upload is consumed in this transaction. Supports text/*, application/json, application/pdf, image/png and image/jpeg. Total bytes must fit the language model Attachment Limit Bytes (0 uses 100 MB). Invalid uploads never call the model or incur a provider charge. Upload again after a refusal.');
        Children.Add(ContractMgt.Parameter('stagingId', 'string', true, 'The GUID returned when the caller uploaded the file to Foundation staging.'));
        Parameter.Add('children', Children);
        Parameters.Add(Parameter);
    end;

    /// <summary>Adds the inline file and files parameters of LLM.Prompt.Ask (#127), same shape as LLM.Prompt.Complete.</summary>
    procedure AddInlineParameters(var Parameters: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        FileParameter: JsonObject;
        FilesParameter: JsonObject;
    begin
        FileParameter := ContractMgt.Parameter('file', 'object', false, 'Optional inline file sent with the question, for a PDF or picture an earlier playbook step produced. Takes precedence over files. Same shape as LLM.Prompt.Complete. Can be combined with attachments; inline and staged files together are limited to 10 files and to the language model Attachment Limit Bytes (0 uses 100 MB). A value that is not an object is refused with InvalidParameterFormat.');
        FileParameter.Add('children', InlineChildren());
        Parameters.Add(FileParameter);
        FilesParameter := ContractMgt.Parameter('files', 'array', false, 'Optional inline files sent with the question when file is absent. Each entry is an object with data, mimeType and fileName. Supports text/*, application/json, application/pdf, image/png and image/jpeg; another type is refused with InvalidParameter before any provider call. Inline and staged files together are limited to 10 files; a bigger set is refused with LimitExceeded. Provider uploads made for the files are deleted after the call, including when it fails.');
        FilesParameter.Add('children', InlineChildren());
        Parameters.Add(FilesParameter);
    end;

    /// <summary>Describes inline file refusals with the same labels as the runtime answers.</summary>
    procedure AddInlineErrors(var Errors: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InlineFileShapeErr, 'file is not an object, files is not an array, or an entry is not an object.', InlineFileFixTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, InlineFileShapeErr, 'An inline file has no data.', InlineFileFixTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InlineTypeErr, 'An inline file is not text, JSON, PDF, PNG or JPEG.', InlineTypeNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, InlineCountErr, 'Inline and staged files together are more than 10.', InlineCountNextTxt));
    end;

    local procedure InlineChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.Parameter('data', 'string', false, 'The file content, Base64-encoded. Required together with mimeType.'));
        Children.Add(ContractMgt.Parameter('mimeType', 'string', false, 'The MIME type, for example application/pdf or image/png. Spaces, letter case and parameters after a semicolon are ignored.'));
        Children.Add(ContractMgt.Parameter('fileName', 'string', false, 'The file name. Used by the providers that take a file name; the others ignore it.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidTypeErr, 'An attachment is not text, JSON, PDF, PNG or JPEG.', UploadAgainTxt));
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
