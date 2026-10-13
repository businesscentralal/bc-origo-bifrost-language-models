namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Install codeunit of Bifrost Language Models.
/// Per database it registers the Copilot capability with Microsoft's Copilot framework; the same
/// registration runs again from "Copilot Upgrade ori".
/// Per company it registers the API key secrets of every existing language model with the Foundation secret store
/// and claims the chat provider through Foundation's "Setup ori".TryClaimChatProvider.
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
    /// Claims "Setup ori"."Chat Provider Type" for Language Models through Foundation's
    /// TryClaimChatProvider, which carries its own inherent permissions, so the caller needs no
    /// permission on "Setup ori" (OrigoSoftwareSolutions/bc-origo-bifrost-core#122, #251, #881).
    /// The claim succeeds only while the value is None or already LanguageModels; another app or an
    /// administrator that holds it is never overridden. Called from install and from upgrade.
    /// </summary>
    procedure ClaimChatProvider()
    var
        BifrostSetup: Record "Setup ori";
    begin
        // False means another provider already holds the claim; it is left unchanged, without telemetry or error.
        if BifrostSetup.TryClaimChatProvider(Enum::"Chat Provider Type ori"::LanguageModels) then
            exit;
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

    /// <summary>
    /// Confirms the user's setup command, registers the capability before initializing the model,
    /// and reports success only after both operations complete. Cancellation leaves setup unchanged.
    /// </summary>
    /// <returns>True after successful initialization; false when the user declines.</returns>
    internal procedure InitCopilotDefaults(): Boolean
    var
        ConfirmQst: Label 'This will register the Bifrost Copilot capability as Microsoft Billed, create or update the COPILOT language model, and refresh its default skill content.\Do you want to continue?', Comment = 'is-IS=Þetta mun skrá Bifröst Copilot-getu sem Microsoft-reiknuð, búa til eða uppfæra COPILOT-mállíkanið og uppfæra sjálfgefið hæfniefni.\Viltu halda áfram?';
        DoneMsg: Label 'Copilot defaults initialized successfully.', Comment = 'is-IS=Copilot sjálfgildi frumstillt.';
    begin
        if not Confirm(ConfirmQst, false) then
            exit(false);
        RegisterCapability();
        InitDefaultLanguageModel();
        Message(DoneMsg);
        exit(true);
    end;

    /// <summary>
    /// Registers or updates the Bifrost Chat Copilot capability with Microsoft billing.
    /// </summary>
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

    /// <summary>
    /// Creates the COPILOT language model when missing and refreshes its skill; preserves an existing default model.
    /// </summary>
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
