namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.Apps;
using System.Environment.Configuration;
using System.Security.AccessControl;
using System.TestLibraries.Utilities;
using System.Threading;

/// <summary>Issue 105: real Assisted Setup registration with platform-only permissions, without running the wizard.</summary>
codeunit 96040 "LangModel Wizard Reg Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>The restricted caller sees one English wizard after each real registration.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC02_EnglishPlatformCaller_RegistersOnce()
    begin
        // Story #105, AC02/AC03 | Time: independent | Risk: metadata only
        VerifyRegistration(1033, 'Set up Bifrost Language Models');
    end;

    /// <summary>The restricted caller sees one Icelandic wizard after each real registration.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC03_IcelandicPlatformCaller_RegistersOnce()
    begin
        // Story #105, AC02/AC03 | Time: independent | Risk: metadata only
        VerifyRegistration(1039, 'Setja upp Bifröst mállíkön');
    end;

    /// <summary>Metadata enumeration does not elevate the caller to launch the wizard.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC05_MetadataCaller_WizardExecutionRefused()
    var
        Wizard: TestPage "LangModel Setup Wizard ori";
    begin
        // Story #105, AC05 | Time: independent | Risk: no business writes
        // [GIVEN] A caller with platform metadata access only, after the real registration event.
        InitializeRestrictedCaller();
        OpenAssistedSetup();
        // [WHEN] That caller attempts to execute the app wizard.
        asserterror Wizard.OpenView();
        // [THEN] The platform refuses business setup access before any wizard operation.
        Assert.ExpectedError('10077901');
        LowerPermissions.SetOutsideO365Scope();
    end;

    /// <summary>Metadata enumeration does not grant language model or security administration.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC05_MetadataCaller_BusinessAndAdminRefused()
    var
        Model: Record "Bifrost Language Model ori";
        Setup: Record "Setup ori";
        AccessControl: Record "Access Control";
        AppSetting: Record "NAV App Setting";
        WizardMgt: Codeunit "LangModel Wizard Mgt ori";
        HadHttpWritePermission: Boolean;
    begin
        // Story #105, AC05 | Time: independent | Risk: refused operations only
        // [GIVEN] No SUPER, Bifrost or Language Models role is assigned to the caller.
        InitializeRestrictedCaller();
        HadHttpWritePermission := AppSetting.WritePermission();
        OpenAssistedSetup();
        // [THEN] Metadata access grants no writes to business, setup, HTTP or role assignments.
        Assert.IsFalse(Model.WritePermission(), 'Metadata enumeration must not grant model writes.');
        Assert.IsFalse(Setup.WritePermission(), 'Metadata enumeration must not grant Foundation configuration writes.');
        Assert.IsFalse(AccessControl.WritePermission(), 'Metadata enumeration must not grant security administration.');
        Assert.AreEqual(HadHttpWritePermission, AppSetting.WritePermission(), 'Registration must not increase the caller''s platform HTTP-setting permissions.');
        // [WHEN] The caller invokes an app administrative command.
        asserterror WizardMgt.GiveChatAccess(CreateGuid());
        // [THEN] Security administration is refused before any target user or assignment is touched.
        Assert.ExpectedError('SUPER');
        LowerPermissions.SetOutsideO365Scope();
    end;

    /// <summary>Only standard registry metadata changes; configuration and completion remain untouched.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC04_Registration_PreservesConfiguration()
    var
        GuidedExperience: Codeunit "Guided Experience";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        BeforeState: Text;
        WasComplete: Boolean;
    begin
        // Story #105, AC04 | Time: independent | Risk: read-only business state
        // [GIVEN] A snapshot of existing business/configuration metadata; no consent or licence setup.
        LowerPermissions.SetOutsideO365Scope();
        BeforeState := ConfigurationFingerprint();
        WasComplete := GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"LangModel Setup Wizard ori");
        HttpMock.Configure(500, '', false, false);
        BindSubscription(HttpMock);
        // [WHEN] A platform-only user enumerates Assisted Setup twice through its real page.
        InitializeRestrictedCaller();
        OpenAssistedSetup();
        OpenAssistedSetup();
        LowerPermissions.SetOutsideO365Scope();
        UnbindSubscription(HttpMock);
        // [THEN] No provider request, business/configuration mutation or completion occurs.
        Assert.AreEqual(0, HttpMock.GetCallCount(), 'Registration must not call a language model provider.');
        Assert.IsTrue(BeforeState = ConfigurationFingerprint(), 'Registration must preserve all observed business/configuration rows.');
        Assert.AreEqual(WasComplete, GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"LangModel Setup Wizard ori"), 'Registration must not complete or reset the wizard.');
    end;

    local procedure InitializeRestrictedCaller()
    begin
        // Standard supported BC sign-in/enumeration baseline, including platform event subscribers.
        // It grants neither this subscriber nor any Language Models business codeunit/page.
        LowerPermissions.SetExactPermissionSet('D365 BASIC');
    end;

    local procedure VerifyRegistration(LanguageId: Integer; ExpectedTitle: Text)
    var
        GuidedExperience: Codeunit "Guided Experience";
        OriginalLanguage: Integer;
    begin
        // [GIVEN] No pre-existing entry can satisfy the registration assertion.
        LowerPermissions.SetOutsideO365Scope();
        GuidedExperience.Remove(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"LangModel Setup Wizard ori");
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        InitializeRestrictedCaller();
        // [WHEN] The page raises OnRegisterAssistedSetup on both opens.
        // [THEN] Each rendered list contains exactly one translated wizard entry.
        AssertWizardCount(ExpectedTitle);
        AssertWizardCount(ExpectedTitle);
        Assert.IsTrue(GuidedExperience.Exists(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"LangModel Setup Wizard ori"), 'The actual wizard page must be registered.');
        GlobalLanguage(OriginalLanguage);
        LowerPermissions.SetOutsideO365Scope();
    end;

    local procedure AssertWizardCount(ExpectedTitle: Text)
    var
        AssistedSetup: TestPage "Assisted Setup";
        MatchingEntries: Integer;
        ObservedTitles: TextBuilder;
    begin
        AssistedSetup.OpenView();
        if AssistedSetup.First() then
            repeat
                ObservedTitles.AppendLine(AssistedSetup.Name.Value);
                if AssistedSetup.Name.Value = ExpectedTitle then
                    MatchingEntries += 1;
            until not AssistedSetup.Next();
        AssistedSetup.Close();
        Assert.AreEqual(1, MatchingEntries, 'The translated wizard must appear exactly once. Observed titles: ' + ObservedTitles.ToText());
    end;

    local procedure OpenAssistedSetup()
    var
        AssistedSetup: TestPage "Assisted Setup";
    begin
        AssistedSetup.OpenView();
        AssistedSetup.Close();
    end;

    local procedure ConfigurationFingerprint(): Text
    var
        Snapshot: TextBuilder;
    begin
        AppendRowVersions(Snapshot, Database::"Bifrost Language Model ori");
        AppendRowVersions(Snapshot, Database::"Setup ori");
        AppendRowVersions(Snapshot, Database::"User Setup ori");
        AppendRowVersions(Snapshot, Database::"App Secret ori");
        AppendRowVersions(Snapshot, Database::"Job Queue Entry");
        AppendRowVersions(Snapshot, Database::"NAV App Setting");
        AppendRowVersions(Snapshot, Database::"Access Control");
        exit(Snapshot.ToText());
    end;

    local procedure AppendRowVersions(var Snapshot: TextBuilder; TableId: Integer)
    var
        Source: RecordRef;
    begin
        // Never read or log secret values: compare row identities and modification timestamps only.
        Source.Open(TableId);
        Snapshot.AppendLine(Format(TableId, 0, 9));
        if Source.FindSet() then
            repeat
                Snapshot.AppendLine(Format(Source.RecordId(), 0, 9));
                Snapshot.AppendLine(Format(Source.Field(Source.SystemModifiedAtNo()).Value, 0, 9));
            until Source.Next() = 0;
        Source.Close();
    end;
}
