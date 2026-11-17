namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue 142: Google defaults and provider changes use the selected provider's endpoint.
/// </summary>
codeunit 96080 "LangModel 142 Defaults Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>New Google cards use the available Flash alias.</summary>
    [Test]
    procedure Scenario_AC01_NewGoogleCard_UsesFlashLatest()
    var
        Model: Record "Bifrost Language Model ori";
        Card: TestPage "Bifrost LangModel Card ori";
    begin
        // Story #142, AC01 | Time: no date dependency | Risk: None.
        // [GIVEN] A new model without provider settings.
        InitializeModel(Model);
        Card.OpenEdit();
        Card.GoToRecord(Model);

        // [WHEN] Google is selected through the card.
        Card."Chat Provider".SetValue('Google (Gemini)');

        // [THEN] The new card has the supported model alias and Google endpoint.
        Card.Model.AssertEquals('gemini-flash-latest');
        Card."Base URL".AssertEquals('https://generativelanguage.googleapis.com/v1beta');
        Card.Close();
        Model.Get(Model.Code);
        Assert.AreEqual('gemini-flash-latest', Model.Model, 'Persist the Google default.');
    end;

    /// <summary>The provider runtime default also uses the alias when no model is stored.</summary>
    [Test]
    procedure Scenario_AC01_EmptyModel_ProviderReturnsFlashLatest()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        // Story #142, AC01 | Time: no date dependency | Risk: None.
        // [GIVEN] The Google provider with no configured model.
        Provider := Enum::"Bifrost LangModel Prov. ori"::Google;
        TempArgument.Init();
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::GetDefaultModel;

        // [WHEN] The provider default is requested.
        Provider.Execute(TempArgument);

        // [THEN] Runtime and card default agree.
        Assert.AreEqual('gemini-flash-latest', TempArgument.GetResultText(), 'Google runtime default.');
    end;

    /// <summary>The reproduced Anthropic to OpenAI switch replaces the inherited URL on the card.</summary>
    [Test]
    procedure Scenario_AC02_AnthropicCardToOpenAI_ReplacesDefaultUrl()
    var
        Model: Record "Bifrost Language Model ori";
        Card: TestPage "Bifrost LangModel Card ori";
    begin
        // Story #142, AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] An Anthropic model with its provider's default URL.
        InitializeModel(Model);
        Model.Validate("Chat Provider", Model."Chat Provider"::Anthropic);
        Model.Modify(true);
        Card.OpenEdit();
        Card.GoToRecord(Model);

        // [WHEN] OpenAI is selected.
        Card."Chat Provider".SetValue('OpenAI');

        // [THEN] The card and persisted record use OpenAI's endpoint.
        Card."Base URL".AssertEquals('https://api.openai.com/');
        Card.Close();
        Model.Get(Model.Code);
        Assert.AreEqual('https://api.openai.com/', Model."Base URL", 'Replace the old provider endpoint.');
    end;

    /// <summary>All pairs of providers with defaults replace inherited endpoints through table validation.</summary>
    [Test]
    procedure Scenario_AC02_DefaultProviderPairs_UseNewEndpoint()
    var
        Model: Record "Bifrost Language Model ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
        Providers: List of [Enum "Bifrost LangModel Prov. ori"];
        OldProvider: Enum "Bifrost LangModel Prov. ori";
        NewProvider: Enum "Bifrost LangModel Prov. ori";
    begin
        // Story #142, AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] Each built-in provider with a default endpoint.
        InitializeModel(Model);
        Providers.Add(Model."Chat Provider"::OpenAI);
        Providers.Add(Model."Chat Provider"::Anthropic);
        Providers.Add(Model."Chat Provider"::Google);
        Providers.Add(Model."Chat Provider"::xAI);
        foreach OldProvider in Providers do
            foreach NewProvider in Providers do
                if OldProvider <> NewProvider then begin
                    Model.Validate("Chat Provider", Model."Chat Provider"::None);
                    Model.Modify(true);
                    Model.Get(Model.Code);
                    Model.Validate("Chat Provider", OldProvider);
                    Model.Modify(true);
                    Model.Get(Model.Code);

                    // [WHEN] The provider changes through the table (the Test.LanguageModel.Set path).
                    Model.Validate("Chat Provider", NewProvider);

                    // [THEN] Its URL is the new provider default.
                    Provider := NewProvider;
                    TempArgument.Init();
                    TempArgument."Procedure Type" := TempArgument."Procedure Type"::GetDefaultBaseUrl;
                    Provider.Execute(TempArgument);
                    if NewProvider = NewProvider::OpenAI then
                        TempArgument.SetResultText('https://api.openai.com/');
                    Assert.AreEqual(TempArgument.GetResultText(), Model."Base URL", 'Provider change must replace an inherited URL.');
                end;
    end;

    /// <summary>Trailing slash variants of inherited URLs are replaced too.</summary>
    [Test]
    procedure Scenario_AC02_TrailingSlash_ReplacesInheritedUrl()
    var
        Model: Record "Bifrost Language Model ori";
    begin
        // Story #142, AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] An Anthropic endpoint saved with a trailing slash.
        InitializeModel(Model);
        Model.Validate("Chat Provider", Model."Chat Provider"::Anthropic);
        Model."Base URL" += '/';
        Model.Modify(true);
        Model.Get(Model.Code);

        // [WHEN] Google is selected.
        Model.Validate("Chat Provider", Model."Chat Provider"::Google);

        // [THEN] The equivalent old default is replaced.
        Assert.AreEqual('https://generativelanguage.googleapis.com/v1beta', Model."Base URL", 'Normalize trailing slashes for default comparison.');
    end;

    /// <summary>A custom URL, paths, explicit model and limits survive a provider change (#60 compatibility).</summary>
    [Test]
    procedure Scenario_AC02_CustomUrl_PreservesConfiguration()
    var
        Model: Record "Bifrost Language Model ori";
    begin
        // Story #142, AC02 | Time: no date dependency | Risk: #60 preservation contract.
        // [GIVEN] An explicitly configured Anthropic proxy.
        InitializeModel(Model);
        Model.Validate("Chat Provider", Model."Chat Provider"::Anthropic);
        Model."Base URL" := 'https://proxy.example.test/custom';
        Model.Model := 'explicit-model';
        Model."Chat Path" := '/custom/chat';
        Model."Models Path" := '/custom/models';
        Model."Max Tokens" := 1234;
        Model.Modify(true);
        Model.Get(Model.Code);

        // [WHEN] OpenAI is selected.
        Model.Validate("Chat Provider", Model."Chat Provider"::OpenAI);

        // [THEN] Values that were not inherited defaults remain configured.
        Assert.AreEqual('https://proxy.example.test/custom', Model."Base URL", 'Preserve explicit URL.');
        Assert.AreEqual('explicit-model', Model.Model, 'Preserve explicit model.');
        Assert.AreEqual('/custom/chat', Model."Chat Path", 'Preserve chat path.');
        Assert.AreEqual('/custom/models', Model."Models Path", 'Preserve models path.');
        Assert.AreEqual(1234, Model."Max Tokens", 'Preserve token limit.');
    end;

    /// <summary>Reselecting the same provider is idempotent.</summary>
    [Test]
    procedure Scenario_AC02_SameProvider_KeepsExistingUrl()
    var
        Model: Record "Bifrost Language Model ori";
    begin
        // Story #142, AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] A Google model with a configured model and default URL.
        InitializeModel(Model);
        Model.Validate("Chat Provider", Model."Chat Provider"::Google);
        Model.Model := 'explicit-model';
        Model.Modify(true);
        Model.Get(Model.Code);

        // [WHEN] Google is selected again.
        Model.Validate("Chat Provider", Model."Chat Provider"::Google);

        // [THEN] Existing values are retained.
        Assert.AreEqual('https://generativelanguage.googleapis.com/v1beta', Model."Base URL", 'Keep same-provider URL.');
        Assert.AreEqual('explicit-model', Model.Model, 'Keep explicit model.');
    end;

    /// <summary>A provider with no standard URL must not inherit another provider's endpoint.</summary>
    [Test]
    procedure Scenario_AC02_CustomProvider_ClearsInheritedEndpoint()
    var
        Model: Record "Bifrost Language Model ori";
    begin
        // Story #142, AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] An Anthropic model with its default endpoint.
        InitializeModel(Model);
        Model.Validate("Chat Provider", Model."Chat Provider"::Anthropic);
        Model.Modify(true);
        Model.Get(Model.Code);

        // [WHEN] A custom provider is selected without an endpoint.
        Model.Validate("Chat Provider", Model."Chat Provider"::"Custom LLM");

        // [THEN] Missing configuration stays empty instead of targeting Anthropic.
        Assert.AreEqual('', Model."Base URL", 'Require an explicit custom endpoint.');
    end;

    local procedure InitializeModel(var Model: Record "Bifrost Language Model ori")
    begin
        Model.Init();
        Model.Code := CopyStr('BIFT-142-' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Model.Code));
        Model.Insert(true);
    end;
}
