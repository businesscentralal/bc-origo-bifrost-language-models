namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.Apps;
using System.Environment.Configuration;
using System.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Language Models setup wizard regression tests for issue 80; isolated fixtures, no licence or consent writes.</summary>
codeunit 96037 "LangModel Setup Wizard Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        WizardMgt: Codeunit "LangModel Wizard Mgt ori";

    /// <summary>Registration runs through the real Assisted Setup page event path.</summary>
    [Test]
    procedure Scenario_AC01_AssistedSetup_RegistersWizard()
    var
        GuidedExperience: Codeunit "Guided Experience";
        AssistedSetup: TestPage "Assisted Setup";
    begin
        // Story #80, AC01 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] The setup registration event has not been called directly by the test.
        // [WHEN] The real Assisted Setup page opens.
        AssistedSetup.OpenView();
        AssistedSetup.Close();
        // [THEN] The Language Models wizard is registered.
        Assert.IsTrue(GuidedExperience.Exists(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"LangModel Setup Wizard ori"), 'The wizard must be registered through Assisted Setup.');
    end;

    /// <summary>The setup page keeps both wizard actions available.</summary>
    [Test]
    procedure Scenario_AC02_Setup_OffersBothWizards()
    var
        SetupPage: TestPage "LangModel Setup ori";
    begin
        // Story #80, AC02 | Time: independent of Today/WorkDate | Risk: None
        // [WHEN] The Language Models setup is opened.
        SetupPage.OpenView();
        // [THEN] Both the app-specific and Foundation wizard actions are available.
        Assert.IsTrue(SetupPage.SetupWizard.Enabled(), 'Language Models wizard action must be enabled.');
        Assert.IsTrue(SetupPage.BifrostSetupWizard.Enabled(), 'Foundation wizard remains reachable.');
        SetupPage.Close();
    end;

    /// <summary>HTTP changes are limited to the owning module.</summary>
    [Test]
    procedure Scenario_AC03_EnableHttp_LeavesAnotherAppUnchanged()
    var
        AppSetting: Record "NAV App Setting";
        Secrets: Codeunit "LangModel Secrets ori";
        OtherId: Guid;
    begin
        // Story #80, AC03 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] An unrelated app has explicitly disabled HTTP.
        OtherId := CreateGuid();
        AppSetting."App ID" := OtherId;
        AppSetting."Allow HttpClient Requests" := false;
        AppSetting.Insert();
        // [WHEN] This app is explicitly enabled.
        WizardMgt.EnableHttp();
        // [THEN] Only this app is enabled.
        Assert.IsTrue(WizardMgt.IsHttpEnabled(), 'Verification must read the enabled setting.');
        AppSetting.Get(Secrets.GetAppId());
        Assert.IsTrue(AppSetting."Allow HttpClient Requests", 'Language Models setting must be enabled.');
        AppSetting.Get(OtherId);
        Assert.IsFalse(AppSetting."Allow HttpClient Requests", 'Another app must remain unchanged.');
    end;

    /// <summary>Enabling an already enabled setting is idempotent.</summary>
    [Test]
    procedure Scenario_AC03_EnableHttpTwice_RemainsEnabled()
    begin
        // Story #80, AC03 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] HTTP is already enabled.
        WizardMgt.EnableHttp();
        // [WHEN] The command is repeated.
        WizardMgt.EnableHttp();
        // [THEN] Verification still succeeds.
        Assert.IsTrue(WizardMgt.IsHttpEnabled(), 'Repeated enable must be harmless.');
    end;

    /// <summary>Declining the existing Copilot confirmation leaves models unchanged.</summary>
    [Test]
    [HandlerFunctions('DeclineConfirmation')]
    procedure Scenario_AC04_CopilotDeclined_LeavesModelsUnchanged()
    var
        Model: Record "Bifrost Language Model ori";
        BeforeCount: Integer;
    begin
        // Story #80, AC04 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] Existing language models.
        BeforeCount := Model.Count();
        // [WHEN] The existing initializer confirmation is declined.
        Assert.IsFalse(WizardMgt.InitializeCopilot(), 'Declining must return false.');
        // [THEN] No model is created or removed.
        Assert.AreEqual(BeforeCount, Model.Count(), 'Declining must not initialize a model.');
    end;

    /// <summary>A free provider is claimed through Foundation.</summary>
    [Test]
    procedure Scenario_AC06_NoProvider_ClaimsLanguageModels()
    var
        Setup: Record "Setup ori";
    begin
        // Story #80, AC06 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] A setup with no chat provider.
        SetProvider(Enum::"Chat Provider Type ori"::None);
        // [WHEN] The wizard requests its claim.
        Assert.IsTrue(WizardMgt.ClaimChatProvider(), 'A free provider should be claimed.');
        // [THEN] The holder is Language Models.
        Setup.Get();
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, Setup."Chat Provider Type", 'The public claim must persist.');
    end;

    /// <summary>Another provider is never overridden, including repeated requests.</summary>
    [Test]
    procedure Scenario_AC06_OtherProvider_PreservesHolder()
    begin
        // Story #80, AC06 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] Another app holds the provider.
        SetProvider(Enum::"Chat Provider Type ori"::MockOtherProvider);
        // [WHEN] The wizard attempts a claim twice.
        Assert.IsFalse(WizardMgt.ClaimChatProvider(), 'Another holder must refuse the claim.');
        Assert.IsFalse(WizardMgt.ClaimChatProvider(), 'Retry must not override the holder.');
        // [THEN] Status still names that provider.
        Assert.AreEqual(Enum::"Chat Provider Type ori"::MockOtherProvider, WizardMgt.GetChatProvider(), 'The existing holder must remain.');
    end;

    /// <summary>The claim is idempotent when Language Models already owns chat.</summary>
    [Test]
    procedure Scenario_AC06_AlreadyClaimed_RemainsLanguageModels()
    begin
        // Story #80, AC06 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] Language Models holds the provider.
        SetProvider(Enum::"Chat Provider Type ori"::LanguageModels);
        // [WHEN] The wizard claims again.
        Assert.IsTrue(WizardMgt.ClaimChatProvider(), 'Our existing claim must be accepted.');
        // [THEN] The holder is unchanged.
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, WizardMgt.GetChatProvider(), 'Claim must be idempotent.');
    end;

    /// <summary>Exactly two company-scoped sets are assigned to each selected user, idempotently.</summary>
    [Test]
    procedure Scenario_AC07_TwoUsers_AssignsOnlyTheirTwoSets()
    var
        User1: Record User;
        User2: Record User;
        UnselectedUser: Record User;
        AccessControl: Record "Access Control";
    begin
        // Story #80, AC07 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] Three self-created enabled users without permissions.
        CreateEnabledUser(User1);
        CreateEnabledUser(User2);
        CreateEnabledUser(UnselectedUser);
        // [WHEN] Two selected users receive access twice.
        WizardMgt.GiveChatAccess(User1."User Security ID");
        WizardMgt.GiveChatAccess(User2."User Security ID");
        WizardMgt.GiveChatAccess(User1."User Security ID");
        WizardMgt.GiveChatAccess(User2."User Security ID");
        // [THEN] The selected users each have only the two sets in this company.
        AssertUserSets(User1."User Security ID");
        AssertUserSets(User2."User Security ID");
        AccessControl.SetRange("User Security ID", UnselectedUser."User Security ID");
        Assert.IsTrue(AccessControl.IsEmpty(), 'Unselected user must remain unchanged.');
    end;

    /// <summary>A disabled user cannot receive chat access.</summary>
    [Test]
    procedure Scenario_AC07_DisabledUser_RefusesWithoutAssignments()
    var
        SelectedUser: Record User;
        AccessControl: Record "Access Control";
    begin
        // Story #80, AC07 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] A self-created disabled user.
        CreateEnabledUser(SelectedUser);
        SelectedUser.State := SelectedUser.State::Disabled;
        SelectedUser.Modify();
        // [WHEN] Access is requested.
        asserterror WizardMgt.GiveChatAccess(SelectedUser."User Security ID");
        // [THEN] No access row was created.
        AccessControl.SetRange("User Security ID", SelectedUser."User Security ID");
        Assert.IsTrue(AccessControl.IsEmpty(), 'Disabled user must receive no permissions.');
    end;

    /// <summary>A valid user model creates missing company-scoped setup.</summary>
    [Test]
    procedure Scenario_AC08_ValidModel_CreatesMissingUserSetup()
    var
        SelectedUser: Record User;
        UserSetup: Record "User Setup ori";
        ModelCode: Code[20];
    begin
        // Story #80, AC08 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] An enabled user without Bifrost setup and an existing model.
        CreateEnabledUser(SelectedUser);
        ModelCode := CreateModel();
        // [WHEN] The model is assigned.
        WizardMgt.SetUserModel(SelectedUser."User Security ID", ModelCode);
        // [THEN] A setup row exists with that validated model.
        UserSetup.Get(SelectedUser."User Security ID");
        Assert.AreEqual(ModelCode, UserSetup."Bifrost Language Model Code", 'Missing user setup must be created.');
    end;

    /// <summary>Updating a model preserves other user setup fields.</summary>
    [Test]
    procedure Scenario_AC08_ExistingSetup_UpdatesModelOnly()
    var
        SelectedUser: Record User;
        UserSetup: Record "User Setup ori";
        ModelCode: Code[20];
    begin
        // Story #80, AC08 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] Existing user setup with a self-created model.
        CreateEnabledUser(SelectedUser);
        ModelCode := CreateModel();
        WizardMgt.SetUserModel(SelectedUser."User Security ID", ModelCode);
        // [WHEN] The assignment is repeated.
        WizardMgt.SetUserModel(SelectedUser."User Security ID", ModelCode);
        // [THEN] There is still exactly one row for this user.
        UserSetup.SetRange("User Security ID", SelectedUser."User Security ID");
        Assert.AreEqual(1, UserSetup.Count(), 'Assignment must be idempotent.');
        Assert.AreEqual(ModelCode, WizardMgt.GetUserModel(SelectedUser."User Security ID"), 'Model must be retained.');
    end;

    /// <summary>An unknown model fails before creating user setup.</summary>
    [Test]
    procedure Scenario_AC08_UnknownModel_RefusesWithoutSetup()
    var
        SelectedUser: Record User;
        UserSetup: Record "User Setup ori";
        UnknownCode: Code[20];
    begin
        // Story #80, AC08 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] A user without setup and a unique nonexistent model code.
        CreateEnabledUser(SelectedUser);
        UnknownCode := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(UnknownCode));
        // [WHEN] The unknown code is assigned.
        asserterror WizardMgt.SetUserModel(SelectedUser."User Security ID", UnknownCode);
        // [THEN] The error names that code and no setup is inserted.
        Assert.ExpectedError(UnknownCode);
        Assert.IsFalse(UserSetup.Get(SelectedUser."User Security ID"), 'Invalid code must not create setup.');
    end;

    /// <summary>Changing the default leaves exactly one default model.</summary>
    [Test]
    procedure Scenario_AC08_ChangeDefault_LeavesOneDefault()
    var
        Model: Record "Bifrost Language Model ori";
        NewCode: Code[20];
    begin
        // Story #80, AC08 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] A first configured default and a second model.
        WizardMgt.SetDefaultModel(CreateModel());
        NewCode := CreateModel();
        // [WHEN] The second model becomes default.
        WizardMgt.SetDefaultModel(NewCode);
        // [THEN] Exactly one model is default, with the new code.
        Model.SetRange(Default, true);
        Assert.AreEqual(1, Model.Count(), 'Exactly one model must be default.');
        Assert.AreEqual(NewCode, WizardMgt.GetDefaultModel(), 'New default must be selected.');
    end;

    /// <summary>A bad default does not clear the valid default.</summary>
    [Test]
    procedure Scenario_AC08_UnknownDefault_PreservesDefault()
    var
        OriginalCode: Code[20];
    begin
        // Story #80, AC08 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] A configured default.
        OriginalCode := CreateModel();
        WizardMgt.SetDefaultModel(OriginalCode);
        // [WHEN] A missing code is submitted.
        asserterror WizardMgt.SetDefaultModel('');
        // [THEN] The original default is retained.
        Assert.AreEqual(OriginalCode, WizardMgt.GetDefaultModel(), 'Invalid input must not clear the default.');
    end;

    /// <summary>Explicit Finish completes registered assisted setup.</summary>
    [Test]
    procedure Scenario_AC09_Finish_MarksSetupComplete()
    var
        GuidedExperience: Codeunit "Guided Experience";
        AssistedSetup: TestPage "Assisted Setup";
    begin
        // Story #80, AC09 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] The registered setup and a valid model configuration.
        AssistedSetup.OpenView();
        AssistedSetup.Close();
        GuidedExperience.ResetAssistedSetup(ObjectType::Page, Page::"LangModel Setup Wizard ori");
        WizardMgt.SetDefaultModel(CreateModel());
        // [WHEN] Finish is explicitly selected.
        WizardMgt.Finish();
        // [THEN] Assisted Setup reports completion.
        Assert.IsTrue(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"LangModel Setup Wizard ori"), 'Finish must mark assisted setup complete.');
    end;

    /// <summary>Opening and closing a wizard does not mark it complete.</summary>
    [Test]
    procedure Scenario_AC09_EarlyClose_DoesNotComplete()
    var
        GuidedExperience: Codeunit "Guided Experience";
        Wizard: TestPage "LangModel Setup Wizard ori";
    begin
        // Story #80, AC09 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] An incomplete setup.
        GuidedExperience.ResetAssistedSetup(ObjectType::Page, Page::"LangModel Setup Wizard ori");
        // [WHEN] The wizard is opened and closed at Welcome.
        Wizard.OpenView();
        Wizard.Close();
        // [THEN] It remains incomplete.
        Assert.IsFalse(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"LangModel Setup Wizard ori"), 'Early close must not complete setup.');
    end;

    /// <summary>An entirely skipped, unconfigured setup cannot be completed.</summary>
    [Test]
    procedure Scenario_AC09_NothingConfigured_RefusesCompletion()
    var
        Model: Record "Bifrost Language Model ori";
        AppSetting: Record "NAV App Setting";
        Secrets: Codeunit "LangModel Secrets ori";
        GuidedExperience: Codeunit "Guided Experience";
    begin
        // Story #80, AC09 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] All optional prerequisite steps are skipped and unconfigured.
        SetProvider(Enum::"Chat Provider Type ori"::None);
        Model.ModifyAll(Default, false);
        if AppSetting.Get(Secrets.GetAppId()) then begin
            AppSetting."Allow HttpClient Requests" := false;
            AppSetting.Modify();
        end;
        GuidedExperience.ResetAssistedSetup(ObjectType::Page, Page::"LangModel Setup Wizard ori");
        // [WHEN] Finish is attempted.
        asserterror WizardMgt.Finish();
        // [THEN] Completion remains false.
        Assert.IsFalse(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"LangModel Setup Wizard ori"), 'Skipped setup must remain incomplete.');
    end;

    /// <summary>Missing users cannot create company setup rows.</summary>
    [Test]
    procedure Scenario_AC08_MissingUser_RefusesWithoutSetup()
    var
        UserSetup: Record "User Setup ori";
        SecurityId: Guid;
        ModelCode: Code[20];
    begin
        // Story #80, AC08 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] An unknown user and an existing language model.
        SecurityId := CreateGuid();
        ModelCode := CreateModel();
        // [WHEN] The model is assigned.
        asserterror WizardMgt.SetUserModel(SecurityId, ModelCode);
        // [THEN] No orphan user setup is inserted.
        Assert.IsFalse(UserSetup.Get(SecurityId), 'Missing user must not get setup.');
    end;

    /// <summary>An ordinary user cannot gain extension-settings administration from this app.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC03_NonAdmin_HttpCommandRefused()
    var
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #80, AC03 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] A product user without extension-settings write permission.
        LowerPermissions.SetO365Basic();
        LowerPermissions.AddPermissionSet('BIFROST LLM ori');
        Assert.IsFalse(WizardMgt.CanEnableHttp(), 'Product set must not grant extension-settings write access.');
        // [WHEN] The command is invoked directly rather than through the hidden action.
        asserterror WizardMgt.EnableHttp();
        // [THEN] It fails with actionable localized guidance.
        Assert.ExpectedError('NAV App Setting');
        LowerPermissions.SetOutsideO365Scope();
    end;

    /// <summary>Product users cannot gain security administration through the wizard.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC07_NonAdmin_AssignmentCommandRefused()
    var
        SelectedUser: Record User;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #80, AC07 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] A user and a caller without security administration.
        CreateEnabledUser(SelectedUser);
        LowerPermissions.SetO365Basic();
        LowerPermissions.AddPermissionSet('BIFROST LLM ori');
        Assert.IsFalse(WizardMgt.CanAssignChatAccess(), 'Product set must not grant permission-assignment authority.');
        // [WHEN] The assignment is requested through the command directly.
        asserterror WizardMgt.GiveChatAccess(SelectedUser."User Security ID");
        // [THEN] Security administration is required.
        Assert.ExpectedError('SUPER');
        LowerPermissions.SetOutsideO365Scope();
    end;

    /// <summary>Handler declines the existing initializer confirmation.</summary>
    [ConfirmHandler]
    procedure DeclineConfirmation(Question: Text[1024]; var Reply: Boolean)
    begin
        Assert.AreNotEqual('', Question, 'The initializer must ask for confirmation.');
        Reply := false;
    end;

    local procedure SetProvider(Provider: Enum "Chat Provider Type ori")
    var
        Setup: Record "Setup ori";
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert();
        end;
        Setup."Chat Provider Type" := Provider;
        Setup.Modify();
    end;

    local procedure CreateModel(): Code[20]
    var
        Model: Record "Bifrost Language Model ori";
    begin
        Model.Code := CopyStr('BIFT-' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Model.Code));
        Model.Insert(true);
        exit(Model.Code);
    end;

    local procedure CreateEnabledUser(var NewUser: Record User)
    begin
        NewUser.Init();
        NewUser."User Security ID" := CreateGuid();
        NewUser."User Name" := CopyStr('BIFT-' + DelChr(Format(NewUser."User Security ID"), '=', '{}-'), 1, MaxStrLen(NewUser."User Name"));
        NewUser.State := NewUser.State::Enabled;
        NewUser.Insert();
    end;

    local procedure AssertUserSets(SecurityId: Guid)
    var
        AccessControl: Record "Access Control";
    begin
        AccessControl.SetRange("User Security ID", SecurityId);
        Assert.AreEqual(2, AccessControl.Count(), 'Exactly two permission assignments per selected user.');
        AccessControl.SetRange("Company Name", CompanyName());
        Assert.AreEqual(2, AccessControl.Count(), 'Both assignments must be company-scoped.');
        Assert.IsTrue(WizardMgt.HasChatSet(SecurityId, false), 'Foundation chat set must be effective.');
        Assert.IsTrue(WizardMgt.HasChatSet(SecurityId, true), 'Language Models chat set must be effective.');
    end;
}
