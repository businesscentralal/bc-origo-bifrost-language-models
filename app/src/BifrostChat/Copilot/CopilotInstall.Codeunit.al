namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Install codeunit of Bifrost Language Models.
/// Per database it registers the Copilot capability with Microsoft's Copilot framework; the same
/// registration runs again from "Copilot Upgrade ori".
/// Per company it registers the API key secrets of every existing language model with the Foundation secret store
/// when "Bifrost Language Model ori" is readable, and claims the chat provider on "Setup ori" when that table
/// can be read, inserted and modified. A missing permission skips that step; install and upgrade never fail.
/// It never creates a language model: InitDefaultLanguageModel is called only on demand, from the
/// "Init Copilot Defaults" action on the Bifrost Language Model List page, so that installing the
/// app writes no setup data on its own.
/// </summary>
codeunit 10035390 "Copilot Install ori"
{
    Access = Internal;
    Subtype = Install;

    trigger OnInstallAppPerDatabase()
    begin
        RegisterCapability();
    end;

    trigger OnInstallAppPerCompany()
    begin
        RegisterSecrets();
        ClaimChatProvider();
    end;

    /// <summary>
    /// Claims "Setup ori"."Chat Provider Type" for Language Models, but only while it is still
    /// None, so an app (or administrator) that already claimed it is never overridden.
    /// Skips without error when the caller cannot read, insert or modify "Setup ori". Publishing Foundation
    /// re-runs OnInstallAppPerCompany in a context with no TableData permission on that table
    /// (OrigoSoftwareSolutions/bc-origo-bifrost-core#122); the read must not fail the install.
    /// </summary>
    procedure ClaimChatProvider()
    var
        BifrostSetup: Record "Setup ori";
    begin
        // GetRecordOnce reads "Setup ori" and inserts the singleton when it is missing; the claim then Modify()s it.
        // Read, Insert and Modify are checked before that data action. A Delete-only grant must not reach either call.
        if not BifrostSetup.ReadPermission() then begin
            LogClaimSkipped('Read');
            exit;
        end;
        if not BifrostSetup.InsertPermission() then begin
            LogClaimSkipped('Insert');
            exit;
        end;
        if not BifrostSetup.ModifyPermission() then begin
            LogClaimSkipped('Modify');
            exit;
        end;

        BifrostSetup.GetRecordOnce();
        if BifrostSetup."Chat Provider Type" <> Enum::"Chat Provider Type ori"::None then
            exit;
        BifrostSetup."Chat Provider Type" := Enum::"Chat Provider Type ori"::LanguageModels;
        BifrostSetup.Modify();
    end;

    /// <summary>
    /// Emits the admin signal for a skipped claim: "Chat Provider Type" stays None and nothing retries
    /// automatically, so an administrator must set it on Bifrost Setup or rerun the install with permission.
    /// </summary>
    local procedure LogClaimSkipped(DeniedPermission: Text)
    var
        CustomDimensions: Dictionary of [Text, Text];
        ClaimSkippedTok: Label 'ORI-BIF-0422', Locked = true;
        ClaimSkippedMsg: Label 'Bifrost Language Models skipped claiming the chat provider on Setup ori at install: missing TableData permission. Chat Provider Type stays unchanged until an administrator sets it.', Locked = true;
    begin
        CustomDimensions.Add('tableId', Format(Database::"Setup ori", 0, 9));
        CustomDimensions.Add('deniedPermission', DeniedPermission);
        Session.LogMessage(ClaimSkippedTok, ClaimSkippedMsg, Verbosity::Warning,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    /// <summary>
    /// Registers the API key secrets of every existing language model with the Bifrost Foundation
    /// secret store, so the administrator sees on Bifrost App Secrets which keys still need a value.
    /// Idempotent - called from install and from upgrade.
    /// Skips without error when the caller cannot read "Bifrost Language Model ori". RegisterAll
    /// FindSet()s that table; "Secret Store ori".Register then writes "App Secret ori" under inherent
    /// permissions, so the language-model read is the caller's data action to guard.
    /// </summary>
    procedure RegisterSecrets()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        if not LangModel.ReadPermission() then begin
            LogSecretsSkipped();
            exit;
        end;

        LangModelSecrets.RegisterAll();
    end;

    /// <summary>
    /// Emits the admin signal for a skipped secret registration. Nothing retries it automatically.
    /// </summary>
    local procedure LogSecretsSkipped()
    var
        CustomDimensions: Dictionary of [Text, Text];
        SecretsSkippedTok: Label 'ORI-BIF-0423', Locked = true;
        SecretsSkippedMsg: Label 'Bifrost Language Models skipped registering language model API key secrets at install or upgrade: missing TableData Read permission on Bifrost Language Model ori. Secrets stay unregistered until an administrator opens Language Models setup or reruns install or upgrade with permission.', Locked = true;
    begin
        CustomDimensions.Add('tableId', Format(Database::"Bifrost Language Model ori", 0, 9));
        CustomDimensions.Add('deniedPermission', 'Read');
        Session.LogMessage(SecretsSkippedTok, SecretsSkippedMsg, Verbosity::Warning,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    procedure RegisterCapability()
    var
        CopilotCapability: Codeunit "Copilot Capability";
        LearnMoreUrlTok: Label 'https://www.origo.is/', Locked = true;
    begin
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori") then
            CopilotCapability.RegisterCapability(
                Enum::"Copilot Capability"::"Bifrost Chat ori",
                Enum::"Copilot Availability"::"Generally Available",
                Enum::"Copilot Billing Type"::"Microsoft Billed",
                LearnMoreUrlTok)
        else
            CopilotCapability.ModifyCapability(
                Enum::"Copilot Capability"::"Bifrost Chat ori",
                Enum::"Copilot Availability"::"Generally Available",
                Enum::"Copilot Billing Type"::"Microsoft Billed",
                LearnMoreUrlTok);
    end;

    procedure InitDefaultLanguageModel()
    var
        LangModel: Record "Bifrost Language Model ori";
        DefaultSkill: Codeunit "Copilot Default Skill ori";
        CopilotCodeTok: Label 'COPILOT', Locked = true;
        CopilotDescTok: Label 'Bifrost Copilot', Comment = 'is-IS=Bifröst Copilot';
    begin
        if LangModel.Get(CopilotCodeTok) then begin
            // Update skill on existing role
            LangModel.SetSkill(DefaultSkill.GetSkillText());
#pragma warning disable AA0214
            LangModel.Modify(true);
#pragma warning restore AA0214
            exit;
        end;

        LangModel.Init();
        LangModel.Code := CopilotCodeTok;
        LangModel.Description := CopilotDescTok;
        LangModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Copilot;
        LangModel.SetSkill(DefaultSkill.GetSkillText());

        LangModel.SetRange(Default, true);
        if LangModel.IsEmpty() then
            LangModel.Default := true;
        LangModel.SetRange(Default);

        LangModel.Insert(true);
    end;
}
