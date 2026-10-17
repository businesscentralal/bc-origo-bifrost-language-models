namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Identifies the operation to execute on the Bifrost Language Model Provider interface.
/// Adding new values extends the interface without changing its signature.
/// </summary>
enum 10035338 "Bifrost Chat Proc. Type ori"
{
    Extensible = true;

    value(0; " ") { Caption = ' ', Comment = 'is-IS= '; }

    // Config-dependent operations
    value(10; IsConfigured) { Caption = 'IsConfigured', Comment = 'is-IS=Er stillt'; }
    value(11; BuildConfigJson) { Caption = 'BuildConfigJson', Comment = 'is-IS=Búa til JSON-stillingar'; }
    value(12; SendChatMessage) { Caption = 'SendChatMessage', Comment = 'is-IS=Senda spjallskilaboð'; }
    value(13; ContinueWithToolResults) { Caption = 'ContinueWithToolResults', Comment = 'is-IS=Halda áfram með niðurstöður verkfæra'; }
    value(14; GetAvailableModels) { Caption = 'GetAvailableModels', Comment = 'is-IS=Sækja tiltæk líkön'; }
    value(15; TestConnection) { Caption = 'TestConnection', Comment = 'is-IS=Prófa tengingu'; }
    value(16; GetTokenUsage) { Caption = 'GetTokenUsage', Comment = 'is-IS=Sækja notkun tákna'; }
    value(17; CompletePrompt) { Caption = 'CompletePrompt', Comment = 'is-IS=Vinna kvaðningu'; }

    // Provider metadata
    value(100; GetProviderName) { Caption = 'GetProviderName', Comment = 'is-IS=Sækja heiti veitanda'; }
    value(101; RequiresApiKey) { Caption = 'RequiresApiKey', Comment = 'is-IS=Krefst API-lykils'; }
    value(102; GetApiKeyLabel) { Caption = 'GetApiKeyLabel', Comment = 'is-IS=Sækja heiti API-lykils'; }
    value(103; GetApiKeyInstruction) { Caption = 'GetApiKeyInstruction', Comment = 'is-IS=Sækja leiðbeiningar um API-lykil'; }
    value(104; GetApiKeyPlaceholder) { Caption = 'GetApiKeyPlaceholder', Comment = 'is-IS=Sækja staðgengil API-lykils'; }
    value(105; GetApiKeyDocsUrl) { Caption = 'GetApiKeyDocsUrl', Comment = 'is-IS=Sækja vefslóð API-lykils'; }
    value(106; GetApiKeyDocsLinkText) { Caption = 'GetApiKeyDocsLinkText', Comment = 'is-IS=Sækja texta tengils að API-lykli'; }
    value(107; GetServiceKeyDescription) { Caption = 'GetServiceKeyDescription', Comment = 'is-IS=Sækja lýsingu sameiginlegs lykils'; }
    value(108; HasServiceKeyPermission) { Caption = 'HasServiceKeyPermission', Comment = 'is-IS=Er með heimild fyrir sameiginlegum lykli'; }
    value(110; GetMaxToolCount) { Caption = 'GetMaxToolCount', Comment = 'is-IS=Sækja hámarksfjölda verkfæra'; }
    value(111; SupportsSplitToolExecution) { Caption = 'SupportsSplitToolExecution', Comment = 'is-IS=Styður aðskilda keyrslu verkfæra'; }
    value(112; SupportsModelSelection) { Caption = 'SupportsModelSelection', Comment = 'is-IS=Styður val á líkani'; }
    value(113; SupportsToolCalling) { Caption = 'SupportsToolCalling', Comment = 'is-IS=Styður verkfæraköll'; }
    value(114; HasExternalEndpoint) { Caption = 'HasExternalEndpoint', Comment = 'is-IS=Er með ytri endapunkt'; }
    value(115; RequiresChatPath) { Caption = 'RequiresChatPath', Comment = 'is-IS=Krefst spjallslóðar'; }
    value(116; RequiresModelsPath) { Caption = 'RequiresModelsPath', Comment = 'is-IS=Krefst líkanaslóðar'; }
    value(120; GetDefaultBaseUrl) { Caption = 'GetDefaultBaseUrl', Comment = 'is-IS=Sækja sjálfgefna grunnslóð'; }
    value(121; GetDefaultModel) { Caption = 'GetDefaultModel', Comment = 'is-IS=Sækja sjálfgefið líkan'; }
    value(122; GetDefaultTimeoutSeconds) { Caption = 'GetDefaultTimeoutSeconds', Comment = 'is-IS=Sækja sjálfgefin tímamörk í sekúndum'; }
    value(123; GetDefaultMaxTokens) { Caption = 'GetDefaultMaxTokens', Comment = 'is-IS=Sækja sjálfgefinn hámarksfjölda tákna'; }
    value(124; GetDefaultContextTokens) { Caption = 'GetDefaultContextTokens', Comment = 'is-IS=Sækja sjálfgefin samhengistákn'; }
    value(125; GetDefaultSkillUrl) { Caption = 'GetDefaultSkillUrl', Comment = 'is-IS=Sækja sjálfgefna vefslóð hæfni'; }
    value(126; GetDefaultSkillText) { Caption = 'GetDefaultSkillText', Comment = 'is-IS=Sækja sjálfgefinn hæfnitexta'; }
}
