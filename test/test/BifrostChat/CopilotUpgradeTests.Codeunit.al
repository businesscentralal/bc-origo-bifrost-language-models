namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Upgrade-time chat provider claim (#34). "Copilot Upgrade ori".OnUpgradePerCompany calls the same
/// "Copilot Install ori".ClaimChatProvider as the install, so an install that ran before the claim
/// existed is finished by the next upgrade. The upgrade trigger itself cannot be called from a test, so
/// these tests run the upgrade's per-company steps in the same order.
/// </summary>
codeunit 96017 "Copilot Upgrade Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        OriginalChatProviderType: Enum "Chat Provider Type ori";

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure UpgradePerCompany_WithoutSetupPermission_Claims()
    begin
        // [GIVEN] "Chat Provider Type" is None
        Initialize(Enum::"Chat Provider Type ori"::None);

        // [WHEN] the upgrade's per-company steps run for a caller without permission on "Setup ori"
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM ori');
        RunUpgradePerCompanySteps();

        // [THEN] Language Models holds the chat provider
        LibraryLowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual(Enum::"Chat Provider Type ori"::LanguageModels, CurrentChatProviderType(), 'The upgrade must claim the chat provider.');
        RestoreSetup();
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure UpgradePerCompany_WhenAnotherProviderHolds_LeavesItUnchanged()
    begin
        // [GIVEN] another app holds the chat provider
        Initialize(Enum::"Chat Provider Type ori"::MockOtherProvider);

        // [WHEN] the upgrade's per-company steps run
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM ori');
        RunUpgradePerCompanySteps();

        // [THEN] the other provider keeps the claim
        LibraryLowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual(Enum::"Chat Provider Type ori"::MockOtherProvider, CurrentChatProviderType(), 'The upgrade must not override another provider.');
        RestoreSetup();
    end;

    /// <summary>
    /// The per-company steps of "Copilot Upgrade ori".OnUpgradePerCompany, in the same order.
    /// </summary>
    local procedure RunUpgradePerCompanySteps()
    var
        Install: Codeunit "Copilot Install ori";
    begin
        Install.RegisterSecrets();
        Install.ClaimChatProvider();
    end;

    local procedure Initialize(ChatProviderType: Enum "Chat Provider Type ori")
    var
        BifrostSetup: Record "Setup ori";
    begin
        LibraryLowerPermissions.SetOutsideO365Scope();
        if not BifrostSetup.Get() then begin
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

    local procedure RestoreSetup()
    var
        BifrostSetup: Record "Setup ori";
    begin
        LibraryLowerPermissions.SetOutsideO365Scope();
        BifrostSetup.Get();
        BifrostSetup."Chat Provider Type" := OriginalChatProviderType;
        BifrostSetup.Modify();
    end;
}
