namespace Origo.Bifrost.LanguageModels;
using Microsoft.Purchases.Document;

using Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Adds the Bifrost Chat action to Purchase Credit Memos.
/// </summary>
pageextension 10035361 "Bifrost Chat PurchCrMemos ori" extends "Purchase Credit Memos"
{
    ContextSensitiveHelpPage = 'bifrost-chat';
    actions
    {
        addlast(Processing)
        {
            action(ori_BifrostChat)
            {
                Caption = 'Chat via Bifrost', Comment = 'is-IS=Spjalla með Bifröst';
                ToolTip = 'Chat about this credit memo in Business Central.', Comment = 'is-IS=Spjalla um þessa kreditnótu í Business Central';
                ApplicationArea = All;
                Visible = ChatBoxVisible;
                Image = SparkleFilled;

                trigger OnAction()
                var
                    ChatProvider: Codeunit "LangModel Chat Provider ori";
                begin
                    ChatProvider.OpenRecordChat(Database::"Purchase Header", Rec.SystemId, StrSubstNo('%1 %2', Rec."Document Type", Rec."No."));
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
