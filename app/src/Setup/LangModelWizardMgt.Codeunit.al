namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;
using System.AI;
using System.Apps;
using System.Environment.Configuration;
using System.Security.AccessControl;
using System.Security.User;

/// <summary>Applies explicit wizard commands under the caller's permissions, without committing.</summary>
codeunit 10035427 "LangModel Wizard Mgt ori"
{
    Access = Internal;
    // Preserve the indirect read used by the platform User Permissions helper.
    Permissions = tabledata "Access Control" = r;

    var
        UserPermissionErr: Label 'Chat access could not be assigned. Ask an administrator with SUPER or SECURITY to assign BIFROST Chat ori and BIFROST LLM Chat ori in this company.', Comment = 'is-IS=Ekki tókst að úthluta spjallaðgangi. Biddu stjórnanda með SUPER eða SECURITY um að úthluta BIFROST Chat ori og BIFROST LLM Chat ori í þessu fyrirtæki.';
        UnknownModelErr: Label 'Language model %1 does not exist. Open Language Models and choose an existing code.', Comment = '%1 = language model code, is-IS=Mállíkanið %1 er ekki til. Opnaðu Mállíkön og veldu fyrirliggjandi kóða.';
        UserDisabledErr: Label 'The selected user is missing or disabled. Refresh the wizard and select an enabled user.', Comment = 'is-IS=Valinn notandi vantar eða er óvirkur. Endurnýjaðu leiðsögnina og veldu virkan notanda.';
        ModelPermissionErr: Label 'The language model could not be saved. Ask a Bifrost administrator to update the language model or user setup.', Comment = 'is-IS=Ekki tókst að vista mállíkanið. Biddu Bifröst stjórnanda um að uppfæra mállíkanið eða notandauppsetningu.';
        NothingConfiguredErr: Label 'Setup is not complete. Enable HTTP, configure a language model, or choose Language Models as the chat provider before finishing.', Comment = 'is-IS=Uppsetningu er ekki lokið. Virkjaðu HTTP, stilltu mállíkan eða veldu Mállíkön sem spjallveitanda áður en þú lýkur leiðsögninni.';
        PermissionSetMissingErr: Label 'Chat access could not be assigned because permission set %1 is unavailable. Ask your administrator to check the installed Bifrost apps.', Comment = '%1 = permission set, is-IS=Ekki tókst að úthluta spjallaðgangi því heimildasamstæðan %1 er ekki tiltæk. Biddu stjórnanda um að athuga uppsett Bifröst forrit.';

    /// <summary>Reads only this extension's HTTP setting, without creating one.</summary>
    internal procedure IsHttpEnabled(): Boolean
    var
        AppSetting: Record "NAV App Setting";
        AppInfo: ModuleInfo;
    begin
        if not AppSetting.ReadPermission() then
            exit(false);
        NavApp.GetCurrentModuleInfo(AppInfo);
        exit(AppSetting.Get(AppInfo.Id()) and AppSetting."Allow HttpClient Requests");
    end;

    /// <summary>Reports the caller's direct extension-settings write capability.</summary>
    internal procedure CanEnableHttp(): Boolean
    var
        AppSetting: Record "NAV App Setting";
    begin
        exit(AppSetting.WritePermission());
    end;

    /// <summary>Reads Copilot registration and activation from the owning module.</summary>
    internal procedure GetCopilotStatus(var Registered: Boolean; var Active: Boolean)
    var
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        Registered := CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori");
        Active := Registered and CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::"Bifrost Chat ori");
    end;

    /// <summary>Uses the existing confirmation and initialization flow unchanged.</summary>
    internal procedure InitializeCopilot(): Boolean
    var
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        exit(CopilotInstall.InitCopilotDefaults());
    end;

    /// <summary>Reads the current provider without inserting a setup row.</summary>
    internal procedure GetChatProvider(): Enum "Chat Provider Type ori"
    var
        Setup: Record "Setup ori";
    begin
        if Setup.Get() then
            exit(Setup."Chat Provider Type");
        exit(Enum::"Chat Provider Type ori"::None);
    end;

    /// <summary>Claims the provider through the public non-overriding Foundation API.</summary>
    internal procedure ClaimChatProvider(): Boolean
    var
        Setup: Record "Setup ori";
    begin
        exit(Setup.TryClaimChatProvider(Enum::"Chat Provider Type ori"::LanguageModels));
    end;

    /// <summary>Returns the configured default, leaving an empty configuration untouched.</summary>
    internal procedure GetDefaultModel(): Code[20]
    var
        Model: Record "Bifrost Language Model ori";
    begin
        Model.SetRange(Default, true);
        if Model.FindFirst() then
            exit(Model.Code);
    end;

    /// <summary>Validates the model before replacing the default in one transaction.</summary>
    internal procedure SetDefaultModel(ModelCode: Code[20])
    var
        Model: Record "Bifrost Language Model ori";
        PreviousModel: Record "Bifrost Language Model ori";
    begin
        CheckModel(ModelCode);
        if not Model.WritePermission() then
            Error(ErrorInfo.Create(ModelPermissionErr));
        PreviousModel.SetRange(Default, true);
        PreviousModel.ModifyAll(Default, false, true);
        Model.Get(ModelCode);
        Model.Validate(Default, true);
        Model.Modify(true);
    end;

    /// <summary>Uses the platform administrator check; product permissions cannot grant security administration.</summary>
    internal procedure CanAssignChatAccess(): Boolean
    var
        AccessControl: Record "Access Control";
        UserPermissions: Codeunit "User Permissions";
    begin
        if not AccessControl.WritePermission() then
            exit(false);
        exit(UserPermissions.IsSuper(UserSecurityId()) or UserPermissions.CanManageUsersOnTenant(UserSecurityId()));
    end;

    /// <summary>Reports the effective assignment, including platform-resolved group assignments.</summary>
    internal procedure HasChatSet(SecurityId: Guid; LanguageModels: Boolean): Boolean
    var
        PermissionSet: Record "Aggregate Permission Set";
        UserPermissions: Codeunit "User Permissions";
    begin
        FindChatSet(PermissionSet, LanguageModels);
        exit(UserPermissions.HasUserPermissionSetAssigned(SecurityId, CompanyName(), PermissionSet."Role ID", PermissionSet.Scope, PermissionSet."App ID"));
    end;

    /// <summary>Loads direct and inherited company/global chat assignments and company model choices once for the users grid.</summary>
    /// <param name="FoundationUsers">Users assigned the Foundation chat set.</param>
    /// <param name="LanguageModelUsers">Users assigned the Language Models chat set.</param>
    /// <param name="UserModels">Company-scoped model choices, keyed by user security ID.</param>
    internal procedure LoadUserStatus(var FoundationUsers: Dictionary of [Guid, Boolean]; var LanguageModelUsers: Dictionary of [Guid, Boolean]; var UserModels: Dictionary of [Guid, Code[20]])
    var
        AccessControl: Record "Access Control";
        FoundationSet: Record "Aggregate Permission Set";
        LanguageModelSet: Record "Aggregate Permission Set";
        UserSetup: Record "User Setup ori";
    begin
        Clear(FoundationUsers);
        Clear(LanguageModelUsers);
        Clear(UserModels);
        FindChatSet(FoundationSet, false);
        FindChatSet(LanguageModelSet, true);
        AccessControl.SetLoadFields("User Security ID", "Role ID", Scope, "App ID", "Company Name");
        AccessControl.SetRange(Scope, AccessControl.Scope::System);
        AccessControl.SetFilter("Role ID", '%1|%2', FoundationSet."Role ID", LanguageModelSet."Role ID");
        AccessControl.SetFilter("Company Name", '%1|%2', '', CompanyName());
        if AccessControl.FindSet() then
            repeat
                if (AccessControl."Role ID" = FoundationSet."Role ID") and (AccessControl."App ID" = FoundationSet."App ID") then
                    FoundationUsers.Set(AccessControl."User Security ID", true);
                if (AccessControl."Role ID" = LanguageModelSet."Role ID") and (AccessControl."App ID" = LanguageModelSet."App ID") then
                    LanguageModelUsers.Set(AccessControl."User Security ID", true);
            until AccessControl.Next() = 0;
        LoadInheritedChatAssignments(FoundationUsers, LanguageModelUsers);
        UserSetup.SetLoadFields("User Security ID", "Bifrost Language Model Code");
        if UserSetup.FindSet() then
            repeat
                UserModels.Set(UserSetup."User Security ID", UserSetup."Bifrost Language Model Code");
            until UserSetup.Next() = 0;
    end;

    local procedure LoadInheritedChatAssignments(var FoundationUsers: Dictionary of [Guid, Boolean]; var LanguageModelUsers: Dictionary of [Guid, Boolean])
    var
        SecurityGroups: Record "Security Group Buffer";
        Members: Record "Security Group Member Buffer";
        SecurityGroup: Codeunit "Security Group";
        SkippedGroups: List of [Code[20]];
        HasChatGroup: Boolean;
        IncompleteChatGroup: Boolean;
    begin
        SecurityGroup.GetGroups(SecurityGroups, false);
        if SecurityGroups.FindSet() then
            repeat
                HasChatGroup := HasChatGroup or FoundationUsers.ContainsKey(SecurityGroups."Group User SID") or
                    LanguageModelUsers.ContainsKey(SecurityGroups."Group User SID");
            until SecurityGroups.Next() = 0;
        if not HasChatGroup then
            exit;

        SkippedGroups := SecurityGroup.GetMembers(Members);
        ApplyGroupMemberships(SecurityGroups, Members, FoundationUsers, LanguageModelUsers);
        // A failed directory lookup must not silently turn an inherited grant into false.
        if SecurityGroups.FindSet() then
            repeat
                if SkippedGroups.Contains(SecurityGroups.Code) then
                    IncompleteChatGroup := IncompleteChatGroup or FoundationUsers.ContainsKey(SecurityGroups."Group User SID") or
                        LanguageModelUsers.ContainsKey(SecurityGroups."Group User SID");
            until SecurityGroups.Next() = 0;
        if IncompleteChatGroup then
            LoadEffectiveChatAssignments(FoundationUsers, LanguageModelUsers);
    end;

    /// <summary>Combines platform membership buffers with the already company/app-filtered assignment snapshot.</summary>
    /// <param name="SecurityGroups">Platform groups and their permission-assignment user IDs.</param>
    /// <param name="Members">Platform-resolved group memberships, held in memory.</param>
    /// <param name="FoundationUsers">Direct and inherited Foundation chat grants.</param>
    /// <param name="LanguageModelUsers">Direct and inherited Language Models chat grants.</param>
    internal procedure ApplyGroupMemberships(var SecurityGroups: Record "Security Group Buffer"; var Members: Record "Security Group Member Buffer"; var FoundationUsers: Dictionary of [Guid, Boolean]; var LanguageModelUsers: Dictionary of [Guid, Boolean])
    var
        FoundationGroups: Dictionary of [Code[20], Boolean];
        LanguageModelGroups: Dictionary of [Code[20], Boolean];
    begin
        if SecurityGroups.FindSet() then
            repeat
                if FoundationUsers.ContainsKey(SecurityGroups."Group User SID") then
                    FoundationGroups.Add(SecurityGroups.Code, true);
                if LanguageModelUsers.ContainsKey(SecurityGroups."Group User SID") then
                    LanguageModelGroups.Add(SecurityGroups.Code, true);
            until SecurityGroups.Next() = 0;
        if Members.FindSet() then
            repeat
                if FoundationGroups.ContainsKey(Members."Security Group Code") then
                    FoundationUsers.Set(Members."User Security ID", true);
                if LanguageModelGroups.ContainsKey(Members."Security Group Code") then
                    LanguageModelUsers.Set(Members."User Security ID", true);
            until Members.Next() = 0;
    end;

    local procedure LoadEffectiveChatAssignments(var FoundationUsers: Dictionary of [Guid, Boolean]; var LanguageModelUsers: Dictionary of [Guid, Boolean])
    var
        EnabledUser: Record User;
    begin
        EnabledUser.SetLoadFields("User Security ID", State);
        EnabledUser.SetRange(State, EnabledUser.State::Enabled);
        if EnabledUser.FindSet() then
            repeat
                if not FoundationUsers.ContainsKey(EnabledUser."User Security ID") then
                    if HasChatSet(EnabledUser."User Security ID", false) then
                        FoundationUsers.Set(EnabledUser."User Security ID", true);
                if not LanguageModelUsers.ContainsKey(EnabledUser."User Security ID") then
                    if HasChatSet(EnabledUser."User Security ID", true) then
                        LanguageModelUsers.Set(EnabledUser."User Security ID", true);
            until EnabledUser.Next() = 0;
    end;

    /// <summary>Assigns the two application sets through the platform API, scoped to the current company.</summary>
    internal procedure GiveChatAccess(SecurityId: Guid)
    var
        PermissionSet: Record "Aggregate Permission Set";
        UserPermissions: Codeunit "User Permissions";
    begin
        if not CanAssignChatAccess() then
            Error(ErrorInfo.Create(UserPermissionErr));
        CheckUser(SecurityId);
        // Resolve both before applying either; no direct Access Control writes or implicit commit.
        FindChatSet(PermissionSet, false);
        FindChatSet(PermissionSet, true);
        FindChatSet(PermissionSet, false);
        if not HasDirectChatAssignment(SecurityId, PermissionSet) then
            UserPermissions.AssignPermissionSets(SecurityId, CompanyName(), PermissionSet);
        FindChatSet(PermissionSet, true);
        if not HasDirectChatAssignment(SecurityId, PermissionSet) then
            UserPermissions.AssignPermissionSets(SecurityId, CompanyName(), PermissionSet);
    end;

    /// <summary>Reads the selected user's current model without creating a setup row.</summary>
    internal procedure GetUserModel(SecurityId: Guid): Code[20]
    var
        UserSetup: Record "User Setup ori";
    begin
        if UserSetup.Get(SecurityId) then
            exit(UserSetup."Bifrost Language Model Code");
    end;

    /// <summary>Validates user and model before creating or updating company-scoped user setup.</summary>
    internal procedure SetUserModel(SecurityId: Guid; ModelCode: Code[20])
    var
        UserSetup: Record "User Setup ori";
    begin
        CheckModel(ModelCode);
        CheckUser(SecurityId);
        if not UserSetup.WritePermission() then
            Error(ErrorInfo.Create(ModelPermissionErr));
        if not UserSetup.Get(SecurityId) then begin
            UserSetup.Init();
            UserSetup."User Security ID" := SecurityId;
            UserSetup.Insert(true);
        end;
        UserSetup.Validate("Bifrost Language Model Code", ModelCode);
        UserSetup.Modify(true);
    end;

    /// <summary>Completes only on explicit Finish with at least one configured prerequisite.</summary>
    internal procedure Finish()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        if not IsHttpEnabled() and (GetDefaultModel() = '') and
           (GetChatProvider() <> Enum::"Chat Provider Type ori"::LanguageModels)
        then
            Error(ErrorInfo.Create(NothingConfiguredErr));
        GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"LangModel Setup Wizard ori");
    end;

    local procedure HasDirectChatAssignment(SecurityId: Guid; PermissionSet: Record "Aggregate Permission Set"): Boolean
    var
        AccessControl: Record "Access Control";
    begin
        // Explicit assignment checks direct rows in this transaction. Effective group membership
        // remains a display concern in HasChatSet; it need not prevent an explicit company grant.
        AccessControl.SetRange("User Security ID", SecurityId);
        AccessControl.SetRange("Role ID", PermissionSet."Role ID");
        AccessControl.SetRange(Scope, PermissionSet.Scope);
        AccessControl.SetRange("App ID", PermissionSet."App ID");
        AccessControl.SetFilter("Company Name", '%1|%2', '', CompanyName());
        exit(not AccessControl.IsEmpty());
    end;

    local procedure CheckModel(ModelCode: Code[20])
    var
        Model: Record "Bifrost Language Model ori";
    begin
        if (ModelCode = '') or not Model.Get(ModelCode) then
            Error(ErrorInfo.Create(StrSubstNo(UnknownModelErr, ModelCode)));
    end;

    local procedure CheckUser(SecurityId: Guid)
    var
        SelectedUser: Record User;
    begin
        if not SelectedUser.Get(SecurityId) then
            Error(ErrorInfo.Create(UserDisabledErr));
        if SelectedUser.State <> SelectedUser.State::Enabled then
            Error(ErrorInfo.Create(UserDisabledErr));
    end;

    local procedure FindChatSet(var PermissionSet: Record "Aggregate Permission Set"; LanguageModels: Boolean)
    var
        AppInfo: ModuleInfo;
        AppId: Guid;
        RoleId: Code[20];
    begin
        if LanguageModels then begin
            NavApp.GetCurrentModuleInfo(AppInfo);
            AppId := AppInfo.Id();
            RoleId := 'BIFROST LLM Chat ori';
        end else begin
            AppId := '7505e808-6e52-4b96-a328-82573391297a';
            RoleId := 'BIFROST Chat ori';
        end;
        PermissionSet.Reset();
        PermissionSet.SetRange(Scope, PermissionSet.Scope::System);
        PermissionSet.SetRange("App ID", AppId);
        PermissionSet.SetRange("Role ID", RoleId);
        if not PermissionSet.FindFirst() then
            Error(ErrorInfo.Create(StrSubstNo(PermissionSetMissingErr, RoleId)));
    end;
}
