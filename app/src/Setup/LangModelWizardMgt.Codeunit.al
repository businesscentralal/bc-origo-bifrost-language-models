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

    var
        HttpPermissionErr: Label 'HTTP could not be enabled. Ask an administrator with write permission on NAV App Setting to enable Allow HttpClient Requests for Bifrost Language Models, then choose Verify.', Comment = 'is-IS=Ekki tókst að virkja HTTP. Biddu stjórnanda með skrifheimild á NAV App Setting um að virkja Leyfa HttpClient-beiðnir fyrir Bifröst mállíkön og veldu síðan Staðfesta.';
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

    /// <summary>Enables outbound HTTP only for this app on explicit administrator request.</summary>
    internal procedure EnableHttp()
    var
        AppSetting: Record "NAV App Setting";
        AppInfo: ModuleInfo;
    begin
        if not CanEnableHttp() then
            Error(ErrorInfo.Create(HttpPermissionErr));
        NavApp.GetCurrentModuleInfo(AppInfo);
        if not AppSetting.Get(AppInfo.Id()) then begin
            AppSetting.Init();
            AppSetting."App ID" := AppInfo.Id();
            AppSetting.Insert();
        end;
        AppSetting."Allow HttpClient Requests" := true;
        AppSetting.Modify();
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
        if not HasChatSet(SecurityId, false) then begin
            FindChatSet(PermissionSet, false);
            UserPermissions.AssignPermissionSets(SecurityId, CompanyName(), PermissionSet);
        end;
        if not HasChatSet(SecurityId, true) then begin
            FindChatSet(PermissionSet, true);
            UserPermissions.AssignPermissionSets(SecurityId, CompanyName(), PermissionSet);
        end;
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
