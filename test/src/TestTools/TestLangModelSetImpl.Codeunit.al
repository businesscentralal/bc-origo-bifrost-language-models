namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>
/// Test.LanguageModel.Set - creates or updates language models and stores their API keys, so a test session can set
/// up one model per provider without the setup pages. Request: { "models": [ { "code", "description", "chatProvider"
/// (Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Google), "baseUrl", "model", "chatPath", "modelsPath",
/// "timeoutSeconds", "maxTokens", "contextTokens", "default", "skill", "sharedApiKey", "personalApiKey" } ] }, or one
/// such object at the top level. A new chat provider fills the empty endpoint fields with its defaults before the
/// values sent are applied. A request that carries a key is redacted in the queue before anything else, and no key is
/// ever answered: the answer says only whether each key is stored. Test app only; refused in SaaS production.
/// </summary>
codeunit 96024 "Test LangModel Set Impl" implements "Msg Interface ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Tools: Codeunit "LangModel Test Tools";
        MissingModelsErr: Label 'Send "models" (an array of language models) or one language model with "code".', Locked = true;
        MissingCodeErr: Label 'A language model has no "code".', Locked = true;
        CodeTooLongErr: Label 'The code "%1" is longer than 20 characters.', Comment = '%1 = code', Locked = true;
        UnknownProviderErr: Label 'The chat provider "%1" is unknown.', Comment = '%1 = provider name', Locked = true;
        ProviderExpectedTxt: Label 'Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI or Google', Locked = true;

    /// <summary>
    /// Declares the JSON request envelope of this test-only type.
    /// </summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        Envelope.Add('dataRequired', true);
        exit(true);
    end;

    /// <summary>
    /// Returns false because models are selected by data parameters, not a subject.
    /// </summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Declares every supported request key and its actual shape.
    /// </summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ModelsParameter: JsonObject;
    begin
        Parameters := ModelParameters();
        ModelsParameter := ContractMgt.Parameter('models', 'array', false, 'Array of model objects, or omit it and supply one model at the top level. All entries are validated before writes.');
        ModelsParameter.Add('children', ModelParameters());
        Parameters.Add(ModelsParameter);
        exit(true);
    end;

    /// <summary>
    /// Describes successful output without exposing credentials.
    /// </summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when all models have been applied.'));
        Fields.Add(ContractMgt.ResponseField('models', 'array', 'Model summaries with stored-key flags, never key values.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>
    /// Describes the coded refusals of the test operation.
    /// </summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Test message types do not run in a SaaS production environment.', 'The environment is SaaS production.', 'Use a sandbox or development container.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'The request has no models or code.', 'Neither a models array nor a model code is supplied.', 'Supply models or one top-level model.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'The request has problems; see errors.', 'A model has no code, an overlong code, an invalid object or an unknown provider.', 'Correct every reported model before retrying.'));
        exit(true);
    end;

    /// <summary>
    /// States the actual writes, external effects and commit behavior.
    /// </summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates or updates model settings, registers secret definitions and stores supplied keys. Setting default clears other defaults. The stored request is redacted when it carries keys. No provider is called; no explicit commit.');
        Effect.Add('idempotent', true);
        exit(true);
    end;

    /// <summary>
    /// Uses Foundation metering without additional declarations.
    /// </summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Returns false because no related chapter is supplied.
    /// </summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Returns false because this test tool has no workflow chapter.
    /// </summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Returns false because usage examples are in the test tooling.
    /// </summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Describes this test-only operation.
    /// </summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>
    /// States the test-only environment and data boundaries.
    /// </summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Test app only. Refused in SaaS production. Runs with the caller permissions; never use customer fixtures or send real credentials through MCP.';
        exit(true);
    end;

    local procedure ModelParameters() Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('code', 'string', false, 'Language model code, up to 20 characters; required for each model.'));
        Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'Optional description.'));
        Parameters.Add(ContractMgt.Parameter('chatProvider', 'string', false, 'Provider enum name; Gemini is also accepted for Google. Test providers are allowed.'));
        Parameters.Add(ContractMgt.Parameter('baseUrl', 'string', false, 'Provider base URL.'));
        Parameters.Add(ContractMgt.Parameter('model', 'string', false, 'Provider model name.'));
        Parameters.Add(ContractMgt.Parameter('chatPath', 'string', false, 'Chat endpoint path.'));
        Parameters.Add(ContractMgt.Parameter('modelsPath', 'string', false, 'Models endpoint path.'));
        Parameters.Add(ContractMgt.Parameter('timeoutSeconds', 'integer', false, 'Request timeout in seconds.'));
        Parameters.Add(ContractMgt.Parameter('maxTokens', 'integer', false, 'Maximum response tokens.'));
        Parameters.Add(ContractMgt.Parameter('contextTokens', 'integer', false, 'Context budget; zero uses the provider default.'));
        Parameters.Add(ContractMgt.Parameter('default', 'boolean', false, 'Whether this is the default; true clears other defaults.'));
        Parameters.Add(ContractMgt.Parameter('skill', 'string', false, 'Model skill text.'));
        Parameters.Add(ContractMgt.Parameter('sharedApiKey', 'string', false, 'Optional shared key; stored without returning its value. Never send real credentials through MCP.'));
        Parameters.Add(ContractMgt.Parameter('personalApiKey', 'string', false, 'Optional personal key; stored without returning its value. Never send real credentials through MCP.'));
    end;

    /// <summary>
    /// Reports that this test-only message type is enabled.
    /// </summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>
    /// Returns the language model table number used by this test-only message type.
    /// </summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Bifrost Language Model ori");
    end;

    /// <summary>
    /// Describes the test-only language model set operation.
    /// </summary>
    procedure GetDescription(): Text[250]
    begin
        exit('TEST ONLY: creates or updates language models and stores their shared or personal API keys, so the chat of every provider can be tested without the setup pages.');
    end;

    /// <summary>
    /// Returns Inbound for this test-only message type.
    /// </summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>
    /// Creates or updates language models and stores supplied keys without returning them, after refusing production execution.
    /// </summary>
    [NonDebuggable]
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ModelsToken: JsonToken;
        ModelToken: JsonToken;
        Models: JsonArray;
        Results: JsonArray;
        ModelObject: JsonObject;
    begin
        if not Tools.AssertNotProduction(Argument) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('models', ModelsToken) and ModelsToken.IsArray() then
            Models := ModelsToken.AsArray()
        else
            if Tools.Has(RequestJson, 'code') then
                Models.Add(RequestJson)
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingModelsErr, 'models', '', 'an array of language models', 'Send {"models":[{"code":"BIFT-OPENAI","chatProvider":"OpenAI","sharedApiKey":"..."}]}.');
                exit;
            end;

        // Keys must not stay in Message ori."Request Data": redact before any key is stored.
        if RequestCarriesKey(Models) then
            Argument.RedactRequestData();

        if not CheckModels(Argument, Models) then
            exit;

        foreach ModelToken in Models do begin
            ModelObject := ModelToken.AsObject();
            Results.Add(ApplyModel(ModelObject));
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('models', Results);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RequestCarriesKey(Models: JsonArray): Boolean
    var
        ModelToken: JsonToken;
    begin
        foreach ModelToken in Models do
            if ModelToken.IsObject() then
                if Tools.Has(ModelToken.AsObject(), 'sharedApiKey') or Tools.Has(ModelToken.AsObject(), 'personalApiKey') then
                    exit(true);
        exit(false);
    end;

    local procedure CheckModels(var Argument: Record "Message Argument ori"; Models: JsonArray): Boolean
    var
        ModelToken: JsonToken;
        ModelObject: JsonObject;
        Provider: Enum "Bifrost LangModel Prov. ori";
        CodeText: Text;
        ParameterName: Text;
        Index: Integer;
    begin
        Index := 0;
        foreach ModelToken in Models do begin
            ParameterName := StrSubstNo('models[%1]', Index);
            if not ModelToken.IsObject() then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, MissingCodeErr, ParameterName, '', 'an object', '')
            else begin
                ModelObject := ModelToken.AsObject();
                CodeText := Tools.GetText(ModelObject, 'code');
                if CodeText = '' then
                    Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingCodeErr, ParameterName + '.code', '', 'a code of up to 20 characters', '');
                if StrLen(CodeText) > 20 then
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(CodeTooLongErr, CodeText), ParameterName + '.code', CodeText, 'a code of up to 20 characters', '');
                if Tools.Has(ModelObject, 'chatProvider') then
                    if not TryResolveProvider(Tools.GetText(ModelObject, 'chatProvider'), Provider) then
                        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnknownProviderErr, Tools.GetText(ModelObject, 'chatProvider')), ParameterName + '.chatProvider', Tools.GetText(ModelObject, 'chatProvider'), ProviderExpectedTxt, '');
            end;
            Index += 1;
        end;
        if not Argument.HasCollectedErrors() then
            exit(true);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, 'The request has problems; see errors.');
        exit(false);
    end;

    [NonDebuggable]
    local procedure ApplyModel(ModelObject: JsonObject): JsonObject
    var
        LanguageModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        Provider: Enum "Bifrost LangModel Prov. ori";
        ModelCode: Code[20];
        KeyValue: SecretText;
    begin
        ModelCode := CopyStr(UpperCase(Tools.GetText(ModelObject, 'code')), 1, MaxStrLen(ModelCode));
        if not LanguageModel.Get(ModelCode) then begin
            LanguageModel.Init();
            LanguageModel.Code := ModelCode;
            LanguageModel.Insert(true);
        end;

        if Tools.Has(ModelObject, 'chatProvider') then begin
            TryResolveProvider(Tools.GetText(ModelObject, 'chatProvider'), Provider);
            LanguageModel.Validate("Chat Provider", Provider);
        end;
        if Tools.Has(ModelObject, 'description') then
            LanguageModel.Description := CopyStr(Tools.GetText(ModelObject, 'description'), 1, MaxStrLen(LanguageModel.Description));
        if Tools.Has(ModelObject, 'baseUrl') then
            LanguageModel."Base URL" := CopyStr(Tools.GetText(ModelObject, 'baseUrl'), 1, MaxStrLen(LanguageModel."Base URL"));
        if Tools.Has(ModelObject, 'model') then
            LanguageModel.Model := CopyStr(Tools.GetText(ModelObject, 'model'), 1, MaxStrLen(LanguageModel.Model));
        if Tools.Has(ModelObject, 'chatPath') then
            LanguageModel."Chat Path" := CopyStr(Tools.GetText(ModelObject, 'chatPath'), 1, MaxStrLen(LanguageModel."Chat Path"));
        if Tools.Has(ModelObject, 'modelsPath') then
            LanguageModel."Models Path" := CopyStr(Tools.GetText(ModelObject, 'modelsPath'), 1, MaxStrLen(LanguageModel."Models Path"));
        if Tools.Has(ModelObject, 'timeoutSeconds') then
            LanguageModel.Validate("Timeout Seconds", ModelObject.GetInteger('timeoutSeconds'));
        if Tools.Has(ModelObject, 'maxTokens') then
            LanguageModel.Validate("Max Tokens", ModelObject.GetInteger('maxTokens'));
        if Tools.Has(ModelObject, 'contextTokens') then
            LanguageModel.Validate("Context Tokens", ModelObject.GetInteger('contextTokens'));
        if Tools.Has(ModelObject, 'skill') then
            LanguageModel.SetSkill(Tools.GetText(ModelObject, 'skill'));
        if Tools.Has(ModelObject, 'default') then
            SetDefault(LanguageModel, ModelObject.GetBoolean('default'));
        LanguageModel.Modify(true);

        if Tools.Has(ModelObject, 'sharedApiKey') then begin
            KeyValue := Tools.GetText(ModelObject, 'sharedApiKey');
            LangModelSecrets.SetServiceKey(LanguageModel.Code, KeyValue);
        end;
        if Tools.Has(ModelObject, 'personalApiKey') then begin
            KeyValue := Tools.GetText(ModelObject, 'personalApiKey');
            LangModelSecrets.SetUserKey(LanguageModel.Code, KeyValue);
        end;

        LanguageModel.Get(LanguageModel.Code);
        exit(Tools.ModelSummary(LanguageModel));
    end;

    local procedure SetDefault(var LanguageModel: Record "Bifrost Language Model ori"; NewDefault: Boolean)
    var
        OtherModel: Record "Bifrost Language Model ori";
    begin
        if NewDefault then begin
            OtherModel.SetRange(Default, true);
            OtherModel.SetFilter(Code, '<>%1', LanguageModel.Code);
            OtherModel.ModifyAll(Default, false);
        end;
        LanguageModel.Validate(Default, NewDefault);
    end;

    local procedure TryResolveProvider(ProviderName: Text; var Provider: Enum "Bifrost LangModel Prov. ori"): Boolean
    var
        Name: Text;
        Index: Integer;
    begin
        // The enum value name (Google, Custom LLM, ...), in any case; Gemini is accepted for Google.
        if LowerCase(ProviderName) = 'gemini' then
            ProviderName := 'Google';
        Index := 0;
        foreach Name in Enum::"Bifrost LangModel Prov. ori".Names() do begin
            Index += 1;
            if LowerCase(Name) = LowerCase(ProviderName) then begin
                Provider := Enum::"Bifrost LangModel Prov. ori".FromInteger(Enum::"Bifrost LangModel Prov. ori".Ordinals().Get(Index));
                exit(true);
            end;
        end;
        exit(false);
    end;
}
