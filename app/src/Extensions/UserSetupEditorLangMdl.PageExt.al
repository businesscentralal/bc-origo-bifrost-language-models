namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Adds the language model assignment and the Bifrost Chat FactBox to the
/// Bifrost Foundation user setup editor.
/// </summary>
pageextension 10035402 "User Setup Editor LangMdl ori" extends "User Setup Editor ori"
{
    layout
    {
        addlast(General)
        {
            field("Bifrost Language Model Code"; Rec."Bifrost Language Model Code")
            {
                ApplicationArea = All;
                Caption = 'Language Model Code', Comment = 'is-IS=Kóði mállíkans';
                ToolTip = 'Specifies the language model this user chats with in Bifrost Chat. If empty, Bifrost Chat is not available for this user.', Comment = 'is-IS=Tilgreinir mállíkanið sem þessi notandi spjallar við í Bifröst Chat. Ef tómt er Bifröst Chat ekki tiltækt fyrir þennan notanda.';

                trigger OnValidate()
                begin
                    CurrPage.Update(true);
                end;
            }
        }
        addlast(FactBoxes)
        {
            part(ori_BifrostChatFactBox; "Bifrost Chat FactBox ori")
            {
                ApplicationArea = All;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"User Setup ori", Rec.SystemId, StrSubstNo(ChatContextCaptionLbl, Rec.TableCaption(), Rec."User Name"));
    end;

    var
        ChatContextCaptionLbl: Label '%1 %2', Locked = true;
}
