namespace Origo.Bifrost.LanguageModels;
using Microsoft.Sales.Customer;

using Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Adds the Bifrost Chat action to Customer List.
/// </summary>
pageextension 10035347 "Bifrost Chat CustomerList ori" extends "Customer List"
{
    ContextSensitiveHelpPage = 'bifrost-chat';
    actions
    {
        addlast(Processing)
        {
            action(ori_BifrostChat)
            {
                Caption = 'Chat via Bifrost', Comment = 'is-IS=Spjalla með Bifröst';
                ToolTip = 'Chat about this customer in Business Central.', Comment = 'is-IS=Spjalla um þennan viðskiptavin í Business Central';
                ApplicationArea = All;
                Visible = ChatBoxVisible;
                Image = SparkleFilled;

                trigger OnAction()
                var
                    ChatProvider: Codeunit "LangModel Chat Provider ori";
                begin
                    ChatProvider.OpenRecordChat(Database::Customer, Rec.SystemId, StrSubstNo('%1 %2', Rec."No.", Rec.Name));
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(ori_BifrostChat_Promoted; ori_BifrostChat)
            {
            }
        }
    }

    var
        ChatBoxVisible: Boolean;

    trigger OnOpenPage()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
    begin
        ChatBoxVisible := BifrostChatMgt.ShowBifrostChat();
    end;
}
