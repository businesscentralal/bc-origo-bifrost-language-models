namespace Origo.Bifrost.LanguageModels;

using System.Security.AccessControl;

/// <summary>Displays enabled users and company-scoped chat configuration, with multi-selection for wizard commands.</summary>
page 10035428 "LangModel Wizard Users ori"
{
    PageType = ListPart;
    SourceTable = User;
    SourceTableView = where(State = const(Enabled));
    Extensible = false;
    ApplicationArea = All;
    ContextSensitiveHelpPage = 'language-models-setup';
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    Editable = false;
    Caption = 'Chat users', Comment = 'is-IS=Spjallnotendur';
    layout
    {
        area(Content)
        {
                repeater(EnabledUsers)
                {
                field(UserName; Rec."User Name")
                {
                    Caption = 'User', Comment = 'is-IS=Notandi';
                    ToolTip = 'Select the enabled users to update in this company.', Comment = 'is-IS=Veldu virka notendur sem á að uppfæra í þessu fyrirtæki.';
                    Editable = false;
                }
                field(HasFoundationChat; HasFoundationChat)
                {
                    Caption = 'BIFROST Chat ori', Comment = 'is-IS=BIFROST Chat ori';
                    ToolTip = 'Shows whether this user has the Foundation chat permission set.', Comment = 'is-IS=Sýnir hvort notandinn hafi spjallheimildasamstæðu Foundation.';
                    Editable = false;
                }
                field(HasLanguageModelsChat; HasLanguageModelsChat)
                {
                    Caption = 'BIFROST LLM Chat ori', Comment = 'is-IS=BIFROST LLM Chat ori';
                    ToolTip = 'Shows whether this user has the Language Models chat permission set.', Comment = 'is-IS=Sýnir hvort notandinn hafi spjallheimildasamstæðu Mállíkana.';
                    Editable = false;
                }
                field(UserModel; UserModel)
                {
                    Caption = 'Language model', Comment = 'is-IS=Mállíkan';
                    ToolTip = 'Shows the language model assigned to this user in this company.', Comment = 'is-IS=Sýnir mállíkanið sem notandanum er úthlutað í þessu fyrirtæki.';
                    Editable = false;
                }
                }
        }
    }
    var
        WizardMgt: Codeunit "LangModel Wizard Mgt ori";
        HasFoundationChat: Boolean;
        HasLanguageModelsChat: Boolean;
        UserModel: Code[20];
        SelectionErr: Label 'No enabled users are selected. Select users and try again.', Comment = 'is-IS=Engir virkir notendur eru valdir. Veldu notendur og reyndu aftur.';

    trigger OnAfterGetRecord()
    begin
        HasFoundationChat := WizardMgt.HasChatSet(Rec."User Security ID", false);
        HasLanguageModelsChat := WizardMgt.HasChatSet(Rec."User Security ID", true);
        UserModel := WizardMgt.GetUserModel(Rec."User Security ID");
    end;

    /// <summary>Applies an explicit wizard command only to the current enabled-user selection.</summary>
    /// <param name="GiveAccess">Assign both permission sets instead of the model.</param>
    /// <param name="ModelCode">Existing model to assign.</param>
    internal procedure ApplyToSelectedUsers(GiveAccess: Boolean; ModelCode: Code[20])
    var
        SelectedUser: Record User;
    begin
        CurrPage.SetSelectionFilter(SelectedUser);
        SelectedUser.SetRange(State, SelectedUser.State::Enabled);
        if not SelectedUser.FindSet() then
            Error(ErrorInfo.Create(SelectionErr));
        repeat
            if GiveAccess then
                WizardMgt.GiveChatAccess(SelectedUser."User Security ID")
            else
                WizardMgt.SetUserModel(SelectedUser."User Security ID", ModelCode);
        until SelectedUser.Next() = 0;
        CurrPage.Update(false);
    end;
}
