namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Issue 82 users-grid regressions with isolated users and permission assignments.</summary>
codeunit 96038 "LangModel Wizard Users Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        WizardMgt: Codeunit "LangModel Wizard Mgt ori";

    /// <summary>The rendered columns distinguish neither, either and both chat sets.</summary>
    [Test]
    procedure Scenario_AC02_PermissionCombinations_ShowIndependentColumns()
    var
        NeitherUser: Record User;
        FoundationUser: Record User;
        LanguageModelUser: Record User;
        BothUser: Record User;
        Users: TestPage "LangModel Wizard Users ori";
    begin
        // Story #82, AC02 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] Four enabled users with independently assigned application sets.
        CreateUser(NeitherUser);
        CreateUser(FoundationUser);
        CreateUser(LanguageModelUser);
        CreateUser(BothUser);
        AddAssignment(FoundationUser, false, CompanyName(), FoundationAppId());
        AddAssignment(LanguageModelUser, true, CompanyName(), LanguageModelsAppId());
        AddAssignment(BothUser, false, CompanyName(), FoundationAppId());
        AddAssignment(BothUser, true, CompanyName(), LanguageModelsAppId());
        // [WHEN] The users page loads its snapshot and renders each user.
        Users.OpenView();
        // [THEN] Both flags reflect the specific set, including false after a true row.
        Users.GoToRecord(BothUser);
        Users.HasFoundationChat.AssertEquals(true);
        Users.HasLanguageModelsChat.AssertEquals(true);
        Users.GoToRecord(NeitherUser);
        Users.HasFoundationChat.AssertEquals(false);
        Users.HasLanguageModelsChat.AssertEquals(false);
        Users.GoToRecord(FoundationUser);
        Users.HasFoundationChat.AssertEquals(true);
        Users.HasLanguageModelsChat.AssertEquals(false);
        Users.GoToRecord(LanguageModelUser);
        Users.HasFoundationChat.AssertEquals(false);
        Users.HasLanguageModelsChat.AssertEquals(true);
        Users.Close();
        DeleteUser(NeitherUser);
        DeleteUser(FoundationUser);
        DeleteUser(LanguageModelUser);
        DeleteUser(BothUser);
    end;

    /// <summary>Global grants apply, while grants scoped to another company do not.</summary>
    [Test]
    procedure Scenario_AC02_GlobalAndOtherCompany_RespectCompanyScope()
    var
        SelectedUser: Record User;
        Users: TestPage "LangModel Wizard Users ori";
    begin
        // Story #82, AC02 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] One global grant and one grant for a different company.
        CreateUser(SelectedUser);
        AddAssignment(SelectedUser, false, '', FoundationAppId());
        AddAssignment(SelectedUser, true, CopyStr(Format(CreateGuid(), 0, 4), 1, 30), LanguageModelsAppId());
        // [WHEN] The current-company users grid opens.
        Users.OpenView();
        Users.GoToRecord(SelectedUser);
        // [THEN] Only the global set is displayed as assigned.
        Users.HasFoundationChat.AssertEquals(true);
        Users.HasLanguageModelsChat.AssertEquals(false);
        Users.Close();
        DeleteUser(SelectedUser);
    end;

    /// <summary>A matching role name from another app must not count as a chat grant.</summary>
    [Test]
    procedure Scenario_AC02_SameRoleDifferentApp_DoesNotCount()
    var
        SelectedUser: Record User;
        Users: TestPage "LangModel Wizard Users ori";
    begin
        // Story #82, AC02 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] Same-name permission assignments from an unrelated app identity.
        CreateUser(SelectedUser);
        AddAssignment(SelectedUser, false, CompanyName(), CreateGuid());
        AddAssignment(SelectedUser, true, CompanyName(), CreateGuid());
        // [WHEN] The user is rendered.
        Users.OpenView();
        Users.GoToRecord(SelectedUser);
        // [THEN] Neither unrelated assignment is mistaken for a product set.
        Users.HasFoundationChat.AssertEquals(false);
        Users.HasLanguageModelsChat.AssertEquals(false);
        Users.Close();
        DeleteUser(SelectedUser);
    end;

    /// <summary>Model choices are loaded once and absent setup does not inherit the previous row's model.</summary>
    [Test]
    procedure Scenario_AC02_ModelThenMissingSetup_ClearsDisplayedModel()
    var
        ConfiguredUser: Record User;
        UnconfiguredUser: Record User;
        Model: Record "Bifrost Language Model ori";
        Users: TestPage "LangModel Wizard Users ori";
    begin
        // Story #82, AC02 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] Only one of two users has a company model assignment.
        CreateUser(ConfiguredUser);
        CreateUser(UnconfiguredUser);
        Model.Code := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Model.Code));
        Model.Insert(true);
        WizardMgt.SetUserModel(ConfiguredUser."User Security ID", Model.Code);
        // [WHEN] The grid moves from the configured to the unconfigured user.
        Users.OpenView();
        Users.GoToRecord(ConfiguredUser);
        Users.UserModel.AssertEquals(Model.Code);
        Users.GoToRecord(UnconfiguredUser);
        // [THEN] The model column is empty rather than stale.
        Users.UserModel.AssertEquals('');
        Users.Close();
        DeleteUser(ConfiguredUser);
        DeleteUser(UnconfiguredUser);
        Model.Delete(true);
    end;

    /// <summary>Reloading the snapshot drops stale assignments and discovers new grants.</summary>
    [Test]
    procedure Scenario_AC02_Reload_ReplacesCachedAssignments()
    var
        SelectedUser: Record User;
        AccessControl: Record "Access Control";
        FoundationUsers: Dictionary of [Guid, Boolean];
        LanguageModelUsers: Dictionary of [Guid, Boolean];
        UserModels: Dictionary of [Guid, Code[20]];
    begin
        // Story #82, AC02 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] A loaded snapshot with only a Foundation assignment.
        CreateUser(SelectedUser);
        AddAssignment(SelectedUser, false, CompanyName(), FoundationAppId());
        WizardMgt.LoadUserStatus(FoundationUsers, LanguageModelUsers, UserModels);
        Assert.IsTrue(FoundationUsers.ContainsKey(SelectedUser."User Security ID"), 'Initial grant must be loaded.');
        // [WHEN] That assignment is replaced and the snapshot is refreshed.
        AccessControl.SetRange("User Security ID", SelectedUser."User Security ID");
        AccessControl.DeleteAll();
        AddAssignment(SelectedUser, true, CompanyName(), LanguageModelsAppId());
        WizardMgt.LoadUserStatus(FoundationUsers, LanguageModelUsers, UserModels);
        // [THEN] Removed grants are cleared and new grants are visible.
        Assert.IsFalse(FoundationUsers.ContainsKey(SelectedUser."User Security ID"), 'Removed grants must not remain cached.');
        Assert.IsTrue(LanguageModelUsers.ContainsKey(SelectedUser."User Security ID"), 'New grants must be loaded.');
        DeleteUser(SelectedUser);
    end;

    /// <summary>Snapshot reads retain the platform helper's indirect access without security administration.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC02_IndirectRead_LoadsWithoutAssignmentAuthority()
    var
        SelectedUser: Record User;
        LowerPermissions: Codeunit "Library - Lower Permissions";
        FoundationUsers: Dictionary of [Guid, Boolean];
        LanguageModelUsers: Dictionary of [Guid, Boolean];
        UserModels: Dictionary of [Guid, Code[20]];
    begin
        // Story #82, AC02 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] An isolated user with a grant, then a caller with only indirect Access Control read.
        LowerPermissions.SetOutsideO365Scope();
        CreateUser(SelectedUser);
        AddAssignment(SelectedUser, false, CompanyName(), FoundationAppId());
        LowerPermissions.SetExactPermissionSet('BIFROST LLM ori');
        LowerPermissions.AddPermissionSet('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('LM Wizard Read ori');
        // [WHEN] Both the previous platform helper and new bulk snapshot read the assignment.
        Assert.IsTrue(WizardMgt.HasChatSet(SelectedUser."User Security ID", false), 'Platform helper must allow the indirect read.');
        WizardMgt.LoadUserStatus(FoundationUsers, LanguageModelUsers, UserModels);
        // [THEN] Display remains available without granting assignment authority.
        Assert.IsTrue(FoundationUsers.ContainsKey(SelectedUser."User Security ID"), 'Bulk snapshot must preserve indirect read access.');
        Assert.IsFalse(WizardMgt.CanAssignChatAccess(), 'Read access must not grant security administration.');
        LowerPermissions.SetOutsideO365Scope();
        DeleteUser(SelectedUser);
    end;

    local procedure CreateUser(var NewUser: Record User)
    begin
        NewUser.Init();
        NewUser."User Security ID" := CreateGuid();
        NewUser."User Name" := CopyStr('X' + DelChr(Format(NewUser."User Security ID", 0, 4), '=', '-'), 1, MaxStrLen(NewUser."User Name"));
        NewUser.State := NewUser.State::Enabled;
        NewUser.Insert(true);
    end;

    local procedure DeleteUser(var OwnedUser: Record User)
    var
        AccessControl: Record "Access Control";
        UserSetup: Record "User Setup ori";
    begin
        AccessControl.SetRange("User Security ID", OwnedUser."User Security ID");
        AccessControl.DeleteAll(true);
        if UserSetup.Get(OwnedUser."User Security ID") then
            UserSetup.Delete(true);
        OwnedUser.Delete(true);
    end;

    local procedure AddAssignment(SelectedUser: Record User; LanguageModels: Boolean; AssignmentCompany: Text; AppId: Guid)
    var
        AccessControl: Record "Access Control";
    begin
        AccessControl."User Security ID" := SelectedUser."User Security ID";
        if LanguageModels then
            AccessControl."Role ID" := 'BIFROST LLM Chat ori'
        else
            AccessControl."Role ID" := 'BIFROST Chat ori';
        AccessControl.Scope := AccessControl.Scope::System;
        AccessControl."App ID" := AppId;
        AccessControl."Company Name" := CopyStr(AssignmentCompany, 1, MaxStrLen(AccessControl."Company Name"));
        AccessControl.Insert();
    end;

    local procedure FoundationAppId(): Guid
    begin
        exit('7505e808-6e52-4b96-a328-82573391297a');
    end;

    local procedure LanguageModelsAppId(): Guid
    begin
        exit('f1722684-0c24-4022-a2e0-0f63154aca76');
    end;
}
