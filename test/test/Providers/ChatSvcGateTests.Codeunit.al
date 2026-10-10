namespace Origo.Bifrost.LanguageModels.Test;
using Origo.Bifrost.LanguageModels;

using System.TestLibraries.Utilities;

/// <summary>
/// Diagnostic tests for the shared (service) API key permission gate.
/// </summary>
codeunit 96013 "Chat Svc Gate Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>
    /// Verifies that the service-key gate allows writes with test permissions disabled.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ChatSvcGate_WritePermission_WithPermissionsDisabled()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
    begin
        // With TestPermissions=Disabled, WritePermission always returns true
        Assert.IsTrue(ChatSvcGate.WritePermission(), 'WritePermission should be true when permissions are disabled');
    end;

    /// <summary>
    /// Verifies that the provider reports service-key permission with test permissions disabled.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ProviderBase_HasServiceKeyPermission_WithPermissionsDisabled()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        Assert.IsTrue(ProviderBase.HasServiceKeyPermission(), 'HasServiceKeyPermission should be true when permissions are disabled');
    end;

    /// <summary>
    /// Verifies that the granted service-key permission permits gate writes under restrictive test permissions.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ChatSvcGate_WritePermission_WithRestrictivePermissions()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] a restricted user that only holds the Chat Service permission set
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST ChatSvc ori');

        // [THEN] the gate table grants write permission
        Assert.IsTrue(ChatSvcGate.WritePermission(), 'BIFROST ChatSvc ori must grant write permission on the Chat Service gate');
    end;

    /// <summary>
    /// Verifies that the service-key gate denies writes without its permission set.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ChatSvcGate_WritePermission_WithoutPermissionSet()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] a restricted user without the Chat Service permission set
        LibraryLowerPermissions.SetO365Basic();

        // [THEN] the gate denies write permission
        Assert.IsFalse(ChatSvcGate.WritePermission(), 'a user without BIFROST ChatSvc ori must not pass the Chat Service gate');
    end;

    /// <summary>
    /// Verifies that a read of the empty gate table finds no stored rows.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ChatSvcGate_Table_IsAccessible()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
    begin
        // Verifies the table is accessible and can be queried
        ChatSvcGate.SetRange("Primary Key", 'DIAG');
        ChatSvcGate.ReadIsolation := IsolationLevel::ReadCommitted;
        Assert.IsFalse(ChatSvcGate.FindFirst(), 'Diagnostic key should not exist');
    end;
}
