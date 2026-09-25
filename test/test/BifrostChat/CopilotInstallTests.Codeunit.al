namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Install-time chat provider claim and secret registration. Publishing Foundation re-runs
/// OnInstallAppPerCompany without TableData permission on "Setup ori" (core#122); the claim must
/// skip instead of failing. Secret registration must likewise skip when "Bifrost Language Model ori"
/// is not readable.
/// </summary>
codeunit 96018 "Copilot Install Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        ProbeCodeTok: Label 'X-INS-PERM', Locked = true;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ClaimChatProvider_WithoutSetupPermission_SkipsWithoutError()
    var
        BifrostSetup: Record "Setup ori";
        CopilotInstall: Codeunit "Copilot Install ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] a restricted user who can run the install codeunit but cannot read or write Foundation "Setup ori"
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM ori');

        Assert.IsFalse(BifrostSetup.ReadPermission(), 'O365 Basic plus BIFROST LLM ori must not grant Read on Setup ori.');
        Assert.IsFalse(BifrostSetup.WritePermission(), 'O365 Basic plus BIFROST LLM ori must not grant Write on Setup ori.');

        // [WHEN] the install claim runs
        CopilotInstall.ClaimChatProvider();

        // [THEN] it returns without error (no GetRecordOnce / Modify on Setup ori) and logs ORI-BIF-0422
        LibraryLowerPermissions.SetOutsideO365Scope();
    end;

    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ClaimChatProvider_WhenNone_ClaimsLanguageModels()
    var
        BifrostSetup: Record "Setup ori";
        ClaimedSetup: Record "Setup ori";
        CopilotInstall: Codeunit "Copilot Install ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        OriginalChatProviderType: Enum "Chat Provider Type ori";
    begin
        // [GIVEN] a permitted caller (lowered permissions from the restrictive test persist per codeunit) and "Chat Provider Type" still None
        LibraryLowerPermissions.SetOutsideO365Scope();
        BifrostSetup.GetRecordOnce();
        OriginalChatProviderType := BifrostSetup."Chat Provider Type";
        BifrostSetup."Chat Provider Type" := Enum::"Chat Provider Type ori"::None;
        BifrostSetup.Modify();

        // [WHEN] the install claim runs
        CopilotInstall.ClaimChatProvider();

        // [THEN] Language Models owns the chat provider
        ClaimedSetup.GetRecordOnce();
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, ClaimedSetup."Chat Provider Type", 'The permitted claim must set Chat Provider Type to LanguageModels.');

        // Restore the original value so later tests see the same setup
        ClaimedSetup."Chat Provider Type" := OriginalChatProviderType;
        ClaimedSetup.Modify();
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure RegisterSecrets_WithoutLanguageModelRead_SkipsWithoutError()
    var
        LangModel: Record "Bifrost Language Model ori";
        AppSecret: Record "App Secret ori";
        CopilotInstall: Codeunit "Copilot Install ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] a language model with its secret rows removed, visible only while permissions are open
        LibraryLowerPermissions.SetOutsideO365Scope();
        PrepareProbeModelWithoutSecrets();

        // [GIVEN] a caller who can run the install codeunit but cannot read "Bifrost Language Model ori"
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('LM Install Exec Tst');
        Assert.IsFalse(LangModel.ReadPermission(), 'LM Install Exec Tst must not grant Read on Bifrost Language Model ori.');

        // [WHEN] install/upgrade secret registration runs
        CopilotInstall.RegisterSecrets();

        // [THEN] it returns without error and does not recreate the secret rows
        LibraryLowerPermissions.SetOutsideO365Scope();
        Assert.IsFalse(
            AppSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetServiceKeyCode(ProbeCodeTok)),
            'A skipped registration must not recreate the shared secret.');
        Assert.IsFalse(
            AppSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetUserKeyCode(ProbeCodeTok)),
            'A skipped registration must not recreate the personal secret.');
        DeleteProbeModel();
    end;

    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure RegisterSecrets_WithReadPermission_RegistersSecrets()
    var
        AppSecret: Record "App Secret ori";
        CopilotInstall: Codeunit "Copilot Install ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] a permitted caller and a language model whose secret rows were removed
        LibraryLowerPermissions.SetOutsideO365Scope();
        PrepareProbeModelWithoutSecrets();

        // [WHEN] install/upgrade secret registration runs
        CopilotInstall.RegisterSecrets();

        // [THEN] both secret rows are registered again
        Assert.IsTrue(
            AppSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetServiceKeyCode(ProbeCodeTok)),
            'RegisterSecrets must register the shared secret when Read is permitted.');
        Assert.IsTrue(
            AppSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetUserKeyCode(ProbeCodeTok)),
            'RegisterSecrets must register the personal secret when Read is permitted.');
        DeleteProbeModel();
    end;

    local procedure PrepareProbeModelWithoutSecrets()
    var
        LangModel: Record "Bifrost Language Model ori";
    begin
        DeleteProbeModel();
        LangModel.Init();
        LangModel.Code := ProbeCodeTok;
        LangModel.Description := 'Install permission probe';
        LangModel.Insert(true);
        DeleteProbeSecrets();
    end;

    local procedure DeleteProbeModel()
    var
        LangModel: Record "Bifrost Language Model ori";
    begin
        if LangModel.Get(ProbeCodeTok) then
            LangModel.Delete(true);
        DeleteProbeSecrets();
    end;

    local procedure DeleteProbeSecrets()
    var
        AppSecret: Record "App Secret ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        if AppSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetServiceKeyCode(ProbeCodeTok)) then
            AppSecret.Delete(true);
        if AppSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetUserKeyCode(ProbeCodeTok)) then
            AppSecret.Delete(true);
    end;
}
