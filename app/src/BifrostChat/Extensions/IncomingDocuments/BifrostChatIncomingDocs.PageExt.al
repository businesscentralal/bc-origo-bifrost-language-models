namespace Origo.Bifrost.LanguageModels;
using Microsoft.EServices.EDocument;

using Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Adds the Bifrost Chat action to Incoming Documents.
/// </summary>
pageextension 10035356 "Bifrost Chat IncomingDocs ori" extends "Incoming Documents"
{
    ContextSensitiveHelpPage = 'bifrost-chat';
    actions
    {
        addlast(Processing)
        {
            action(ori_BifrostChat)
            {
                Caption = 'Chat via Bifrost', Comment = 'is-IS=Spjalla með Bifröst';
                ToolTip = 'Chat about this incoming document in Business Central.', Comment = 'is-IS=Spjalla um þetta skjal á innleið í Business Central';
                ApplicationArea = All;
                Visible = ChatBoxVisible;
                Image = SparkleFilled;

                trigger OnAction()
                var
                    ChatProvider: Codeunit "LangModel Chat Provider ori";
                begin
                    ChatProvider.OpenRecordChat(Database::"Incoming Document", Rec.SystemId, StrSubstNo('%1 %2', Rec.TableCaption(), Rec."Entry No."));
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
