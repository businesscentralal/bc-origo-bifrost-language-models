namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Install-time chat provider claim. Publishing Foundation re-runs OnInstallAppPerCompany without
/// TableData permission on "Setup ori" (core#122); the claim must skip instead of failing.
/// </summary>
codeunit 96018 "Copilot Install Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

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
    end;

    [Test]
    procedure ClaimChatProvider_WhenNone_ClaimsLanguageModels()
    var
        BifrostSetup: Record "Setup ori";
        ClaimedSetup: Record "Setup ori";
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        // [GIVEN] a permitted caller and "Chat Provider Type" still None
        BifrostSetup.GetRecordOnce();
        BifrostSetup."Chat Provider Type" := Enum::"Chat Provider Type ori"::None;
        BifrostSetup.Modify();

        // [WHEN] the install claim runs
        CopilotInstall.ClaimChatProvider();

        // [THEN] Language Models owns the chat provider
        ClaimedSetup.GetRecordOnce();
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, ClaimedSetup."Chat Provider Type", 'The permitted claim must set Chat Provider Type to LanguageModels.');
    end;
}
