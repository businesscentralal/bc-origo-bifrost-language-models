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
                    Caption = 'Chat permission', Comment = 'is-IS=Spjallheimild';
                    ToolTip = 'Shows whether this user is assigned the BIFROST Chat ori permission set for this company or all companies.', Comment = 'is-IS=Sýnir hvort notandanum sé úthlutað heimildasamstæðunni BIFROST Chat ori fyrir þetta fyrirtæki eða öll fyrirtæki.';
                    Editable = false;
                }
                field(HasLanguageModelsChat; HasLanguageModelsChat)
                {
                    Caption = 'Language model chat', Comment = 'is-IS=Spjall við mállíkan';
                    ToolTip = 'Shows whether this user is assigned the BIFROST LLM Chat ori permission set for this company or all companies.', Comment = 'is-IS=Sýnir hvort notandanum sé úthlutað heimildasamstæðunni BIFROST LLM Chat ori fyrir þetta fyrirtæki eða öll fyrirtæki.';
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
        FoundationUsers: Dictionary of [Guid, Boolean];
        LanguageModelUsers: Dictionary of [Guid, Boolean];
        UserModels: Dictionary of [Guid, Code[20]];
        SelectionErr: Label 'No enabled users are selected. Select users and try again.', Comment = 'is-IS=Engir virkir notendur eru valdir. Veldu notendur og reyndu aftur.';

    trigger OnOpenPage()
    begin
        Rec.SetLoadFields("User Security ID", "User Name", State);
        WizardMgt.LoadUserStatus(FoundationUsers, LanguageModelUsers, UserModels);
    end;

    trigger OnAfterGetRecord()
    begin
        HasFoundationChat := FoundationUsers.ContainsKey(Rec."User Security ID");
        HasLanguageModelsChat := LanguageModelUsers.ContainsKey(Rec."User Security ID");
        Clear(UserModel);
        if UserModels.ContainsKey(Rec."User Security ID") then
            UserModel := UserModels.Get(Rec."User Security ID");
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
        RefreshUsers();
    end;

    /// <summary>Reloads the user status snapshot after an explicit command or verification request.</summary>
    internal procedure RefreshUsers()
    begin
        WizardMgt.LoadUserStatus(FoundationUsers, LanguageModelUsers, UserModels);
        CurrPage.Update(false);
    end;
}
