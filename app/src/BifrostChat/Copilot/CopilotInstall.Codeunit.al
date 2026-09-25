namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Install codeunit of Bifrost Language Models.
/// Per database it registers the Copilot capability with Microsoft's Copilot framework; the same
/// registration runs again from "Copilot Upgrade ori".
/// Per company it registers the API key secrets of every existing language model with the Foundation secret store
/// and claims the chat provider on "Setup ori" when that table is readable and writable.
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
    /// Skips without error when the caller cannot read or write "Setup ori", or when GetRecordOnce
    /// or Modify still fails under a partial grant. Each skip emits telemetry ORI-BIF-0422.
    /// Publishing Foundation re-runs OnInstallAppPerCompany in a context with no TableData permission
    /// on that table (OrigoSoftwareSolutions/bc-origo-bifrost-core#122); that read must not fail the install.
    /// Chat Provider Type stays None until a user with permission claims it.
    /// </summary>
    procedure ClaimChatProvider()
    var
        BifrostSetup: Record "Setup ori";
    begin
        // GetRecordOnce reads "Setup ori" and inserts the singleton when it is missing; the claim then Modify()s it.
        // Probe first so a missing grant never raises during OnInstallAppPerCompany. TryFunctions cover a partial
        // grant (WritePermission true for any of insert/modify/delete, or an indirect permission the write still rejects).
        if not BifrostSetup.ReadPermission() then begin
            LogClaimSkipped('Read');
            exit;
        end;
        if not BifrostSetup.WritePermission() then begin
            LogClaimSkipped('Write');
            exit;
        end;
        if not TryGetSetupOnce(BifrostSetup) then begin
            LogClaimSkipped('Write');
            exit;
        end;

        if BifrostSetup."Chat Provider Type" <> Enum::"Chat Provider Type ori"::None then
            exit;

        if not BifrostSetup.WritePermission() then begin
            LogClaimSkipped('Write');
            exit;
        end;

        BifrostSetup."Chat Provider Type" := Enum::"Chat Provider Type ori"::LanguageModels;
        if not TryModifyClaim(BifrostSetup) then
            LogClaimSkipped('Modify');
    end;

    /// <summary>
    /// Emits the admin signal for a skipped claim: "Chat Provider Type" stays None until a user
    /// with permission claims it. Event ORI-BIF-0422. Dimensions are system metadata only.
    /// </summary>
    /// <param name="DeniedPermission">Read, Write, or Modify. No customer data.</param>
    local procedure LogClaimSkipped(DeniedPermission: Text)
    var
        CustomDimensions: Dictionary of [Text, Text];
        ClaimSkippedTok: Label 'ORI-BIF-0422', Locked = true;
        ClaimSkippedMsg: Label 'Chat provider claim skipped at install (permission missing).', Locked = true;
    begin
        CustomDimensions.Add('tableId', Format(Database::"Setup ori", 0, 9));
        CustomDimensions.Add('deniedPermission', CopyStr(DeniedPermission, 1, 250));
        Session.LogMessage(ClaimSkippedTok, ClaimSkippedMsg, Verbosity::Warning,
            DataClassification::SystemMetadata, TelemetryScope::All, CustomDimensions);
    end;

    [TryFunction]
    local procedure TryGetSetupOnce(var BifrostSetup: Record "Setup ori")
    begin
        BifrostSetup.GetRecordOnce();
    end;

    [TryFunction]
    local procedure TryModifyClaim(var BifrostSetup: Record "Setup ori")
    begin
        BifrostSetup.Modify();
    end;

    /// <summary>
    /// Registers the API key secrets of every existing language model with the Bifrost Foundation
    /// secret store, so the administrator sees on Bifrost App Secrets which keys still need a value.
    /// Idempotent - called from install and from upgrade.
    /// </summary>
    procedure RegisterSecrets()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        LangModelSecrets.RegisterAll();
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
