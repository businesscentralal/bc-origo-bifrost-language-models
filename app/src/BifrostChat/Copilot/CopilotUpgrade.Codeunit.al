namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.Upgrade;

/// <summary>
/// Ensures the Copilot capability is registered after upgrade, that every language model
/// has its API key secrets registered with the Bifrost Foundation secret store, and that the chat
/// provider is claimed for Language Models when no other app holds it (#34, #35), and that the
/// LLM.Prompt.Ask caps and defaults row exists with the earlier fixed values (#120).
/// </summary>
codeunit 10035391 "Copilot Upgrade ori"
{
    Access = Internal;
    Subtype = Upgrade;

    trigger OnUpgradePerDatabase()
    var
        Install: Codeunit "Copilot Install ori";
    begin
        Install.RegisterCapability();
    end;

    trigger OnUpgradePerCompany()
    var
        Install: Codeunit "Copilot Install ori";
    begin
        Install.RegisterSecrets();
        Install.ClaimChatProvider();
        Install.InitAskSetup();
    end;
}
