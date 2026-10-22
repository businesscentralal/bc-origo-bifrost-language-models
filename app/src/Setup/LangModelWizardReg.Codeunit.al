namespace Origo.Bifrost.LanguageModels;

using System.Environment.Configuration;
using System.Media;

/// <summary>Registers the Language Models assisted setup without completing or configuring it.</summary>
codeunit 10035426 "LangModel Wizard Reg. ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Guided Experience", OnRegisterAssistedSetup, '', false, false)]
    local procedure RegisterWizard()
    var
        GuidedExperience: Codeunit "Guided Experience";
        TitleTxt: Label 'Set up Bifrost Language Models', Comment = 'is-IS=Setja upp Bifröst mállíkön';
        ShortTitleTxt: Label 'Bifrost Language Models', Comment = 'is-IS=Bifröst mállíkön';
        DescriptionTxt: Label 'Enable outbound HTTP, set up Copilot or another language model, make Bifrost Chat use it, and give users chat access.', Comment = 'is-IS=Virkja HTTP út á við, setja upp Copilot eða annað mállíkan, tengja það við Bifröst spjall og veita notendum spjallaðgang.';
    begin
        GuidedExperience.InsertAssistedSetup(TitleTxt, ShortTitleTxt, DescriptionTxt, 10,
            ObjectType::Page, Page::"LangModel Setup Wizard ori", Enum::"Assisted Setup Group"::Extensions,
            '', Enum::"Video Category"::Uncategorized, 'https://docs.bifrost.origo.is/en-us/language-models/');
    end;
}
