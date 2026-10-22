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
        PromptDeniedWhenTxt: Label 'The caller does not hold Foundation''s BIFROST Chat ori permission set. A language model whose provider is not Copilot also needs this app''s BIFROST LLM Chat ori.', Comment = 'is-IS=Kallandinn hefur ekki heimildasamstæðuna BIFROST Chat ori úr Foundation. Ef veitandi mállíkansins er ekki Copilot þarf einnig BIFROST LLM Chat ori úr þessu forriti.';
        MissingPromptWhenTxt: Label 'prompt is missing or empty.', Comment = 'is-IS=prompt vantar eða er tómt.';
        RoleNotFoundWhenTxt: Label 'roleCode is sent but no language model has that code.', Comment = 'is-IS=roleCode er sent en ekkert mállíkan hefur þann kóða.';
        NoProviderWhenTxt: Label 'The selected, the caller''s or the default language model has no usable chat provider or API key.', Comment = 'is-IS=Valið mállíkan, mállíkan kallandans eða sjálfgefna mállíkanið hefur engan nothæfan spjallveitanda eða API-lykil.';
        PromptDeniedErr: Label 'You do not have permission to complete prompts with a language model.', Comment = 'is-IS=Þú hefur ekki heimild til að vinna kvaðningar með mállíkani.';
        PromptDeniedExpectedTxt: Label 'the BIFROST Chat ori permission set, and BIFROST LLM Chat ori for a language model whose provider is not Copilot', Comment = 'is-IS=heimildasamstæðan BIFROST Chat ori og einnig BIFROST LLM Chat ori ef veitandi mállíkansins er ekki Copilot';
        PromptDeniedNextStepTxt: Label 'Ask your administrator to assign the BIFROST Chat ori permission set, and BIFROST LLM Chat ori for a language model whose provider is not Copilot.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta þér heimildasamstæðunni BIFROST Chat ori og einnig BIFROST LLM Chat ori ef veitandi mállíkansins er ekki Copilot.';
        MissingPromptErr: Label 'The prompt is missing.', Comment = 'is-IS=Kvaðninguna vantar.';
        PromptExpectedTxt: Label 'a non-empty JSON string', Comment = 'is-IS=JSON-strengur sem er ekki tómur';
        InvalidPromptErr: Label 'The prompt must be a JSON string.', Comment = 'is-IS=Kvaðningin í prompt verður að vera JSON-strengur.';
        InvalidPromptWhenTxt: Label 'prompt is a number, Boolean, null, object or array instead of a JSON string.', Comment = 'is-IS=prompt er tala, rökgildi, null, hlutur eða fylki í stað JSON-strengs.';
        MissingPromptNextStepTxt: Label 'Send the text to complete in prompt.', Comment = 'is-IS=Sendu textann sem á að vinna í prompt.';
        RoleNotFoundErr: Label 'Bifrost Language Model "%1" was not found.', Comment = '%1 = language model code, is-IS=Bifröst mállíkanið "%1" fannst ekki.';
        RoleExpectedTxt: Label 'the code of a Bifrost Language Model', Comment = 'is-IS=kóði Bifröst mállíkans';
        RoleNotFoundNextStepTxt: Label 'Leave roleCode out to use your own or the default language model, or use a code from the Bifrost Language Models list.', Comment = 'is-IS=Slepptu roleCode til að nota þitt eigið eða sjálfgefna mállíkanið, eða notaðu kóða af listanum yfir Bifröst mállíkön.';
        NoProviderErr: Label 'No language model with a chat provider is set up for you.', Comment = 'is-IS=Ekkert mállíkan með spjallveitanda er sett upp fyrir þig.';
        NoProviderExpectedTxt: Label 'a Bifrost Language Model with a chat provider and an API key', Comment = 'is-IS=Bifröst mállíkan með spjallveitanda og API-lykli';
        NoProviderNextStepTxt: Label 'Ask your administrator to set up a language model on the Bifrost Language Models setup page, with its API key on Bifrost App Secrets.', Comment = 'is-IS=Biddu kerfisstjóra um að setja upp mállíkan á uppsetningarsíðu Bifröst mállíkana, með API-lykli þess í leyndarmálum forrita Bifröst.';

    /// <summary>
    /// Reports that the message type implementation is enabled.
    /// </summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>
    /// Returns zero because this completion does not filter a target table.
    /// </summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>
    /// Returns the localized description of the one-shot completion message type.
    /// </summary>
    procedure GetDescription() Description: Text[250]
    var
        DescriptionLbl: Label 'Sends one prompt to a language model and returns its text answer, with no tools, record context or conversation.', Comment = 'is-IS=Sendir eina kvaðningu til mállíkans og skilar textasvari þess, án verkfæra, færslusamhengis eða samtals.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>
    /// Returns localized search terms for discovering one-shot language model completions.
    /// </summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'one-shot AI completion, prompt completion, generate text, transform text, classify text, extract data, summarize text, playbook reasoning, scheduled task AI, language model, LLM, ask AI, read document with AI, read image with AI', Comment = 'is-IS=einskots gervigreindarúrvinnsla, úrvinnsla kvaðningar, búa til texta, umbreyta texta, flokka texta, draga gögn út, draga saman texta, röksemdafærsla í verkferli, gervigreind í tímasettu bakgrunnsverkefni, mállíkan, LLM, spyrja gervigreind, lesa skjal með gervigreind, lesa mynd með gervigreind';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>
    /// Explains when to select a one-shot completion instead of a dedicated message type.
    /// </summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Read-only. Generates a text response from a prompt without tools, record context or conversation state; nothing is remembered between calls. Use a dedicated message type when one exists, and Data.Records.Get first when the prompt needs Business Central data.', Comment = 'is-IS=Eingöngu lestur. Býr til textasvar úr kvaðningu án verkfæra, færslusamhengis eða samtalsstöðu; ekkert er munað milli kalla. Notaðu sérstaka skilaboðategund þegar hún er til og Data.Records.Get fyrst þegar kvaðningin þarf gögn úr Business Central.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>
    /// Describes the required JSON data envelope without a subject record.
    /// </summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        StrictOption: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The type addresses no record; a subject that is sent is ignored.');
        StrictOption.Add('type', 'boolean');
        StrictOption.Add('required', false);
        StrictOption.Add('default', false);
        StrictOption.Add('description', 'Optional root Boolean, default false. When true, unknown data keys are refused before execution with UnknownParameter. Do not place this option inside data.');
        Envelope.Add('strict', StrictOption);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>
    /// Returns false because the completion has no target record contract.
    /// </summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Describes the prompt, optional system text, language model code and file inputs.
    /// </summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        FileParameter: JsonObject;
        AttachmentParameter: JsonObject;
    begin
        Parameters.Add(ContractMgt.Parameter('prompt', 'string', true, 'The user prompt sent to the language model. A value that is not a JSON string is refused with InvalidParameterFormat; an empty one with MissingParameter.'));
        Parameters.Add(ContractMgt.Parameter('system', 'string', false, 'Optional system prompt sent as-is; no Bootstrap or skill is injected. Left out of the provider request when empty.'));
        Parameters.Add(ContractMgt.Parameter('roleCode', 'string', false, 'Optional code of a Bifrost Language Model (at most 20 characters). When omitted, the caller''s own language model is used, and then the default model.'));
        FileParameter := ContractMgt.Parameter('file', 'object', false, 'Optional inline file sent with the prompt; takes precedence over attachment. A value that is not a JSON object is ignored, and attachment is then ignored too.');
        FileParameter.Add('children', FileChildren());
        Parameters.Add(FileParameter);
        AttachmentParameter := ContractMgt.Parameter('attachment', 'object', false, 'Optional reference to a stored attachment whose content is sent with the prompt. Ignored when file is supplied, when table is not one of the allowed names, or when systemId is not a GUID that finds an attachment with content.');
        AttachmentParameter.Add('children', AttachmentChildren());
        Parameters.Add(AttachmentParameter);
        exit(true);
    end;

    /// <summary>
    /// Describes the successful reply and text fields returned by the provider.
    /// </summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the provider response was returned.'));
        Fields.Add(ContractMgt.ResponseField('reply', 'string', 'The provider response text, when supplied by the provider.'));
        Fields.Add(ContractMgt.ResponseField('text', 'string', 'A copy of reply, added when the provider did not return text.'));
        Fields.Add(ContractMgt.ResponseField('type', 'string', 'The value reply. Returned by the Anthropic provider only.'));
        Fields.Add(ContractMgt.ResponseField('usage', 'object', 'The token usage the provider reported for the call. Returned by the Anthropic provider only, and only when the provider reports usage.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>
    /// Describes coded failures and next steps using the same labels as execution.
    /// </summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        // The rows share their labels with the live answers; Msg Contract Mgt ori builds the chapters in English.
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PromptDeniedErr, PromptDeniedWhenTxt, PromptDeniedNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingPromptErr, MissingPromptWhenTxt, MissingPromptNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RoleNotFoundErr, RoleNotFoundWhenTxt, RoleNotFoundNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NoProviderErr, NoProviderWhenTxt, NoProviderNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidPromptErr, InvalidPromptWhenTxt, MissingPromptNextStepTxt));
        ProviderBase.AddPromptErrors(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own error text',
            'An error the type does not catch is raised before the provider is called, for example a message version other than 1.0.',
            'Read the text and correct the request. Nothing was sent to the provider and nothing was changed.'));
        exit(true);
    end;

    /// <summary>
    /// Describes the completion effect and its external provider call.
    /// </summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The caller holds Foundation''s BIFROST Chat ori permission set, and this app''s BIFROST LLM Chat ori when the language model''s provider is not Copilot.');
        Preconditions.Add('The caller can read the Bifrost Language Models table.');
        Preconditions.Add('A language model with a usable chat provider is set up: the one in roleCode, otherwise the caller''s own or the default language model, with its API key where the provider needs one.');
        Preconditions.Add('Outbound HttpClient requests are allowed for the app; otherwise the call is refused with PreconditionFailed.');
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Sends the prompt, the system prompt and any file to the selected external language model provider and returns its answer; the data sent cannot be recalled and the answer can differ between calls. No Business Central business data is changed. The only write is the Last Used On stamp of the language model''s API key, at most once a day, after the provider has answered. The type itself does not commit.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Chat ori; BIFROST LLM Chat ori for non-Copilot providers');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>
    /// Returns false because this implementation supplies no metering chapter.
    /// </summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Lists related message types for discovery and follow-up work.
    /// </summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Read Business Central data first, then use the returned values in the prompt.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Set', 'Use the completion as input for structured record updates only after validating the generated values.'));
        exit(true);
    end;

    /// <summary>
    /// Returns false because the related chapter already names the read and write siblings.
    /// </summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Adds example completion requests and responses to the contract.
    /// </summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Complete a prompt with the caller''s own or the default model',
            '{"type":"LLM.Prompt.Complete","data":{"prompt":"Classify the subject \"Invoice 4711 for March\" as invoice, order or other.","system":"Answer with one word."}}',
            '{"status":"Success","reply":"invoice","text":"invoice"}'));
        Examples.Add(ContractMgt.Example('Complete a prompt with a selected model',
            '{"type":"LLM.Prompt.Complete","data":{"prompt":"Summarize this text.","system":"Return one concise sentence.","roleCode":"CLAUDE"}}',
            '{"status":"Success","reply":"A concise summary.","text":"A concise summary."}'));
        Examples.Add(ContractMgt.Example('Send an inline file with the prompt',
            '{"type":"LLM.Prompt.Complete","data":{"prompt":"Extract the invoice number and total.","file":{"data":"JVBERi0xLjQK","mimeType":"application/pdf","fileName":"invoice.pdf"}}}',
            '{"status":"Success","reply":"Invoice 4711, total 1240 EUR.","text":"Invoice 4711, total 1240 EUR."}'));
        Examples.Add(ContractMgt.Example('Send a stored incoming document attachment with the prompt',
            '{"type":"LLM.Prompt.Complete","data":{"prompt":"Who is the vendor on this document?","attachment":{"table":"Incoming Document Attachment","systemId":"<systemId>"}}}',
            '{"status":"Success","reply":"Contoso Ltd.","text":"Contoso Ltd."}'));
        exit(true);
    end;

    /// <summary>
    /// Describes the one-shot completion operation and its scope.
    /// </summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Use LLM.Prompt.Complete for one-shot reasoning, transformation, extraction, classification or generation when no dedicated message type covers the task. It sends one user prompt and optional system prompt, and optionally one file, to a configured provider without tools, record context or conversation state, and returns the answer as text. It reads and writes no Business Central records for you: read the data first and put the values in the prompt.';
        exit(true);
    end;

    /// <summary>
    /// Describes completion constraints and provider-specific behavior.
    /// </summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'If roleCode is omitted, the caller''s configured language model is used and then the default model is tried. An inline file takes precedence over a stored attachment. Images (a mimeType that starts with image/) are sent to the provider as images, other types as documents. The Copilot provider does not accept files: a call with a file answers with the provider failure (PreconditionFailed). Other providers may reject files they cannot read. Provider response properties other than status, reply and text are passed through; the Anthropic provider adds type and usage. The prompt and any file leave Business Central for the provider the language model names, so send no data that provider may not receive. The reply is free text from an external model: validate it before it is used to change anything.';
        exit(true);
    end;

    local procedure FileChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.Parameter('data', 'string', false, 'The file content, Base64-encoded. Send it together with mimeType.'));
        Children.Add(ContractMgt.Parameter('mimeType', 'string', false, 'The MIME type, for example application/pdf or image/png. image/* is sent as an image, anything else as a document.'));
        Children.Add(ContractMgt.Parameter('fileName', 'string', false, 'The file name. Used by the providers that take a file name; the others ignore it.'));
    end;

    local procedure AttachmentChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TableParameter: JsonObject;
        Allowed: JsonArray;
    begin
        Allowed.Add('Incoming Document Attachment');
        Allowed.Add('Document Attachment');
        TableParameter := ContractMgt.Parameter('table', 'string', true, 'The table that holds the attachment.');
        TableParameter.Add('allowed', Allowed);
        Children.Add(TableParameter);
        Children.Add(ContractMgt.Parameter('systemId', 'string', true, 'The SystemId (GUID) of the attachment record.'));
    end;

    /// <summary>
    /// Returns Outbound for the completion message type.
    /// </summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>
    /// Validates permissions and completion inputs, resolves the language model and returns the provider completion or a coded error.
    /// </summary>
    [NonDebuggable]
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TempChatArg: Record "Bifrost Chat Argument ori" temporary;
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ChatProvider: Codeunit "LangModel Chat Provider ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        PromptToken: JsonToken;
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
        if RequestJson.Get('prompt', PromptToken) then
            if not IsJsonString(PromptToken) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidPromptErr, 'prompt', '', PromptExpectedTxt, MissingPromptNextStepTxt);
                exit;
            end;
        UserPrompt := GetTextValue(RequestJson, 'prompt');
        if UserPrompt = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingPromptErr, 'prompt', '', PromptExpectedTxt, MissingPromptNextStepTxt);
            exit;
        end;

        if not BifrostLanguageModel.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PromptDeniedErr, '', '', PromptDeniedExpectedTxt, PromptDeniedNextStepTxt);
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
        if not TryCompletePrompt(Provider, TempChatArg) then begin
            ClearLastError();
            ProviderBase.RespondPromptError(Argument, ResponseJson);
            exit;
        end;
        ResponseText := TempChatArg.GetResultText();
        LangModelSecrets.MarkApiKeyUsed(BifrostLanguageModel.Code);

        if not ResponseJson.ReadFrom(ResponseText) then begin
            ProviderBase.RespondPromptError(Argument, ResponseJson);
            exit;
        end;

        if HasProperty(ResponseJson, 'error') then begin
            ProviderBase.RespondPromptError(Argument, ResponseJson);
            exit;
        end;

        ResponseJson.Add('status', 'Success');
        if not HasProperty(ResponseJson, 'text') then
            if HasProperty(ResponseJson, 'reply') then
                ResponseJson.Add('text', GetTextValue(ResponseJson, 'reply'));

        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TryCompletePrompt(Provider: Interface "Bifrost LangModel Provider ori"; var TempChatArg: Record "Bifrost Chat Argument ori" temporary)
    begin
        Provider.Execute(TempChatArg);
    end;

    local procedure IsJsonString(Token: JsonToken): Boolean
    var
        JsonText: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(JsonText);
        exit(JsonText.StartsWith('"'));
    end;

    local procedure GetTextValue(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if IsJsonString(Token) then
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
