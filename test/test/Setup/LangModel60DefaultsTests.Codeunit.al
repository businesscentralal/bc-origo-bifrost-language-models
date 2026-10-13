namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #60: OpenAI selection defaults an empty base URL without overwriting configured values.
/// </summary>
codeunit 96031 "LangModel 60 Defaults Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;

    /// <summary>
    /// Verifies emptyendpoints fillsdefaults through the model card.
    /// </summary>
    [Test]
    procedure Scenario_AC01_EmptyEndpoints_FillsDefaults()
    var
        LangModel: Record "Bifrost Language Model ori";
        ModelCard: TestPage "Bifrost LangModel Card ori";
    begin
        // [SCENARIO] #60 AC01 | Time: no date dependency | Risk: None.
        // [GIVEN] An individually created model with the specified endpoint configuration.
        InitializeModel(LangModel);
        LangModel.Modify();

        // [WHEN] The user selects OpenAI on the card.
        ModelCard.OpenEdit();
        ModelCard.GoToRecord(LangModel);
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);

        // [THEN] Only the empty base URL defaults; every existing value and empty path is preserved.
        ModelCard."Base URL".AssertEquals('https://api.openai.com/');
        ModelCard."Chat Path".AssertEquals('');
        ModelCard."Models Path".AssertEquals('');
        ModelCard.Close();
        LangModel.Get(LangModel.Code);
        AssertEndpoints(LangModel, 'https://api.openai.com/', '', '');
    end;

    /// <summary>
    /// Verifies proxyendpoints keepsexistingvalues through the model card.
    /// </summary>
    [Test]
    procedure Scenario_AC02_ProxyEndpoints_KeepsExistingValues()
    var
        LangModel: Record "Bifrost Language Model ori";
        ModelCard: TestPage "Bifrost LangModel Card ori";
    begin
        // [SCENARIO] #60 AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] An individually created model with the specified endpoint configuration.
        InitializeModel(LangModel);
        LangModel."Base URL" := 'https://proxy.example.test/api';
        LangModel."Chat Path" := '/proxy/chat';
        LangModel."Models Path" := '/proxy/models';
        LangModel.Modify();

        // [WHEN] The user selects OpenAI on the card.
        ModelCard.OpenEdit();
        ModelCard.GoToRecord(LangModel);
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);

        // [THEN] Only the empty base URL defaults; every existing value and empty path is preserved.
        ModelCard."Base URL".AssertEquals('https://proxy.example.test/api');
        ModelCard."Chat Path".AssertEquals('/proxy/chat');
        ModelCard."Models Path".AssertEquals('/proxy/models');
        ModelCard.Close();
        LangModel.Get(LangModel.Code);
        AssertEndpoints(LangModel, 'https://proxy.example.test/api', '/proxy/chat', '/proxy/models');
    end;

    /// <summary>
    /// Verifies azureendpoints keepsexistingvalues through the model card.
    /// </summary>
    [Test]
    procedure Scenario_AC02_AzureEndpoints_KeepsExistingValues()
    var
        LangModel: Record "Bifrost Language Model ori";
        ModelCard: TestPage "Bifrost LangModel Card ori";
    begin
        // [SCENARIO] #60 AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] An individually created model with the specified endpoint configuration.
        InitializeModel(LangModel);
        LangModel."Chat Provider" := LangModel."Chat Provider"::"Azure OpenAI";
        LangModel."Base URL" := 'https://example.openai.azure.com/openai/v1';
        LangModel."Chat Path" := '/chat/completions?api-version=2026-01-01';
        LangModel."Models Path" := '/models?api-version=2026-01-01';
        LangModel.Modify();

        // [WHEN] The user selects OpenAI on the card.
        ModelCard.OpenEdit();
        ModelCard.GoToRecord(LangModel);
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);

        // [THEN] Only the empty base URL defaults; every existing value and empty path is preserved.
        ModelCard."Base URL".AssertEquals('https://example.openai.azure.com/openai/v1');
        ModelCard."Chat Path".AssertEquals('/chat/completions?api-version=2026-01-01');
        ModelCard."Models Path".AssertEquals('/models?api-version=2026-01-01');
        ModelCard.Close();
        LangModel.Get(LangModel.Code);
        AssertEndpoints(LangModel, 'https://example.openai.azure.com/openai/v1', '/chat/completions?api-version=2026-01-01', '/models?api-version=2026-01-01');
    end;

    /// <summary>
    /// Verifies an existing base URL is preserved and empty paths remain empty.
    /// </summary>
    [Test]
    procedure Scenario_AC02_OnlyBaseUrl_LeavesPathsEmpty()
    var
        LangModel: Record "Bifrost Language Model ori";
        ModelCard: TestPage "Bifrost LangModel Card ori";
    begin
        // [SCENARIO] #60 AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] An individually created model with the specified endpoint configuration.
        InitializeModel(LangModel);
        LangModel."Base URL" := 'https://proxy.example.test/v1';
        LangModel.Modify();

        // [WHEN] The user selects OpenAI on the card.
        ModelCard.OpenEdit();
        ModelCard.GoToRecord(LangModel);
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);

        // [THEN] Only the empty base URL defaults; every existing value and empty path is preserved.
        ModelCard."Base URL".AssertEquals('https://proxy.example.test/v1');
        ModelCard."Chat Path".AssertEquals('');
        ModelCard."Models Path".AssertEquals('');
        ModelCard.Close();
        LangModel.Get(LangModel.Code);
        AssertEndpoints(LangModel, 'https://proxy.example.test/v1', '', '');
    end;

    /// <summary>
    /// Verifies an existing chat path is preserved while only the base URL defaults.
    /// </summary>
    [Test]
    procedure Scenario_AC02_OnlyChatPath_FillsBaseUrlOnly()
    var
        LangModel: Record "Bifrost Language Model ori";
        ModelCard: TestPage "Bifrost LangModel Card ori";
    begin
        // [SCENARIO] #60 AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] An individually created model with the specified endpoint configuration.
        InitializeModel(LangModel);
        LangModel."Chat Path" := '/custom/chat';
        LangModel.Modify();

        // [WHEN] The user selects OpenAI on the card.
        ModelCard.OpenEdit();
        ModelCard.GoToRecord(LangModel);
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);

        // [THEN] Only the empty base URL defaults; every existing value and empty path is preserved.
        ModelCard."Base URL".AssertEquals('https://api.openai.com/');
        ModelCard."Chat Path".AssertEquals('/custom/chat');
        ModelCard."Models Path".AssertEquals('');
        ModelCard.Close();
        LangModel.Get(LangModel.Code);
        AssertEndpoints(LangModel, 'https://api.openai.com/', '/custom/chat', '');
    end;

    /// <summary>
    /// Verifies an existing models path is preserved while only the base URL defaults.
    /// </summary>
    [Test]
    procedure Scenario_AC02_OnlyModelsPath_FillsBaseUrlOnly()
    var
        LangModel: Record "Bifrost Language Model ori";
        ModelCard: TestPage "Bifrost LangModel Card ori";
    begin
        // [SCENARIO] #60 AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] An individually created model with the specified endpoint configuration.
        InitializeModel(LangModel);
        LangModel."Models Path" := '/custom/models';
        LangModel.Modify();

        // [WHEN] The user selects OpenAI on the card.
        ModelCard.OpenEdit();
        ModelCard.GoToRecord(LangModel);
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);

        // [THEN] Only the empty base URL defaults; every existing value and empty path is preserved.
        ModelCard."Base URL".AssertEquals('https://api.openai.com/');
        ModelCard."Chat Path".AssertEquals('');
        ModelCard."Models Path".AssertEquals('/custom/models');
        ModelCard.Close();
        LangModel.Get(LangModel.Code);
        AssertEndpoints(LangModel, 'https://api.openai.com/', '', '/custom/models');
    end;

    /// <summary>
    /// Verifies that repeated OpenAI validation preserves subsequent user edits.
    /// </summary>
    [Test]
    procedure Scenario_AC02_RepeatedSelection_KeepsUserEdits()
    var
        LangModel: Record "Bifrost Language Model ori";
        ModelCard: TestPage "Bifrost LangModel Card ori";
    begin
        // [SCENARIO] #60 AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] The user has selected OpenAI and then configured a custom base URL and paths.
        InitializeModel(LangModel);
        ModelCard.OpenEdit();
        ModelCard.GoToRecord(LangModel);
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);
        ModelCard."Base URL".SetValue('https://proxy.example.test/v1');
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::"Azure OpenAI");
        ModelCard."Chat Path".SetValue('/edited/chat');
        ModelCard."Models Path".SetValue('/edited/models');
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);

        // [WHEN] OpenAI is selected again after editing paths while Azure OpenAI enables them.
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::OpenAI);

        // [THEN] The user edits remain persisted.
        ModelCard.Close();
        LangModel.Get(LangModel.Code);
        AssertEndpoints(LangModel, 'https://proxy.example.test/v1', '/edited/chat', '/edited/models');
    end;

    /// <summary>
    /// Verifies table validation also applies the defaults for non-page callers.
    /// </summary>
    [Test]
    procedure Scenario_AC01_TableValidation_FillsDefaults()
    var
        TempLangModel: Record "Bifrost Language Model ori" temporary;
    begin
        // [SCENARIO] #60 AC01 | Time: no date dependency | Risk: None.
        // [GIVEN] An empty temporary model; direct validation covers non-page callers after card coverage.
        TempLangModel.Init();

        // [WHEN] A caller validates the provider on the table.
        TempLangModel.Validate("Chat Provider", TempLangModel."Chat Provider"::OpenAI);

        // [THEN] The base URL defaults and both paths remain empty.
        AssertEndpoints(TempLangModel, 'https://api.openai.com/', '', '');
    end;

    /// <summary>
    /// Verifies Azure OpenAI selection does not receive public OpenAI endpoint defaults.
    /// </summary>
    [Test]
    procedure Scenario_AC02_AzureSelection_LeavesEndpointsEmpty()
    var
        LangModel: Record "Bifrost Language Model ori";
        ModelCard: TestPage "Bifrost LangModel Card ori";
    begin
        // [SCENARIO] #60 AC02 | Time: no date dependency | Risk: None.
        // [GIVEN] A new model with empty endpoint fields.
        InitializeModel(LangModel);
        ModelCard.OpenEdit();
        ModelCard.GoToRecord(LangModel);

        // [WHEN] Azure OpenAI is selected instead of OpenAI.
        ModelCard."Chat Provider".SetValue(LangModel."Chat Provider"::"Azure OpenAI");

        // [THEN] Azure endpoints remain for the user to configure.
        ModelCard.Close();
        LangModel.Get(LangModel.Code);
        AssertEndpoints(LangModel, '', '', '');
    end;

    local procedure InitializeModel(var LangModel: Record "Bifrost Language Model ori")
    begin
        LangModel.Init();
        LangModel.Code := CopyStr('BIFT-' + Format(Any.IntegerInRange(100000, 999999)), 1, MaxStrLen(LangModel.Code));
        LangModel.Insert(true);
    end;

    local procedure AssertEndpoints(LangModel: Record "Bifrost Language Model ori"; BaseUrl: Text; ChatPath: Text; ModelsPath: Text)
    begin
        Assert.AreEqual(BaseUrl, LangModel."Base URL", 'Base URL must default only when empty.');
        Assert.AreEqual(ChatPath, LangModel."Chat Path", 'Chat Path must default only when empty.');
        Assert.AreEqual(ModelsPath, LangModel."Models Path", 'Models Path must default only when empty.');
    end;
}
