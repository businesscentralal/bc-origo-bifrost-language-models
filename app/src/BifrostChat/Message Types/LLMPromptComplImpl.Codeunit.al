namespace Origo.Bifrost.LanguageModels;
using Microsoft.EServices.EDocument;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;
using System.Text;
using System.Utilities;

/// <summary>
/// One-shot LLM completion. Sends system + user prompt to the configured provider
/// and returns the text response. No tools, no chat Bootstrap, no conversation state.
/// </summary>
codeunit 10035396 "LLM Prompt Compl Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        PromptDeniedErr: Label 'You do not have permission to complete prompts with a language model.', Comment = 'is-IS=Þú hefur ekki heimild til að vinna kvaðningar með mállíkani.';
        PromptDeniedExpectedTxt: Label 'the BIFROST Chat ori permission set, and BIFROST LLM Chat ori for a language model whose provider is not Copilot', Comment = 'is-IS=heimildasamstæðan BIFROST Chat ori, og BIFROST LLM Chat ori fyrir mállíkan sem er ekki með Copilot sem veitanda';
        PromptDeniedNextStepTxt: Label 'Ask your administrator to assign the BIFROST Chat ori permission set, and BIFROST LLM Chat ori for a language model whose provider is not Copilot.', Comment = 'is-IS=Biddu kerfisstjóra um heimildasamstæðuna BIFROST Chat ori, og BIFROST LLM Chat ori fyrir mállíkan sem er ekki með Copilot sem veitanda.';
        MissingPromptErr: Label 'The prompt is missing.', Comment = 'is-IS=Kvaðninguna vantar.';
        PromptExpectedTxt: Label 'a non-empty text', Comment = 'is-IS=texti sem er ekki tómur';
        MissingPromptNextStepTxt: Label 'Send the text to complete in prompt.', Comment = 'is-IS=Sendu textann sem á að vinna í prompt.';
        RoleNotFoundErr: Label 'Bifrost Language Model "%1" was not found.', Comment = '%1 = language model code, is-IS=Bifröst mállíkanið "%1" fannst ekki.';
        RoleExpectedTxt: Label 'the code of a Bifrost Language Model', Comment = 'is-IS=kóði Bifröst mállíkans';
        RoleNotFoundNextStepTxt: Label 'Leave roleCode out to use your own or the default language model, or use a code from the Bifrost Language Models list.', Comment = 'is-IS=Slepptu roleCode til að nota þitt eigið eða sjálfgefna mállíkanið, eða notaðu kóða af listanum yfir Bifröst mállíkön.';
        NoProviderErr: Label 'No language model with a chat provider is set up for you.', Comment = 'is-IS=Ekkert mállíkan með spjallveitanda er sett upp fyrir þig.';
        NoProviderExpectedTxt: Label 'a Bifrost Language Model with a chat provider and an API key', Comment = 'is-IS=Bifröst mállíkan með spjallveitanda og API-lykli';
        NoProviderNextStepTxt: Label 'Ask your administrator to set up a language model on the Bifrost Language Models setup page, with its API key on Bifrost App Secrets.', Comment = 'is-IS=Biddu kerfisstjóra um að setja upp mállíkan á uppsetningarsíðu Bifröst mállíkana, með API-lykli þess í leyndarmálum forrita Bifröst.';
        ProviderFailedErr: Label 'The language model could not complete the prompt: %1', Comment = '%1 = the provider''s error text, is-IS=Mállíkanið gat ekki unnið kvaðninguna: %1';
        ProviderExpectedTxt: Label 'an answer from the language model', Comment = 'is-IS=svar frá mállíkaninu';
        ProviderFailedNextStepTxt: Label 'Check the language model''s Base URL, model and API key with Test Connection on the Bifrost Language Model card, then try again.', Comment = 'is-IS=Athugaðu grunnslóð, líkan og API-lykil mállíkansins með Prófa tengingu á spjaldi Bifröst mállíkansins og reyndu svo aftur.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription() Description: Text[250]
    var
        DescriptionLbl: Label 'One-shot LLM completion — send a prompt, get text back. No tools, no chat.', Comment = 'is-IS=Einskots LLM framkvæmd — senda kvaðningu, fá texta til baka. Engin tól, ekkert spjall.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'one-shot AI completion, prompt completion, generate text, transform text, classify text, extract data, summarize text, playbook reasoning, scheduled task AI', Comment = 'is-IS=einskots gervigreindarúrvinnsla, úrvinnsla kvaðningar, búa til texta, umbreyta texta, flokka texta, draga gögn út, draga saman texta, röksemdafærsla í verkferli, gervigreind í áætluðu verki';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Generates a text response from a prompt without tools, record context or conversation state; use a dedicated message type when one exists.', Comment = 'is-IS=Býr til textasvar úr kvaðningu án tóla, færslusamhengis eða samtalsstöðu; notaðu sérstaka boðgerð þegar hún er til.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The message type is identified by LLM.Prompt.Complete; no subject record is used.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('prompt', 'string', true, 'The user prompt sent to the language model.'));
        Parameters.Add(ContractMgt.Parameter('system', 'string', false, 'Optional system prompt sent as-is; no Bootstrap or skill is injected.'));
        Parameters.Add(ContractMgt.Parameter('roleCode', 'string', false, 'Optional Bifrost Language Model code. When omitted, the caller''s configured or default model is used.'));
        Parameters.Add(ContractMgt.Parameter('file', 'object', false, 'Optional inline file object with data, mimeType and fileName; takes precedence over attachment.'));
        Parameters.Add(ContractMgt.Parameter('attachment', 'object', false, 'Optional stored attachment reference with table and systemId; ignored when file is supplied or the record cannot be resolved.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the provider response was returned.'));
        Fields.Add(ContractMgt.ResponseField('reply', 'string', 'The provider response text, when supplied by the provider.'));
        Fields.Add(ContractMgt.ResponseField('text', 'string', 'A copy of reply, added when the provider did not return text.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        // The rows share their labels with the live answers; Msg Contract Mgt ori builds the chapters in English.
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PromptDeniedErr, 'The caller does not hold Foundation''s BIFROST Chat ori permission set. A language model whose provider is not Copilot also needs this app''s BIFROST LLM Chat ori.', PromptDeniedNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingPromptErr, 'prompt is missing or empty.', MissingPromptNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RoleNotFoundErr, 'roleCode is sent but no language model has that code.', RoleNotFoundNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NoProviderErr, 'The selected, the caller''s or the default language model has no usable chat provider or API key.', NoProviderNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ProviderFailedErr, 'The provider cannot complete the request, including a file it does not accept; %1 is the provider''s own error text.', ProviderFailedNextStepTxt));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Sends the prompt to the selected external language model and returns its response; no Business Central records are changed.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Chat ori; BIFROST LLM Chat ori for non-Copilot providers');
        Effect.Add('preconditions', 'Foundation chat permission is assigned and a usable language model and provider are configured.');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Read Business Central data first, then use the returned values in the prompt.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Set', 'Use the completion as input for structured record updates only after validating the generated values.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Complete a prompt with a selected model', '{"prompt":"Summarize this text.","system":"Return one concise sentence.","roleCode":"CLAUDE"}', '{"status":"Success","reply":"A concise summary.","text":"A concise summary."}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Use LLM.Prompt.Complete for one-shot reasoning, transformation, extraction, classification or generation when no dedicated message type covers the task. It sends one user prompt and optional system prompt to a configured provider without tools, record context or conversation state.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'If roleCode is omitted, the caller''s configured language model is used and then the default model is tried. An inline file takes precedence over a stored attachment. Providers may reject files, and provider response properties other than status, reply and text are passed through.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    [NonDebuggable]
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TempChatArg: Record "Bifrost Chat Argument ori" temporary;
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ChatProvider: Codeunit "LangModel Chat Provider ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        Provider: Interface "Bifrost LangModel Provider ori";
        RequestJson: JsonObject;
        PayloadJson: JsonObject;
        MessagesArray: JsonArray;
        MessageObj: JsonObject;
        ResponseJson: JsonObject;
        ResponseText: Text;
        SystemPrompt: Text;
        UserPrompt: Text;
        RoleCode: Code[20];
        RoleCodeText: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not BifrostChatMgt.HasChatPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PromptDeniedErr, '', '', PromptDeniedExpectedTxt, PromptDeniedNextStepTxt);
            exit;
        end;

        RequestJson := Argument.GetRequestJson();
        UserPrompt := GetTextValue(RequestJson, 'prompt');
        if UserPrompt = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingPromptErr, 'prompt', '', PromptExpectedTxt, MissingPromptNextStepTxt);
            exit;
        end;

        RoleCodeText := GetTextValue(RequestJson, 'roleCode');
        if StrLen(RoleCodeText) > MaxStrLen(RoleCode) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(RoleNotFoundErr, RoleCodeText), 'roleCode', RoleCodeText, RoleExpectedTxt, RoleNotFoundNextStepTxt);
            exit;
        end;
        RoleCode := CopyStr(RoleCodeText, 1, MaxStrLen(RoleCode));
        if (RoleCode <> '') and (not BifrostLanguageModel.Get(RoleCode)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(RoleNotFoundErr, RoleCodeText), 'roleCode', RoleCodeText, RoleExpectedTxt, RoleNotFoundNextStepTxt);
            exit;
        end;

        if RoleCode <> '' then
            Provider := BifrostLanguageModel."Chat Provider"
        else
            Provider := ChatProvider.GetLangModelProviderWithModel(BifrostLanguageModel);
        BuildChatArgument(BifrostLanguageModel, TempChatArg);
        TempChatArg."Procedure Type" := TempChatArg."Procedure Type"::IsConfigured;
        Provider.Execute(TempChatArg);
        if not TempChatArg."Result Boolean" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoProviderErr, 'roleCode', RoleCodeText, NoProviderExpectedTxt, NoProviderNextStepTxt);
            exit;
        end;

        SystemPrompt := GetTextValue(RequestJson, 'system');
        if SystemPrompt <> '' then
            PayloadJson.Add('systemPrompt', SystemPrompt);

        MessageObj.Add('role', 'user');
        MessageObj.Add('content', UserPrompt);
        MessagesArray.Add(MessageObj);
        PayloadJson.Add('messages', MessagesArray);
        AddFileContent(RequestJson, PayloadJson);

        PayloadJson.WriteTo(ResponseText);
        TempChatArg.SetPayload(ResponseText);
        TempChatArg."Procedure Type" := TempChatArg."Procedure Type"::CompletePrompt;
        TempChatArg.SetResultText('');
        Provider.Execute(TempChatArg);
        ResponseText := TempChatArg.GetResultText();
        LangModelSecrets.MarkApiKeyUsed(BifrostLanguageModel.Code);

        if not ResponseJson.ReadFrom(ResponseText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ProviderFailedErr, ResponseText), '', '', ProviderExpectedTxt, ProviderFailedNextStepTxt);
            exit;
        end;

        if HasProperty(ResponseJson, 'error') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ProviderFailedErr, GetTextValue(ResponseJson, 'error')), '', '', ProviderExpectedTxt, ProviderFailedNextStepTxt);
            exit;
        end;

        ResponseJson.Add('status', 'Success');
        if not HasProperty(ResponseJson, 'text') then
            if HasProperty(ResponseJson, 'reply') then
                ResponseJson.Add('text', GetTextValue(ResponseJson, 'reply'));

        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure GetTextValue(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure HasProperty(Source: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        exit(Source.Get(PropertyName, Token));
    end;

    [NonDebuggable]
    local procedure BuildChatArgument(var BifrostLanguageModel: Record "Bifrost Language Model ori"; var TempChatArg: Record "Bifrost Chat Argument ori" temporary)
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ApiKeyValue: SecretText;
    begin
        TempChatArg.Init();
        TempChatArg."Language Model SystemId" := BifrostLanguageModel.SystemId;
        TempChatArg."Base URL" := BifrostLanguageModel."Base URL";
        TempChatArg.Model := BifrostLanguageModel.Model;
        TempChatArg."Timeout Ms" := BifrostLanguageModel."Timeout Seconds" * 1000;
        TempChatArg."Max Tokens" := BifrostLanguageModel."Max Tokens";
        TempChatArg."Context Tokens" := BifrostLanguageModel.GetContextTokens();
        if LangModelSecrets.TryGetApiKey(BifrostLanguageModel.Code, ApiKeyValue) then
            TempChatArg.SetApiKey(ApiKeyValue);
    end;

    local procedure AddFileContent(RequestJson: JsonObject; var PayloadJson: JsonObject)
    var
        FileToken: JsonToken;
        AttachmentToken: JsonToken;
        FileJson: JsonObject;
        FilesArray: JsonArray;
    begin
        if RequestJson.Get('file', FileToken) then begin
            if FileToken.IsObject() then begin
                FilesArray.Add(FileToken);
                PayloadJson.Add('files', FilesArray);
            end;
            exit;
        end;

        if RequestJson.Get('attachment', AttachmentToken) then
            if AttachmentToken.IsObject() then
                if ResolveAttachment(AttachmentToken.AsObject(), FileJson) then begin
                    FilesArray.Add(FileJson);
                    PayloadJson.Add('files', FilesArray);
                end;
    end;

    local procedure ResolveAttachment(AttachmentJson: JsonObject; var FileJson: JsonObject): Boolean
    var
        TableName: Text;
    begin
        TableName := GetTextValue(AttachmentJson, 'table');
        case TableName of
            'Incoming Document Attachment':
                exit(ResolveIncomingDocAttachment(AttachmentJson, FileJson));
            'Document Attachment':
                exit(ResolveDocumentAttachment(AttachmentJson, FileJson));
            else
                exit(false);
        end;
    end;

    local procedure ResolveIncomingDocAttachment(AttachmentJson: JsonObject; var FileJson: JsonObject): Boolean
    var
        IncomingDocAttachment: Record "Incoming Document Attachment";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        InStream: InStream;
        SystemIdGuid: Guid;
        FileName: Text;
    begin
        if not Evaluate(SystemIdGuid, GetTextValue(AttachmentJson, 'systemId')) then
            exit(false);
        IncomingDocAttachment.SetLoadFields(Name, "File Extension", Content);
        if not IncomingDocAttachment.GetBySystemId(SystemIdGuid) then
            exit(false);
        if not IncomingDocAttachment.GetContent(TempBlob) then
            exit(false);
        TempBlob.CreateInStream(InStream);
        FileName := IncomingDocAttachment.Name;
        if (FileName <> '') and (IncomingDocAttachment."File Extension" <> '') then
            if not FileName.EndsWith('.' + IncomingDocAttachment."File Extension") then
                FileName += '.' + IncomingDocAttachment."File Extension";
        FileJson.Add('data', Base64Convert.ToBase64(InStream));
        FileJson.Add('mimeType', GuessMimeType(IncomingDocAttachment."File Extension"));
        FileJson.Add('fileName', FileName);
        exit(true);
    end;

    local procedure ResolveDocumentAttachment(AttachmentJson: JsonObject; var FileJson: JsonObject): Boolean
    var
        DocAttachment: Record "Document Attachment";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        InStream: InStream;
        SystemIdGuid: Guid;
        FileName: Text;
    begin
        if not Evaluate(SystemIdGuid, GetTextValue(AttachmentJson, 'systemId')) then
            exit(false);
        DocAttachment.SetLoadFields("File Name", "File Extension");
        if not DocAttachment.GetBySystemId(SystemIdGuid) then
            exit(false);
        DocAttachment.GetAsTempBlob(TempBlob);
        if not TempBlob.HasValue() then
            exit(false);
        TempBlob.CreateInStream(InStream);
        FileName := DocAttachment."File Name";
        if (FileName <> '') and (DocAttachment."File Extension" <> '') then
            if not FileName.EndsWith('.' + DocAttachment."File Extension") then
                FileName += '.' + DocAttachment."File Extension";
        FileJson.Add('data', Base64Convert.ToBase64(InStream));
        FileJson.Add('mimeType', GuessMimeType(DocAttachment."File Extension"));
        FileJson.Add('fileName', FileName);
        exit(true);
    end;

    local procedure GuessMimeType(FileExtension: Text): Text
    begin
        case LowerCase(DelChr(FileExtension, '<>', '.')) of
            'pdf':
                exit('application/pdf');
            'png':
                exit('image/png');
            'jpg', 'jpeg':
                exit('image/jpeg');
            'gif':
                exit('image/gif');
            'webp':
                exit('image/webp');
            'xml':
                exit('application/xml');
            'json':
                exit('application/json');
            'txt', 'csv':
                exit('text/plain');
            else
                exit('application/octet-stream');
        end;
    end;
}
