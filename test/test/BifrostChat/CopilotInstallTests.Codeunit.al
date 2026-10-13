namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using Origo.Bifrost;
using System.AI;
using System.TestLibraries.Utilities;

/// <summary>
/// Install-time chat provider claim (#35). The claim goes through Foundation's
/// "Setup ori".TryClaimChatProvider, which carries its own inherent permissions: a caller without any
/// permission on "Setup ori" claims too (core#122), another provider that holds the value is never
/// overridden, and the claim is idempotent.
/// </summary>
codeunit 96018 "Copilot Install Tests"
{
    Subtype = Test;

    var
        TempSavedModels: Record "Bifrost Language Model ori" temporary;
        Assert: Codeunit "Library Assert";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        OriginalChatProviderType: Enum "Chat Provider Type ori";
        HadSetupRow: Boolean;
        ConfirmAnswer: Boolean;
        SuccessMessages: Integer;

    /// <summary>
    /// Verifies that install claims Language Models without direct setup permission.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ClaimChatProvider_WithoutSetupPermission_Claims()
    var
        BifrostSetup: Record "Setup ori";
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        // [GIVEN] "Chat Provider Type" is None
        Initialize(Enum::"Chat Provider Type ori"::None);

        // [GIVEN] a restricted caller who cannot read or write Foundation "Setup ori"
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM ori');
        Assert.IsFalse(BifrostSetup.ReadPermission(), 'O365 Basic plus BIFROST LLM ori must not grant Read on Setup ori.');
        Assert.IsFalse(BifrostSetup.WritePermission(), 'O365 Basic plus BIFROST LLM ori must not grant Write on Setup ori.');

        // [WHEN] the install claim runs
        CopilotInstall.ClaimChatProvider();

        // [THEN] it returns without error and Language Models holds the chat provider
        LibraryLowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, CurrentChatProviderType(), 'The restricted claim must set Chat Provider Type to LanguageModels.');
        RestoreSetup();
    end;

    /// <summary>
    /// Verifies that install preserves another provider claim.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ClaimChatProvider_WhenAnotherProviderHolds_LeavesItUnchanged()
    var
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        // [GIVEN] another app holds the chat provider
        Initialize(Enum::"Chat Provider Type ori"::MockOtherProvider);

        // [WHEN] a restricted caller runs the install claim
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM ori');
        CopilotInstall.ClaimChatProvider();

        // [THEN] it returns without error and the other provider keeps the claim
        LibraryLowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual(Enum::"Chat Provider Type ori"::MockOtherProvider, CurrentChatProviderType(), 'A claim held by another provider must not be overridden.');
        RestoreSetup();
    end;

    /// <summary>
    /// Verifies that install claims Language Models when no provider is selected.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ClaimChatProvider_WhenNone_ClaimsLanguageModels()
    var
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        // [GIVEN] a permitted caller and "Chat Provider Type" still None
        Initialize(Enum::"Chat Provider Type ori"::None);

        // [WHEN] the install claim runs
        CopilotInstall.ClaimChatProvider();

        // [THEN] Language Models owns the chat provider
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, CurrentChatProviderType(), 'The permitted claim must set Chat Provider Type to LanguageModels.');
        RestoreSetup();
    end;

    /// <summary>
    /// Verifies that claiming Language Models twice is idempotent.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ClaimChatProvider_Twice_IsIdempotent()
    var
        BifrostSetup: Record "Setup ori";
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        // [GIVEN] "Chat Provider Type" is None
        Initialize(Enum::"Chat Provider Type ori"::None);

        // [WHEN] the claim runs twice
        CopilotInstall.ClaimChatProvider();
        CopilotInstall.ClaimChatProvider();

        // [THEN] Language Models holds the chat provider and there is still one setup row
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, CurrentChatProviderType(), 'A second claim must keep LanguageModels.');
        Assert.AreEqual(1, BifrostSetup.Count(), 'The claim must not create a second setup row.');
        RestoreSetup();
    end;

    /// <summary>
    /// Verifies that install creates missing setup and claims Language Models.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ClaimChatProvider_MissingSetupRow_CreatesAndClaims()
    var
        BifrostSetup: Record "Setup ori";
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        // [GIVEN] no setup row
        Initialize(Enum::"Chat Provider Type ori"::None);
        BifrostSetup.DeleteAll();

        // [WHEN] a restricted caller runs the install claim
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM ori');
        CopilotInstall.ClaimChatProvider();

        // [THEN] the setup row is created and Language Models holds the chat provider
        LibraryLowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual(1, BifrostSetup.Count(), 'The claim must create the setup row.');
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, CurrentChatProviderType(), 'The claim must set Chat Provider Type to LanguageModels.');
        RestoreSetup();
    end;

    /// <summary>
    /// Verifies the initialization action: DeclinedAbsent LeavesModelsUnchanged.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    [HandlerFunctions('ConfirmInit')]
    procedure InitDefaults_DeclinedAbsent_LeavesModelsUnchanged()
    var
        LanguageModel: Record "Bifrost Language Model ori";
        ModelList: TestPage "Bifrost LangModel List ori";
    begin
        // PR57 bounded repair | Time: independent of WorkDate | Risk: local Copilot registration commits.
        // [GIVEN] An owned fixture; original model records are restored explicitly.
        PrepareInitFixture(false);

        // [WHEN] The actual page action runs with a handled confirmation.
        ModelList.OpenView();
        ModelList.InitCopilotDefaults.Invoke();
        ModelList.Close();
        // [THEN] Real records and success messages match the user's choice.
        Assert.IsFalse(LanguageModel.Get('COPILOT'), 'Decline must not create a model.');
        Assert.AreEqual(0, SuccessMessages, 'Success must be reported only after completion.');
        RestoreInitFixture();
    end;

    /// <summary>
    /// Verifies the initialization action: AcceptedAbsent CreatesDefault.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    [HandlerFunctions('ConfirmInit,InitSuccess')]
    procedure InitDefaults_AcceptedAbsent_CreatesDefault()
    var
        LanguageModel: Record "Bifrost Language Model ori";
        DefaultSkill: Codeunit "Copilot Default Skill ori";
        ModelList: TestPage "Bifrost LangModel List ori";
    begin
        // PR57 bounded repair | Time: independent of WorkDate | Risk: local Copilot registration commits.
        // [GIVEN] An owned fixture; original model records are restored explicitly.
        PrepareInitFixture(true);

        // [WHEN] The actual page action runs with a handled confirmation.
        ModelList.OpenView();
        ModelList.InitCopilotDefaults.Invoke();
        ModelList.Close();
        // [THEN] Real records and success messages match the user's choice.
        LanguageModel.Get('COPILOT');
        Assert.IsTrue(LanguageModel.Default, 'First model must become default.');
        Assert.AreEqual(Enum::"Bifrost LangModel Prov. ori"::Copilot, LanguageModel."Chat Provider", 'Wrong provider.');
        Assert.AreEqual(DefaultSkill.GetSkillText(), LanguageModel.GetSkill(), 'Default skill must be initialized.');
        Assert.AreEqual(1, SuccessMessages, 'Success must be reported only after completion.');
        RestoreInitFixture();
    end;

    /// <summary>
    /// Verifies the initialization action: AcceptedOtherDefault PreservesSelection.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    [HandlerFunctions('ConfirmInit,InitSuccess')]
    procedure InitDefaults_AcceptedOtherDefault_PreservesSelection()
    var
        LanguageModel: Record "Bifrost Language Model ori";
        ModelList: TestPage "Bifrost LangModel List ori";
    begin
        // PR57 bounded repair | Time: independent of WorkDate | Risk: local Copilot registration commits.
        // [GIVEN] An owned fixture; original model records are restored explicitly.
        PrepareInitFixture(true);
        LanguageModel.Init();
        LanguageModel.Code := 'XPR58-OTHER';
        LanguageModel.Default := true;
        LanguageModel.Insert(true);
        // [WHEN] The actual page action runs with a handled confirmation.
        ModelList.OpenView();
        ModelList.InitCopilotDefaults.Invoke();
        ModelList.Close();
        // [THEN] Real records and success messages match the user's choice.
        LanguageModel.Get('COPILOT');
        Assert.IsFalse(LanguageModel.Default, 'Existing default must not be displaced.');
        LanguageModel.Get('XPR58-OTHER');
        Assert.IsTrue(LanguageModel.Default, 'Other default must stay selected.');
        Assert.AreEqual(1, SuccessMessages, 'Success must be reported only after completion.');
        RestoreInitFixture();
    end;

    /// <summary>
    /// Verifies that declining initialization preserves the existing model and skill.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    [HandlerFunctions('ConfirmInit')]
    procedure InitDefaults_DeclinedExisting_PreservesModelAndSkill()
    var
        LanguageModel: Record "Bifrost Language Model ori";
        ModelList: TestPage "Bifrost LangModel List ori";
    begin
        // PR57 bounded repair | Time: independent of WorkDate | Risk: local Copilot registration commits.
        // [GIVEN] An owned fixture; original model records are restored explicitly.
        PrepareInitFixture(false);
        LanguageModel.Init();
        LanguageModel.Code := 'COPILOT';
        LanguageModel.Description := 'PR57 preserved description';
        LanguageModel.Model := 'preserved-model';
        LanguageModel.Default := true;
        LanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        LanguageModel.SetSkill('old skill');
        LanguageModel.Insert(true);
        // [WHEN] The actual page action runs with a handled confirmation.
        ModelList.OpenView();
        ModelList.InitCopilotDefaults.Invoke();
        ModelList.Close();
        // [THEN] Real records and success messages match the user's choice.
        LanguageModel.Get('COPILOT');
        Assert.IsTrue(LanguageModel.Default, 'Existing default must stay selected.');
        Assert.AreEqual('PR57 preserved description', LanguageModel.Description, 'Description must stay unchanged.');
        Assert.AreEqual('preserved-model', LanguageModel.Model, 'Model must stay unchanged.');
        Assert.AreEqual(Enum::"Bifrost LangModel Prov. ori"::Mock, LanguageModel."Chat Provider", 'Provider must stay unchanged.');
        Assert.AreEqual('old skill', LanguageModel.GetSkill(), 'Decline must preserve skill.');
        Assert.AreEqual(0, SuccessMessages, 'Success must be reported only after completion.');
        RestoreInitFixture();
    end;

    /// <summary>
    /// Verifies the initialization action: AcceptedExisting RefreshesOnlySkill.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    [HandlerFunctions('ConfirmInit,InitSuccess')]
    procedure InitDefaults_AcceptedExisting_RefreshesOnlySkill()
    var
        LanguageModel: Record "Bifrost Language Model ori";
        DefaultSkill: Codeunit "Copilot Default Skill ori";
        ModelList: TestPage "Bifrost LangModel List ori";
    begin
        // PR57 bounded repair | Time: independent of WorkDate | Risk: local Copilot registration commits.
        // [GIVEN] An owned fixture; original model records are restored explicitly.
        PrepareInitFixture(true);
        LanguageModel.Init();
        LanguageModel.Code := 'COPILOT';
        LanguageModel.Description := 'PR57 preserved description';
        LanguageModel.Model := 'preserved-model';
        LanguageModel.Default := true;
        LanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        LanguageModel.SetSkill('old skill');
        LanguageModel.Insert(true);
        // [WHEN] The actual page action runs with a handled confirmation.
        ModelList.OpenView();
        ModelList.InitCopilotDefaults.Invoke();
        ModelList.Close();
        // [THEN] Real records and success messages match the user's choice.
        LanguageModel.Get('COPILOT');
        Assert.IsTrue(LanguageModel.Default, 'Existing default must stay selected.');
        Assert.AreEqual('PR57 preserved description', LanguageModel.Description, 'Description must stay unchanged.');
        Assert.AreEqual('preserved-model', LanguageModel.Model, 'Model must stay unchanged.');
        Assert.AreEqual(Enum::"Bifrost LangModel Prov. ori"::Mock, LanguageModel."Chat Provider", 'Provider must stay unchanged.');
        Assert.AreEqual(DefaultSkill.GetSkillText(), LanguageModel.GetSkill(), 'Skill must be refreshed.');
        Assert.AreEqual(1, SuccessMessages, 'Success must be reported only after completion.');
        RestoreInitFixture();
    end;

    /// <summary>
    /// Verifies that model-write failure propagates through the page and never reports success.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    [HandlerFunctions('ConfirmInit')]
    procedure InitDefaults_ModelWriteFailure_PropagatesWithoutSuccess()
    var
        LanguageModel: Record "Bifrost Language Model ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ModelList: TestPage "Bifrost LangModel List ori";
    begin
        // PR57 bounded repair | Time: independent of WorkDate | Risk: registration commits before failure.
        // [GIVEN] The real model insert fails after actual local capability registration.
        PrepareInitFixture(true);
        MockProvider.SetRejectCopilotWrite(true);
        ModelList.OpenView();
        // [WHEN] The actual page action propagates the injected table-write error.
        asserterror ModelList.InitCopilotDefaults.Invoke();
        MockProvider.SetRejectCopilotWrite(false);
        Assert.ExpectedError('PR57 test rejected COPILOT model write.');
        // [THEN] No success message or partially created model remains.
        Assert.AreEqual(0, SuccessMessages, 'Failure must not report success.');
        Assert.IsFalse(LanguageModel.Get('COPILOT'), 'Failed insert must not leave a model.');
        ModelList.Close();
        RestoreInitFixture();
    end;

    /// <summary>
    /// Answers the original setup confirmation and verifies that its effects remain explicit.
    /// </summary>
    [ConfirmHandler]
    procedure ConfirmInit(Question: Text[1024]; var Reply: Boolean)
    begin
        Assert.IsTrue(StrPos(Question, 'Microsoft Billed') > 0, 'Confirmation must disclose Microsoft billing.');
        Assert.IsTrue(StrPos(Question, 'COPILOT') > 0, 'Confirmation must identify the affected model.');
        Reply := ConfirmAnswer;
    end;

    /// <summary>
    /// Verifies success only after the model and capability both exist.
    /// </summary>
    [MessageHandler]
    procedure InitSuccess(MessageText: Text[1024])
    var
        LanguageModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        Assert.AreEqual('Copilot defaults initialized successfully.', MessageText, 'Unexpected success text.');
        Assert.IsTrue(LanguageModel.Get('COPILOT'), 'Model must exist before reporting success.');
        Assert.IsTrue(CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori", LangModelSecrets.GetAppId()), 'Capability must be registered before success.');
        SuccessMessages += 1;
    end;

    local procedure PrepareInitFixture(Accept: Boolean)
    var
        LanguageModel: Record "Bifrost Language Model ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        LibraryLowerPermissions.SetOutsideO365Scope();
        MockProvider.Reset();
        ConfirmAnswer := Accept;
        SuccessMessages := 0;
        TempSavedModels.Reset();
        TempSavedModels.DeleteAll();
        LanguageModel.ReadIsolation := IsolationLevel::ReadCommitted;
        if LanguageModel.FindSet() then
            repeat
                LanguageModel.CalcFields(Skill);
                TempSavedModels := LanguageModel;
                TempSavedModels.Insert();
            until LanguageModel.Next() = 0;
        // Do not clear existing secret values when temporarily removing fixture models.
        LanguageModel.SetFilter(Code, 'COPILOT|XPR58-OTHER');
        LanguageModel.DeleteAll(false);
        LanguageModel.Reset();
        LanguageModel.SetRange(Default, true);
        LanguageModel.ModifyAll(Default, false);
    end;

    local procedure RestoreInitFixture()
    var
        LanguageModel: Record "Bifrost Language Model ori";
    begin
        LanguageModel.SetFilter(Code, 'COPILOT|XPR58-OTHER');
        LanguageModel.DeleteAll(false);
        TempSavedModels.Reset();
        if TempSavedModels.FindSet() then
            repeat
                LanguageModel := TempSavedModels;
                if LanguageModel.Get(TempSavedModels.Code) then begin
                    LanguageModel.TransferFields(TempSavedModels, false);
                    LanguageModel.Modify(false);
                end else begin
                    LanguageModel := TempSavedModels;
                    LanguageModel.Insert(false, true);
                end;
            until TempSavedModels.Next() = 0;
        TempSavedModels.DeleteAll();
    end;

    /// <summary>
    /// Remembers the current setup and sets "Chat Provider Type" to the given value, outside the lowered permissions.
    /// </summary>
    local procedure Initialize(ChatProviderType: Enum "Chat Provider Type ori")
    var
        BifrostSetup: Record "Setup ori";
    begin
        LibraryLowerPermissions.SetOutsideO365Scope();
        HadSetupRow := BifrostSetup.Get();
        if not HadSetupRow then begin
            BifrostSetup.Init();
            BifrostSetup.Insert(true);
        end;
        OriginalChatProviderType := BifrostSetup."Chat Provider Type";
        BifrostSetup."Chat Provider Type" := ChatProviderType;
        BifrostSetup.Modify();
    end;

    local procedure CurrentChatProviderType(): Enum "Chat Provider Type ori"
    var
        BifrostSetup: Record "Setup ori";
    begin
        BifrostSetup.Get();
        exit(BifrostSetup."Chat Provider Type");
    end;

    /// <summary>
    /// Puts the setup back as Initialize found it, so later tests see the same value.
    /// </summary>
    local procedure RestoreSetup()
    var
        BifrostSetup: Record "Setup ori";
    begin
        LibraryLowerPermissions.SetOutsideO365Scope();
        if not BifrostSetup.Get() then begin
            BifrostSetup.Init();
            BifrostSetup.Insert(true);
        end;
        BifrostSetup."Chat Provider Type" := OriginalChatProviderType;
        BifrostSetup.Modify();
        if not HadSetupRow then
            BifrostSetup.Delete();
    end;
}
