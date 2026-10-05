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
