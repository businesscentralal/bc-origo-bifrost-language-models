namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.Environment;

/// <summary>
/// Shared helpers of the Language Models test message types: the production guard, JSON readers and the language
/// model summary they answer with. API key values are never read back or answered.
/// </summary>
codeunit 96027 "LangModel Test Tools"
{
    Access = Internal;

    var
        ProductionErr: Label 'Test message types do not run in a SaaS production environment.', Locked = true;
        ProductionNextStepTxt: Label 'Use a sandbox or a development container.', Locked = true;

    /// <summary>
    /// Envelope chapter for the test-only language model message types: no subject, JSON 1.0, optional root strict.
    /// </summary>
    procedure TestEnvelope(var Envelope: JsonObject): Boolean
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
    /// Write effect chapter so Foundation 28.0.10+ can complete strict validation of these test types.
    /// </summary>
    procedure WriteEffect(Changes: Text; var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', Changes);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', '');
        exit(true);
    end;

    /// <summary>
    /// Declares the language-model fields used both at the root of Test.LanguageModel.Set and inside models[].
    /// </summary>
    procedure AddModelFieldParameters(var Parameters: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('code', 'string', false, 'Language model code, at most 20 characters. Upper-cased when stored.'));
        Parameters.Add(ContractMgt.Parameter('chatProvider', 'string', false, 'Chat provider name: Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Google, Mock, or Gemini for Google.'));
        Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'Optional description stored on the language model.'));
        Parameters.Add(ContractMgt.Parameter('baseUrl', 'string', false, 'Optional provider base URL.'));
        Parameters.Add(ContractMgt.Parameter('model', 'string', false, 'Optional provider model name.'));
        Parameters.Add(ContractMgt.Parameter('chatPath', 'string', false, 'Optional chat path.'));
        Parameters.Add(ContractMgt.Parameter('modelsPath', 'string', false, 'Optional models path.'));
        Parameters.Add(ContractMgt.Parameter('timeoutSeconds', 'integer', false, 'Optional HTTP timeout in seconds.'));
        Parameters.Add(ContractMgt.Parameter('maxTokens', 'integer', false, 'Optional max tokens.'));
        Parameters.Add(ContractMgt.Parameter('contextTokens', 'integer', false, 'Optional context window size.'));
        Parameters.Add(ContractMgt.Parameter('default', 'boolean', false, 'When true, this model becomes the default and other defaults are cleared.'));
        Parameters.Add(ContractMgt.Parameter('skill', 'string', false, 'Optional skill text stored on the language model.'));
        Parameters.Add(ContractMgt.Parameter('sharedApiKey', 'string', false, 'Optional shared API key. Stored, never answered.'));
        Parameters.Add(ContractMgt.Parameter('personalApiKey', 'string', false, 'Optional personal API key. Stored, never answered.'));
    end;

    /// <summary>
    /// Answers PermissionDenied and returns false in a SaaS production environment; true everywhere else.
    /// </summary>
    procedure AssertNotProduction(var Argument: Record "Message Argument ori"): Boolean
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        if EnvironmentInformation.IsSaaS() and not EnvironmentInformation.IsSandbox() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, ProductionErr, '', '', 'a sandbox or an on-premises environment', ProductionNextStepTxt);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// The text of a JSON property, or '' when it is missing or null.
    /// </summary>
    procedure GetText(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Source.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    /// <summary>
    /// True when the property is present with a non-null value.
    /// </summary>
    procedure Has(Source: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Source.Get(PropertyName, Token) then
            exit(false);
        if Token.IsValue() then
            exit(not Token.AsValue().IsNull());
        exit(true);
    end;

    /// <summary>
    /// The language model as the test types answer it: its settings, the effective context size and whether each
    /// key is stored. The key values themselves are never answered.
    /// </summary>
    procedure ModelSummary(var LanguageModel: Record "Bifrost Language Model ori") Summary: JsonObject
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        Summary.Add('code', LanguageModel.Code);
        Summary.Add('description', LanguageModel.Description);
        Summary.Add('chatProvider', Enum::"Bifrost LangModel Prov. ori".Names().Get(Enum::"Bifrost LangModel Prov. ori".Ordinals().IndexOf(LanguageModel."Chat Provider".AsInteger())));
        Summary.Add('baseUrl', LanguageModel."Base URL");
        Summary.Add('model', LanguageModel.Model);
        Summary.Add('chatPath', LanguageModel."Chat Path");
        Summary.Add('modelsPath', LanguageModel."Models Path");
        Summary.Add('timeoutSeconds', LanguageModel."Timeout Seconds");
        Summary.Add('maxTokens', LanguageModel."Max Tokens");
        Summary.Add('contextTokens', LanguageModel."Context Tokens");
        Summary.Add('effectiveContextTokens', LanguageModel.GetContextTokens());
        Summary.Add('default', LanguageModel.Default);
        Summary.Add('sharedKeyStored', LangModelSecrets.HasServiceKey(LanguageModel.Code));
        Summary.Add('personalKeyStored', LangModelSecrets.HasUserKey(LanguageModel.Code));
    end;
}
