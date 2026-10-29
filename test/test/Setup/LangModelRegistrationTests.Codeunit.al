namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests that Bifrost Language Models makes itself known to Bifrost Foundation's application
/// registry. Setup notifications live on the Bifrost Setup page only, so the registration
/// subscriber in "LangModel Registration ori" is the app's whole contribution to them.
/// </summary>
codeunit 96016 "LangModel Registration Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;

        IsInitialized := true;
    end;

    /// <summary>
    /// Verifies that Bifrost Language Models registers itself in Bifrost Foundation's app registry.
    /// </summary>
    [Test]
    procedure AppRegistry_ListsLanguageModelsWithItsSetupPage()
    var
        TempRegisteredApp: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        LangModelAppId: Guid;
    begin
        // [SCENARIO] Bifrost Language Models registers itself in Bifrost Foundation's app registry
        // with its own module id and the object id of its setup page.
        Initialize();

        // [GIVEN] The module id of Bifrost Language Models
        LangModelAppId := LangModelSecrets.GetAppId();

        // [WHEN] The registry is built
        AppRegistry.GetApps(TempRegisteredApp);

        // [THEN] Bifrost Language Models is one of the registered applications
        Assert.IsTrue(TempRegisteredApp.Get(LangModelAppId), 'Bifrost Language Models must register itself in the Bifrost app registry.');

        // [THEN] It points at its own setup page and carries its display name
        Assert.AreEqual(Page::"LangModel Setup ori", TempRegisteredApp."Setup Page Id", 'The registry must point at the Bifrost Language Models setup page.');
        Assert.AreNotEqual('', TempRegisteredApp."App Name", 'The registry must carry the Bifrost Language Models app name.');
    end;

    /// <summary>
    /// A restricted licence administrator can open Bifrost Setup while Language Models is installed.
    /// Without InherentPermissions X on LangModel Registration ori, OnRegisterApps aborts the page.
    /// </summary>
    [Test]
    procedure LicAdm_OpensBifrostSetup_WithLanguageModelsInstalled()
    var
        BifrostSetup: Record "Setup ori";
        TempRegisteredApp: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        SetupPage: TestPage "Setup ori";
        LangModelAppId: Guid;
    begin
        // Story #91, AC02/AC03 | Time: independent of Today/WorkDate | Risk: none
        // [GIVEN] The Bifrost Setup singleton exists and Language Models is installed.
        BifrostSetup.InsertIfNotExists();
        LangModelAppId := LangModelSecrets.GetAppId();
        Commit();

        // [WHEN] A licence administrator opens Bifrost Setup.
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST LicAdm ori');
        LowerPermissions.AddPermissionSet('LM Setup Base ori');
        AppRegistry.GetApps(TempRegisteredApp);
        SetupPage.OpenView();

        // [THEN] The registration subscriber ran and the page opened non-editable.
        Assert.IsTrue(TempRegisteredApp.Get(LangModelAppId), 'OnRegisterApps must register Language Models under a licence administrator.');
        Assert.AreEqual(Page::"LangModel Setup ori", TempRegisteredApp."Setup Page Id", 'The registry must still point at the Language Models setup page.');
        Assert.IsFalse(SetupPage.Editable(), 'A licence administrator is not a Bifrost administrator.');
        SetupPage.Close();
        LowerPermissions.StopLoggingNAVPermissions();
    end;
}
