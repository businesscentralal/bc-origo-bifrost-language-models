namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Setup page of Bifrost Language Models, opened from the Apps group on the Bifrost Setup page.
/// It shows the state of the language models, of the MCP tool server and of the API keys
/// Bifrost Language Models keeps in the Bifrost Foundation secret store.
/// Setup notifications - including the one about blocked HttpClient requests - are raised by
/// Bifrost Foundation on the Bifrost Setup page, never here.
/// </summary>
page 10035421 "LangModel Setup ori"
{
    Caption = 'Bifrost Language Models Setup', Comment = 'is-IS=Uppsetning Bifröst mállíkana';
    ContextSensitiveHelpPage = 'language-models-setup';
    PageType = Card;
    Extensible = false;
    ApplicationArea = All;
    UsageCategory = None;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(LanguageModels)
            {
                Caption = 'Language Models', Comment = 'is-IS=Mállíkön';
                InstructionalText = 'A language model connects Chat via Bifrost to a provider - Copilot, OpenAI, Azure OpenAI, a custom LLM, Anthropic, xAI or Google Gemini - and carries the skill content injected into every chat.', Comment = 'is-IS=Mállíkan tengir Spjall með Bifröst við veitanda - Copilot, OpenAI, Azure OpenAI, sérsniðið LLM, Anthropic, xAI eða Google Gemini - og ber hæfniefnið sem er sett inn í hvert spjall.';

                field(LanguageModelCount; LanguageModelCount)
                {
                    Editable = false;
                    Caption = 'Language Models', Comment = 'is-IS=Mállíkön';
                    ToolTip = 'Specifies how many language models are set up in this company.', Comment = 'is-IS=Tilgreinir hversu mörg mállíkön eru sett upp í þessu fyrirtæki.';
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"Bifrost LangModel List ori");
                    end;
                }
                field(DefaultLanguageModel; DefaultLanguageModelCode)
                {
                    Editable = false;
                    Caption = 'Default Language Model', Comment = 'is-IS=Sjálfgefið mállíkan';
                    ToolTip = 'Used by LLM.Prompt.Complete when neither a role code nor a user language model is given. Not used by Bifrost Chat.', Comment = 'is-IS=Notað af LLM.Prompt.Complete þegar hvorki hlutverkskóði né mállíkan notanda er gefið. Ekki notað af Bifröst spjalli.';
                }
            }
            group(ToolServer)
            {
                Caption = 'MCP Tool Server', Comment = 'is-IS=MCP-verkfæraþjónn';
                InstructionalText = 'Chat via Bifrost exposes the Bifrost message types to the language model as Model Context Protocol tools, so the model can read and write Business Central data on your behalf.', Comment = 'is-IS=Spjall með Bifröst birtir mállíkaninu skilaboðategundir Bifröst sem verkfæri (Model Context Protocol), svo líkanið geti lesið og skrifað gögn í Business Central fyrir þína hönd.';

                field(ToolCount; ToolCount)
                {
                    Editable = false;
                    Caption = 'Available Tools', Comment = 'is-IS=Tiltæk verkfæri';
                    ToolTip = 'Specifies how many Model Context Protocol tools the chat can call in this company.', Comment = 'is-IS=Tilgreinir hversu mörg verkfæri (Model Context Protocol) spjallið getur kallað á í þessu fyrirtæki.';
                }
            }
            group(AskLimits)
            {
                Caption = 'LLM.Prompt.Ask Limits', Comment = 'is-IS=Mörk LLM.Prompt.Ask';
                InstructionalText = 'The caps bound every LLM.Prompt.Ask run in this company: a request limit above a cap is cut to the cap with a clamped warning. The defaults are used when a request sends no limit. Every tool call is still a Bifrost message that counts against the monthly quota, and the tools stay read-only.', Comment = 'is-IS=Hámörkin takmarka hverja LLM.Prompt.Ask keyrslu í þessu fyrirtæki: mörk í beiðni sem eru hærri en hámark eru lækkuð í hámarkið með clamped viðvörun. Sjálfgefnu gildin eru notuð þegar beiðni sendir engin mörk. Hvert verkfærakall er áfram Bifröst skilaboð sem telst til mánaðarlegs kvóta og verkfærin eru áfram aðeins til lestrar.';

                field(AskMaxToolCallsCap; AskSetup."Ask Max Tool Calls Cap")
                {
                    Caption = 'Ask Max Tool Calls Cap', Comment = 'is-IS=Hámark verkfærakalla í spurningu';
                    ToolTip = 'Specifies the most tool calls one LLM.Prompt.Ask request may use, from 1 to 999. A higher limits.maxToolCalls is cut to this value with a clamped:maxToolCalls warning.', Comment = 'is-IS=Tilgreinir flest verkfærakköll sem ein LLM.Prompt.Ask beiðni má nota, frá 1 til 999. Hærra limits.maxToolCalls er lækkað í þetta gildi með viðvöruninni clamped:maxToolCalls.';
                    Editable = AskSetupEditable;

                    trigger OnValidate()
                    begin
                        ApplyAskValue(AskSetup.FieldNo("Ask Max Tool Calls Cap"), AskSetup."Ask Max Tool Calls Cap");
                    end;
                }
                field(AskDefaultToolCalls; AskSetup."Ask Default Tool Calls")
                {
                    Caption = 'Ask Default Tool Calls', Comment = 'is-IS=Sjálfgefin verkfærakköll í spurningu';
                    ToolTip = 'Specifies the tool calls an LLM.Prompt.Ask request may use when it sends no limits.maxToolCalls. It cannot be above Ask Max Tool Calls Cap.', Comment = 'is-IS=Tilgreinir verkfærakköllin sem LLM.Prompt.Ask beiðni má nota þegar hún sendir ekkert limits.maxToolCalls. Það má ekki vera hærra en Hámark verkfærakalla í spurningu.';
                    Editable = AskSetupEditable;

                    trigger OnValidate()
                    begin
                        ApplyAskValue(AskSetup.FieldNo("Ask Default Tool Calls"), AskSetup."Ask Default Tool Calls");
                    end;
                }
                field(AskMaxRoundsCap; AskSetup."Ask Max Rounds Cap")
                {
                    Caption = 'Ask Max Rounds Cap', Comment = 'is-IS=Hámark umferða í spurningu';
                    ToolTip = 'Specifies the most provider requests (rounds) one LLM.Prompt.Ask request may use, from 1 to 999. A higher limits.maxRounds is cut to this value with a clamped:maxRounds warning.', Comment = 'is-IS=Tilgreinir flestar beiðnir til veitanda (umferðir) sem ein LLM.Prompt.Ask beiðni má nota, frá 1 til 999. Hærra limits.maxRounds er lækkað í þetta gildi með viðvöruninni clamped:maxRounds.';
                    Editable = AskSetupEditable;

                    trigger OnValidate()
                    begin
                        ApplyAskValue(AskSetup.FieldNo("Ask Max Rounds Cap"), AskSetup."Ask Max Rounds Cap");
                    end;
                }
                field(AskDefaultRounds; AskSetup."Ask Default Rounds")
                {
                    Caption = 'Ask Default Rounds', Comment = 'is-IS=Sjálfgefnar umferðir í spurningu';
                    ToolTip = 'Specifies the provider requests (rounds) an LLM.Prompt.Ask request may use when it sends no limits.maxRounds. It cannot be above Ask Max Rounds Cap.', Comment = 'is-IS=Tilgreinir beiðnir til veitanda (umferðir) sem LLM.Prompt.Ask beiðni má nota þegar hún sendir ekkert limits.maxRounds. Það má ekki vera hærra en Hámark umferða í spurningu.';
                    Editable = AskSetupEditable;

                    trigger OnValidate()
                    begin
                        ApplyAskValue(AskSetup.FieldNo("Ask Default Rounds"), AskSetup."Ask Default Rounds");
                    end;
                }
                field(AskMaxResultCharsCap; AskSetup."Ask Max Result Chars Cap")
                {
                    Caption = 'Ask Max Result Chars Cap', Comment = 'is-IS=Hámark stafa í verkfæraniðurstöðu';
                    ToolTip = 'Specifies the most characters of one tool result that LLM.Prompt.Ask sends to the model, 1 or more. A higher limits.maxResultChars is cut to this value with a clamped:maxResultChars warning.', Comment = 'is-IS=Tilgreinir flesta stafi einnar verkfæraniðurstöðu sem LLM.Prompt.Ask sendir líkaninu, 1 eða fleiri. Hærra limits.maxResultChars er lækkað í þetta gildi með viðvöruninni clamped:maxResultChars.';
                    Editable = AskSetupEditable;

                    trigger OnValidate()
                    begin
                        ApplyAskValue(AskSetup.FieldNo("Ask Max Result Chars Cap"), AskSetup."Ask Max Result Chars Cap");
                    end;
                }
                field(AskDefaultResultChars; AskSetup."Ask Default Result Chars")
                {
                    Caption = 'Ask Default Result Chars', Comment = 'is-IS=Sjálfgefnir stafir í verkfæraniðurstöðu';
                    ToolTip = 'Specifies the characters of one tool result LLM.Prompt.Ask sends to the model when the request sends no limits.maxResultChars. It cannot be above Ask Max Result Chars Cap.', Comment = 'is-IS=Tilgreinir stafi einnar verkfæraniðurstöðu sem LLM.Prompt.Ask sendir líkaninu þegar beiðnin sendir ekkert limits.maxResultChars. Það má ekki vera hærra en Hámark stafa í verkfæraniðurstöðu.';
                    Editable = AskSetupEditable;

                    trigger OnValidate()
                    begin
                        ApplyAskValue(AskSetup.FieldNo("Ask Default Result Chars"), AskSetup."Ask Default Result Chars");
                    end;
                }
            }
            group(Secrets)
            {
                Caption = 'API Keys', Comment = 'is-IS=API-lyklar';
                InstructionalText = 'Bifrost Language Models keeps every provider API key in the Bifrost secret store. Each language model has a shared key for the whole company and a personal key per user.', Comment = 'is-IS=Bifröst mállíkön geyma alla API-lykla veitenda í leyndarmálageymslu Bifröst. Hvert mállíkan hefur sameiginlegan lykil fyrir allt fyrirtækið og persónulegan lykil fyrir hvern notanda.';

                field(ModelsWithoutKey; ModelsWithoutKeyCount)
                {
                    Editable = false;
                    Caption = 'Language Models Without a Key', Comment = 'is-IS=Mállíkön án lykils';
                    ToolTip = 'Specifies how many language models need an API key but have neither a shared key nor a personal key stored for you.', Comment = 'is-IS=Tilgreinir hversu mörg mállíkön þurfa API-lykil en hafa hvorki sameiginlegan lykil né persónulegan lykil geymdan fyrir þig.';
                    StyleExpr = MissingKeyStyleExpr;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"Bifrost LangModel List ori");
                    end;
                }
                field(KeyHint; KeyHintText)
                {
                    Editable = false;
                    Caption = 'Note', Comment = 'is-IS=Athugasemd';
                    ToolTip = 'Specifies what to do about the API keys that are still missing.', Comment = 'is-IS=Tilgreinir hvað eigi að gera við API-lyklana sem vantar enn.';
                    MultiLine = true;
                    Visible = KeyHintVisible;
                    StyleExpr = MissingKeyStyleExpr;
                    ShowCaption = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LanguageModelList)
            {
                ApplicationArea = All;
                Caption = 'Language Models', Comment = 'is-IS=Mállíkön';
                ToolTip = 'Manage the language models with the skill content injected into Chat via Bifrost.', Comment = 'is-IS=Stjórna mállíkönum með hæfniefni sem er sett inn í Spjall með Bifröst.';
                Image = Permission;
                RunObject = page "Bifrost LangModel List ori";
            }
            action(AppSecrets)
            {
                ApplicationArea = All;
                Caption = 'API Keys', Comment = 'is-IS=API-lyklar';
                ToolTip = 'Show the API keys Bifrost Language Models has registered in the Bifrost secret store and whether a value has been entered.', Comment = 'is-IS=Sýna API-lyklana sem Bifröst mállíkön hafa skráð í leyndarmálageymslu Bifröst og hvort gildi hafi verið skráð.';
                Image = EncryptionKeys;

                trigger OnAction()
                var
                    LangModelSecrets: Codeunit "LangModel Secrets ori";
                    AppSecretsPage: Page "App Secrets ori";
                begin
                    LangModelSecrets.RegisterAll();
                    AppSecretsPage.SetAppFilter(LangModelSecrets.GetAppId());
                    AppSecretsPage.Run();
                end;
            }
            action(SetupWizard)
            {
                ApplicationArea = All;
                Caption = 'Setup Wizard', Comment = 'is-IS=Uppsetningarleiðsögn';
                ToolTip = 'Set up HTTP, a language model, the chat provider, and chat users.', Comment = 'is-IS=Setja upp HTTP, mállíkan, spjallveitanda og spjallnotendur.';
                Image = Setup;
                RunObject = page "LangModel Setup Wizard ori";
            }
            action(BifrostSetupWizard)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Setup Wizard', Comment = 'is-IS=Uppsetningarleiðsögn Bifröst';
                ToolTip = 'Open the general Bifrost setup wizard.', Comment = 'is-IS=Opna almenna uppsetningarleiðsögn Bifröst.';
                Image = Setup;
                RunObject = page "Setup Wizard ori";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process', Comment = 'is-IS=Vinnsla';

                actionref(LanguageModelList_Promoted; LanguageModelList) { }
                actionref(AppSecrets_Promoted; AppSecrets) { }
                actionref(SetupWizard_Promoted; SetupWizard) { }
                actionref(BifrostSetupWizard_Promoted; BifrostSetupWizard) { }
            }
        }
    }

    var
        AskSetup: Record "LangModel Ask Setup ori";
        DefaultLanguageModelCode: Text[50];
        KeyHintText: Text;
        MissingKeyStyleExpr: Text;
        LanguageModelCount: Integer;
        ToolCount: Integer;
        ModelsWithoutKeyCount: Integer;
        KeyHintVisible: Boolean;
        AskSetupEditable: Boolean;
        UnfavorableStyleTok: Label 'Unfavorable', Locked = true;
        FavorableStyleTok: Label 'Favorable', Locked = true;
        KeyMissingHintTxt: Label 'API keys cannot be moved from another extension. Open a language model and use Set Personal API Key or Set Shared API Key to enter each key once.', Comment = 'is-IS=Ekki er hægt að flytja API-lykla frá annarri viðbót. Opnaðu mállíkan og notaðu Setja inn persónulegan API-lykil eða Setja inn sameiginlegan API-lykil til að slá hvern lykil inn einu sinni.';
        NoDefaultLanguageModelTxt: Label '(none)', Comment = 'is-IS=(ekkert)';

    trigger OnOpenPage()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        LangModelSecrets.RegisterAll();
        RefreshStatus();
        AskSetup.GetSetup();
        AskSetupEditable := AskSetup.WritePermission();
    end;

    /// <summary>
    /// Validates one Ask cap or default against the stored row and writes it; inserts the row on the first change. On a
    /// refusal the page keeps the stored values. Needs write permission on "LangModel Ask Setup ori", which only the
    /// language-model admin sets grant.
    /// </summary>
    local procedure ApplyAskValue(FieldNo: Integer; NewValue: Integer)
    var
        StoredAskSetup: Record "LangModel Ask Setup ori";
    begin
        AskSetup.GetSetup();
        StoredAskSetup.SetValue(AskSetup, FieldNo, NewValue);
        AskSetup := StoredAskSetup;
    end;

    local procedure RefreshStatus()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        MCPServer: Codeunit "MCP Tool Server ori";
    begin
        LangModel.ReadIsolation := IsolationLevel::ReadUncommitted;
        LangModel.SetLoadFields(Code, Default);
        LanguageModelCount := LangModel.Count();

        DefaultLanguageModelCode := '';
        LangModel.SetRange(Default, true);
        if LangModel.FindFirst() then
            DefaultLanguageModelCode := CopyStr(LangModel.Code, 1, MaxStrLen(DefaultLanguageModelCode));
        LangModel.SetRange(Default);

        ToolCount := MCPServer.GetToolCount();
        ModelsWithoutKeyCount := LangModelSecrets.CountModelsWithoutKey();

        KeyHintVisible := ModelsWithoutKeyCount > 0;
        if KeyHintVisible then begin
            KeyHintText := KeyMissingHintTxt;
            MissingKeyStyleExpr := UnfavorableStyleTok;
        end else begin
            KeyHintText := '';
            MissingKeyStyleExpr := FavorableStyleTok;
        end;

        if DefaultLanguageModelCode = '' then
            DefaultLanguageModelCode := CopyStr(NoDefaultLanguageModelTxt, 1, MaxStrLen(DefaultLanguageModelCode));
    end;
}
