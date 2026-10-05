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
codeunit 96024 "Test LangModel Set Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Tools: Codeunit "LangModel Test Tools";
        MissingModelsErr: Label 'Send "models" (an array of language models) or one language model with "code".', Locked = true;
        MissingCodeErr: Label 'A language model has no "code".', Locked = true;
        CodeTooLongErr: Label 'The code "%1" is longer than 20 characters.', Comment = '%1 = code', Locked = true;
        UnknownProviderErr: Label 'The chat provider "%1" is unknown.', Comment = '%1 = provider name', Locked = true;
        ProviderExpectedTxt: Label 'Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI or Google', Locked = true;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Bifrost Language Model ori");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('TEST ONLY: creates or updates language models and stores their shared or personal API keys, so the chat of every provider can be tested without the setup pages.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

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
