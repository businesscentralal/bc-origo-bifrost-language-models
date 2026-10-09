namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
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
        Assert: Codeunit "Library Assert";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        OriginalChatProviderType: Enum "Chat Provider Type ori";
        HadSetupRow: Boolean;

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
