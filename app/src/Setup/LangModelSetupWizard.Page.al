namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;
using System.AI;
using System.Security.AccessControl;
using System.Security.User;

/// <summary>Guides administrators through optional Language Models setup steps and explicit completion.</summary>
page 10035345 "LangModel Setup Wizard ori"
{
    PageType = NavigatePage;
    Extensible = false;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    ContextSensitiveHelpPage = 'language-models-setup';
    Caption = 'Set up Bifrost Language Models', Comment = 'is-IS=Setja upp Bifröst mállíkön';

    layout
    {
        area(Content)
        {
            group(Welcome)
            {
                Visible = CurrentStep = 1;
                Caption = 'Welcome to Bifrost Chat', Comment = 'is-IS=Velkomin í Bifröst spjall';
                InstructionalText = 'Bifrost Chat lets you work with Business Central through a language model. Enable HTTP, initialize Copilot or another provider, choose the chat provider, and give users access. Every step can be skipped and repeated later from Bifrost Language Models Setup.', Comment = 'is-IS=Bifröst spjall gerir þér kleift að vinna í Business Central með mállíkani. Virkjaðu HTTP, frumstilltu Copilot eða annan veitanda, veldu spjallveitanda og veittu notendum aðgang. Sleppa má hverju skrefi og endurtaka síðar í uppsetningu Bifröst mállíkana.';
            }
            group(Http)
            {
                Visible = CurrentStep = 2;
                Caption = 'HTTP for this app', Comment = 'is-IS=HTTP fyrir þetta forrit';
                InstructionalText = 'Copilot itself does not need this setting. Other language model providers and the MCP tool server need Allow HttpClient Requests for Bifrost Language Models.', Comment = 'is-IS=Copilot sjálft þarf ekki þessa stillingu. Aðrir mállíkanaveitendur og MCP-verkfæraþjónninn þurfa Leyfa HttpClient-beiðnir fyrir Bifröst mállíkön.';
                field(HttpEnabled; HttpEnabled)
                {
                    Caption = 'HTTP enabled', Comment = 'is-IS=HTTP virkt';
                    ToolTip = 'Shows whether this app may send HTTP requests.', Comment = 'is-IS=Sýnir hvort þetta forrit megi senda HTTP-beiðnir.';
                    Editable = false;
                }
                group(HttpPermissionNote)
                {
                    ShowCaption = false;
                    Visible = not CanWriteAppSetting;
                    InstructionalText = 'You do not have permission to change extension settings. Ask an administrator with the SUPER permission set (or write permission on table NAV App Setting) to enable Allow HttpClient Requests for the applications listed above.', Comment = 'is-IS=Þú hefur ekki heimild til að breyta stillingum viðbóta. Biddu kerfisstjóra sem hefur SUPER heimildasamstæðuna (eða skrifheimild á töfluna NAV App Setting) um að virkja Leyfa HttpClient-beiðnir fyrir forritin hér að ofan.';
                }
            }
            group(LanguageModel)
            {
                Visible = CurrentStep = 3;
                Caption = 'Language model', Comment = 'is-IS=Mállíkan';
                field(ProviderChoice; ProviderChoice)
                {
                    Caption = 'Provider', Comment = 'is-IS=Veitandi';
                    ToolTip = 'Choose Copilot or configure another provider.', Comment = 'is-IS=Veldu Copilot eða stilltu annan veitanda.';
                    OptionCaption = 'Copilot (recommended),Another provider', Comment = 'is-IS=Copilot (mælt með),Annar veitandi';
                    trigger OnValidate()
                    begin
                        RefreshStatus();
                    end;
                }
                group(CopilotHelp)
                {
                    Visible = ProviderChoice = ProviderChoice::Copilot;
                    Caption = 'Copilot', Comment = 'is-IS=Copilot';
                    InstructionalText = 'Open Copilot & agent capabilities and make sure Bifrost Copilot is active. If the environment requires it, allow data movement to the Azure OpenAI geography. Copilot usage is billed by Microsoft. Choose Initialize Copilot to create or update the COPILOT model and its default skill.', Comment = 'is-IS=Opnaðu Copilot og getu virkja og gakktu úr skugga um að Bifröst Copilot sé virkt. Ef umhverfið krefst þess skaltu leyfa gagnaflutning á landsvæði Azure OpenAI. Microsoft innheimtir fyrir Copilot-notkun. Veldu Frumstilla Copilot til að búa til eða uppfæra COPILOT-mállíkanið og sjálfgefið hæfniefni þess.';
                field(CopilotRegistered; CopilotRegistered)
                {
                    Caption = 'Capability registered', Comment = 'is-IS=Geta skráð';
                    ToolTip = 'Shows whether Bifrost Copilot is registered.', Comment = 'is-IS=Sýnir hvort Bifröst Copilot sé skráð.';
                    Editable = false;
                }
                field(CopilotStatus; CopilotStatus)
                {
                    Caption = 'Capability status', Comment = 'is-IS=Staða getu';
                    ToolTip = 'Shows whether Bifrost Copilot is active. If not, open Copilot and agent capabilities.', Comment = 'is-IS=Sýnir hvort Bifröst Copilot sé virkt. Ef ekki skaltu opna Copilot og getu virkja.';
                    Editable = false;
                }
                field(CopilotModelExists; CopilotModelExists)
                {
                    Caption = 'COPILOT model exists', Comment = 'is-IS=COPILOT-mállíkan til';
                    ToolTip = 'Shows whether the COPILOT language model has been initialized.', Comment = 'is-IS=Sýnir hvort COPILOT-mállíkanið hafi verið frumstillt.';
                    Editable = false;
                }
                }
                group(OtherProviders)
                {
                    ShowCaption = false;
                    Visible = ProviderChoice = ProviderChoice::Other;
                field(AvailableModels; AvailableModels)
                {
                    Caption = 'Existing models and API keys', Comment = 'is-IS=Fyrirliggjandi mállíkön og API-lyklar';
                    ToolTip = 'Lists each model, its provider, and whether a shared or personal API key is set for you.', Comment = 'is-IS=Sýnir hvert mállíkan, veitanda þess og hvort sameiginlegur eða persónulegur API-lykill hafi verið skráður fyrir þig.';
                    Editable = false;
                    MultiLine = true;
                }
                }
                field(DefaultModel; DefaultModel)
                {
                    Caption = 'Default Language Model', Comment = 'is-IS=Sjálfgefið mállíkan';
                    ToolTip = 'Choose the default model for requests without a model. Chat users also need a per-user model.', Comment = 'is-IS=Veldu sjálfgefið mállíkan fyrir beiðnir án mállíkans. Spjallnotendur þurfa einnig eigið mállíkan.';
                    Lookup = true;
                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupModel(Text));
                    end;

                    trigger OnValidate()
                    begin
                        WizardMgt.SetDefaultModel(DefaultModel);
                        RefreshStatus();
                    end;
                }
            }
            group(ChatProvider)
            {
                Visible = CurrentStep = 4;
                Caption = 'Chat provider', Comment = 'is-IS=Spjallveitandi';
                InstructionalText = 'This wizard never overrides another chat provider. If another app holds it, an administrator can change the provider on Bifrost Setup.', Comment = 'is-IS=Þessi leiðsögn yfirskrifar aldrei annan spjallveitanda. Ef annað forrit er skráð getur stjórnandi breytt veitandanum í Bifröst uppsetningu.';
                field(CurrentProvider; CurrentProvider)
                {
                    Caption = 'Current chat provider', Comment = 'is-IS=Núverandi spjallveitandi';
                    ToolTip = 'Shows which provider currently owns Bifrost Chat.', Comment = 'is-IS=Sýnir hvaða veitandi er nú skráður fyrir Bifröst spjall.';
                    Editable = false;
                }
            }
            group(Users)
            {
                Visible = CurrentStep = 5;
                Caption = 'Users', Comment = 'is-IS=Notendur';
                InstructionalText = 'Select enabled users, give them both chat permission sets, and choose their language model. Changes take effect at the next sign-in or session refresh.', Comment = 'is-IS=Veldu virka notendur, veittu þeim báðar spjallheimildasamstæðurnar og veldu mállíkan þeirra. Breytingar taka gildi við næstu innskráningu eða endurnýjun setu.';
                field(SelectedModel; SelectedModel)
                {
                    Caption = 'Language model for selected users', Comment = 'is-IS=Mállíkan fyrir valda notendur';
                    ToolTip = 'Choose the model to assign with Set language model for selected users.', Comment = 'is-IS=Veldu mállíkanið sem á að úthluta með Setja mállíkan fyrir valda notendur.';
                    Lookup = true;
                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupModel(Text));
                    end;

                }
                group(UserPermissionNote)
                {
                    ShowCaption = false;
                    Visible = not CanAssignPermissions;
                    InstructionalText = 'An administrator with SUPER or SECURITY can give chat access. The BIFROST Chat ori and BIFROST LLM Chat ori sets can also be assigned through an Entra security group.', Comment = 'is-IS=Stjórnandi með SUPER eða SECURITY getur veitt spjallaðgang. Einnig má úthluta BIFROST Chat ori og BIFROST LLM Chat ori með Entra-öryggishópi.';
                }
                part(ChatUsers; "LangModel Wizard Users ori")
                {
                    ApplicationArea = All;
                }
            }
            group(Finish)
            {
                Visible = CurrentStep = 6;
                Caption = 'Finish setup', Comment = 'is-IS=Ljúka uppsetningu';
                InstructionalText = 'Open a supported Business Central page, such as Customers, and choose Chat via Bifrost in the FactBox. Chat users need both chat sets and a language model. You can return to this wizard from Bifrost Language Models Setup.', Comment = 'is-IS=Opnaðu studda Business Central síðu, svo sem Viðskiptamenn, og veldu Spjall með Bifröst í upplýsingareitnum. Spjallnotendur þurfa báðar spjallheimildasamstæðurnar og mállíkan. Þú getur opnað þessa leiðsögn aftur í uppsetningu Bifröst mállíkana.';
                field(HttpSummary; HttpSummary)
                {
                    Caption = 'HTTP', Comment = 'is-IS=HTTP';
                    ToolTip = 'Shows whether the step is done, skipped, or needs an administrator.', Comment = 'is-IS=Sýnir hvort skrefi sé lokið, sleppt eða þurfi stjórnanda.';
                    Editable = false;
                }
                field(ModelSummary; ModelSummary)
                {
                    Caption = 'Language model', Comment = 'is-IS=Mállíkan';
                    ToolTip = 'Shows whether the step is done, skipped, or needs an administrator.', Comment = 'is-IS=Sýnir hvort skrefi sé lokið, sleppt eða þurfi stjórnanda.';
                    Editable = false;
                }
                field(ProviderSummary; ProviderSummary)
                {
                    Caption = 'Chat provider', Comment = 'is-IS=Spjallveitandi';
                    ToolTip = 'Shows whether the step is done, skipped, or needs an administrator.', Comment = 'is-IS=Sýnir hvort skrefi sé lokið, sleppt eða þurfi stjórnanda.';
                    Editable = false;
                }
                field(UsersSummary; UsersSummary)
                {
                    Caption = 'Users', Comment = 'is-IS=Notendur';
                    ToolTip = 'Shows whether the step is done, skipped, or needs an administrator.', Comment = 'is-IS=Sýnir hvort skrefi sé lokið, sleppt eða þurfi stjórnanda.';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Back)
            {
                Caption = 'Back', Comment = 'is-IS=Til baka';
                ToolTip = 'Back.', Comment = 'is-IS=Til baka.';
                Image = PreviousRecord;
                InFooterBar = true;
                Visible = CurrentStep > 1;

                trigger OnAction()
                begin
                    CurrentStep -= 1;
                    RefreshStatus();
                end;
            }
            action(Next)
            {
                Caption = 'Next', Comment = 'is-IS=Áfram';
                ToolTip = 'Next.', Comment = 'is-IS=Áfram.';
                Image = NextRecord;
                InFooterBar = true;
                Visible = CurrentStep < 6;

                trigger OnAction()
                begin
                    CurrentStep += 1;
                    RefreshStatus();
                end;
            }
            action(FinishSetup)
            {
                Caption = 'Finish', Comment = 'is-IS=Ljúka';
                ToolTip = 'Finish.', Comment = 'is-IS=Ljúka.';
                Image = Approve;
                InFooterBar = true;
                Visible = CurrentStep = 6;

                trigger OnAction()
                begin
                    WizardMgt.Finish();
                    CurrPage.Close();
                end;
            }
            action(EnableHttp)
            {
                Caption = 'Enable HTTP Client Requests', Comment = 'is-IS=Virkja HTTP-biðlarabeiðnir';
                ToolTip = 'Enable HTTP Client Requests.', Comment = 'is-IS=Virkja HTTP-biðlarabeiðnir.';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 2) and CanWriteAppSetting and not HttpEnabled;

                trigger OnAction()
                begin
                    WizardMgt.EnableHttp();
                    RefreshStatus();
                end;
            }
            action(ExtensionSettings)
            {
                Caption = 'Open Extension Settings', Comment = 'is-IS=Opna stillingar viðbótar';
                ToolTip = 'Open Extension Settings.', Comment = 'is-IS=Opna stillingar viðbótar.';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 2) and not CanWriteAppSetting;

                trigger OnAction()
                begin
                    Hyperlink(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, 2500));
                end;
            }
            action(Verify)
            {
                Caption = 'Verify', Comment = 'is-IS=Staðfesta';
                ToolTip = 'Verify.', Comment = 'is-IS=Staðfesta.';
                Image = Refresh;
                InFooterBar = true;
                Visible = (CurrentStep > 1) and (CurrentStep < 6);

                trigger OnAction()
                begin
                    RefreshStatus();
                end;
            }
            action(InitializeCopilot)
            {
                Caption = 'Initialize Copilot', Comment = 'is-IS=Frumstilla Copilot';
                ToolTip = 'Initialize Copilot.', Comment = 'is-IS=Frumstilla Copilot.';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 3) and (ProviderChoice = ProviderChoice::Copilot);

                trigger OnAction()
                begin
                    if WizardMgt.InitializeCopilot() then
                        RefreshStatus();
                end;
            }
            action(CopilotCapabilities)
            {
                Caption = 'Open Copilot & agent capabilities', Comment = 'is-IS=Opna Copilot og getu virkja';
                ToolTip = 'Open Copilot & agent capabilities.', Comment = 'is-IS=Opna Copilot og getu virkja.';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 3) and (ProviderChoice = ProviderChoice::Copilot);

                trigger OnAction()
                begin
                    Page.RunModal(Page::"Copilot AI Capabilities");
                    RefreshStatus();
                end;
            }
            action(Help)
            {
                Caption = 'Language Models help', Comment = 'is-IS=Hjálp fyrir mállíkön';
                ToolTip = 'Language Models help.', Comment = 'is-IS=Hjálp fyrir mállíkön.';
                Image = Help;
                InFooterBar = true;
                Visible = CurrentStep = 3;

                trigger OnAction()
                begin
                    Hyperlink('https://docs.bifrost.origo.is/' + HelpLanguage() + '/language-models/');
                end;
            }
            action(LanguageModels)
            {
                Caption = 'Open Language Models', Comment = 'is-IS=Opna mállíkön';
                ToolTip = 'Open Language Models.', Comment = 'is-IS=Opna mállíkön.';
                Image = Setup;
                InFooterBar = true;
                Visible = CurrentStep = 3;

                trigger OnAction()
                begin
                    Page.RunModal(Page::"Bifrost LangModel List ori");
                    RefreshStatus();
                end;
            }
            action(ApiKeys)
            {
                Caption = 'API Keys', Comment = 'is-IS=API-lyklar';
                ToolTip = 'API Keys.', Comment = 'is-IS=API-lyklar.';
                Image = Setup;
                InFooterBar = true;
                Visible = CurrentStep = 3;

                trigger OnAction()
                begin
                    OpenApiKeys();
                    RefreshStatus();
                end;
            }
            action(ClaimProvider)
            {
                Caption = 'Use Bifrost Language Models for chat', Comment = 'is-IS=Nota Bifröst mállíkön fyrir spjall';
                ToolTip = 'Use Bifrost Language Models for chat.', Comment = 'is-IS=Nota Bifröst mállíkön fyrir spjall.';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 4) and (CurrentProvider = CurrentProvider::None);

                trigger OnAction()
                begin
                    if WizardMgt.ClaimChatProvider() then
                        RefreshStatus();
                end;
            }
            action(BifrostSetup)
            {
                Caption = 'Open Bifrost Setup', Comment = 'is-IS=Opna Bifröst uppsetningu';
                ToolTip = 'Open Bifrost Setup.', Comment = 'is-IS=Opna Bifröst uppsetningu.';
                Image = Setup;
                InFooterBar = true;
                Visible = CurrentStep = 4;

                trigger OnAction()
                begin
                    Page.RunModal(Page::"Setup ori");
                    RefreshStatus();
                end;
            }
            action(GiveChatAccess)
            {
                Caption = 'Give chat access to selected users', Comment = 'is-IS=Veita völdum notendum spjallaðgang';
                ToolTip = 'Give chat access to selected users.', Comment = 'is-IS=Veita völdum notendum spjallaðgang.';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 5) and CanAssignPermissions;

                trigger OnAction()
                begin
                    ApplyToSelectedUsers(true);
                end;
            }
            action(SetUserModel)
            {
                Caption = 'Set language model for selected users', Comment = 'is-IS=Setja mállíkan fyrir valda notendur';
                ToolTip = 'Set language model for selected users.', Comment = 'is-IS=Setja mállíkan fyrir valda notendur.';
                Image = Setup;
                InFooterBar = true;
                Visible = CurrentStep = 5;

                trigger OnAction()
                begin
                    ApplyToSelectedUsers(false);
                end;
            }
        }
    }

    var
        WizardMgt: Codeunit "LangModel Wizard Mgt ori";
        CurrentStep: Integer;
        ProviderChoice: Option Copilot,Other;
        CurrentProvider: Enum "Chat Provider Type ori";
        DefaultModel: Code[20];
        SelectedModel: Code[20];
        HttpEnabled: Boolean;
        CanWriteAppSetting: Boolean;
        CanAssignPermissions: Boolean;
        CopilotRegistered: Boolean;
        CopilotActive: Boolean;
        CopilotStatus: Text;
        CopilotModelExists: Boolean;
        UsersUpdated: Boolean;
        AvailableModels: Text;
        HttpSummary: Text;
        ModelSummary: Text;
        ProviderSummary: Text;
        UsersSummary: Text;
        CopilotActiveTxt: Label 'Active', Comment = 'is-IS=Virkt';
        CopilotInactiveTxt: Label 'Not active — open Copilot & agent capabilities to activate Bifrost Copilot.', Comment = 'is-IS=Ekki virkt — opnaðu Copilot og getu virkja til að virkja Bifröst Copilot.';
        CopilotUnregisteredTxt: Label 'Not registered — choose Initialize Copilot.', Comment = 'is-IS=Ekki skráð — veldu Frumstilla Copilot.';
        DoneTxt: Label 'Done', Comment = 'is-IS=Lokið';
        SkippedTxt: Label 'Skipped', Comment = 'is-IS=Sleppt';
        AdministratorTxt: Label 'Needs an administrator', Comment = 'is-IS=Þarf stjórnanda';
        ModelLineTxt: Label '%1 — %2 — API key: %3', Comment = '%1 = model, %2 = provider, %3 = key status, is-IS=%1 — %2 — API-lykill: %3';
        KeySetTxt: Label 'Set', Comment = 'is-IS=Skráður';
        KeyMissingTxt: Label 'Missing', Comment = 'is-IS=Vantar';
        KeyNotRequiredTxt: Label 'Not required', Comment = 'is-IS=Ekki krafist';

    trigger OnOpenPage()
    begin
        CurrentStep := 1;
        RefreshStatus();
    end;

    local procedure RefreshStatus()
    var
        Model: Record "Bifrost Language Model ori";
    begin
        HttpEnabled := WizardMgt.IsHttpEnabled();
        CanWriteAppSetting := WizardMgt.CanEnableHttp();
        CanAssignPermissions := WizardMgt.CanAssignChatAccess();
        WizardMgt.GetCopilotStatus(CopilotRegistered, CopilotActive);
        CopilotStatus := CopilotUnregisteredTxt;
        if CopilotRegistered then
            if CopilotActive then
                CopilotStatus := CopilotActiveTxt
            else
                CopilotStatus := CopilotInactiveTxt;
        CopilotModelExists := Model.Get('COPILOT');
        CurrentProvider := WizardMgt.GetChatProvider();
        DefaultModel := WizardMgt.GetDefaultModel();
        HttpSummary := StepSummary(HttpEnabled, CanWriteAppSetting);
        ModelSummary := StepSummary(DefaultModel <> '', true);
        ProviderSummary := StepSummary(CurrentProvider = CurrentProvider::LanguageModels, CurrentProvider = CurrentProvider::None);
        UsersSummary := StepSummary(UsersUpdated, CanAssignPermissions);
        RefreshModels();
        CurrPage.Update(false);
    end;

    local procedure StepSummary(Done: Boolean; CanConfigure: Boolean): Text
    begin
        if Done then
            exit(DoneTxt);
        if not CanConfigure then
            exit(AdministratorTxt);
        exit(SkippedTxt);
    end;

    local procedure RefreshModels()
    var
        Model: Record "Bifrost Language Model ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Secrets: Codeunit "LangModel Secrets ori";
        Provider: Interface "Bifrost LangModel Provider ori";
        KeyStatus: Text;
    begin
        AvailableModels := '';
        Model.SetLoadFields(Code, "Chat Provider");
        if Model.FindSet() then
            repeat
                KeyStatus := KeyMissingTxt;
                Provider := Model."Chat Provider";
                TempArgument.Init();
                TempArgument."Procedure Type" := TempArgument."Procedure Type"::RequiresApiKey;
                TempArgument."Result Boolean" := false;
                Provider.Execute(TempArgument);
                if not TempArgument."Result Boolean" then
                    KeyStatus := KeyNotRequiredTxt
                else
                    if Secrets.HasServiceKey(Model.Code) or Secrets.HasUserKey(Model.Code) then
                        KeyStatus := KeySetTxt;
                if AvailableModels <> '' then
                    AvailableModels += '\';
                AvailableModels += StrSubstNo(ModelLineTxt, Model.Code, Model."Chat Provider", KeyStatus);
            until Model.Next() = 0;
    end;

    local procedure ApplyToSelectedUsers(GiveAccess: Boolean)
    begin
        CurrPage.ChatUsers.Page.ApplyToSelectedUsers(GiveAccess, SelectedModel);
        UsersUpdated := true;
        RefreshStatus();
    end;

    local procedure OpenApiKeys()
    var
        Secrets: Codeunit "LangModel Secrets ori";
        SecretsPage: Page "App Secrets ori";
    begin
        Secrets.RegisterAll();
        SecretsPage.SetAppFilter(Secrets.GetAppId());
        SecretsPage.RunModal();
    end;

    local procedure LookupModel(var ModelCode: Text): Boolean
    var
        Model: Record "Bifrost Language Model ori";
        ModelList: Page "Bifrost LangModel List ori";
    begin
        ModelList.LookupMode(true);
        if ModelList.RunModal() <> Action::LookupOK then
            exit(false);
        ModelList.GetRecord(Model);
        ModelCode := Model.Code;
        exit(true);
    end;

    local procedure HelpLanguage(): Text
    begin
        if GlobalLanguage() = 1039 then
            exit('is-is');
        exit('en-us');
    end;
}
