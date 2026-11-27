namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue 175: the Bifrost Related action opens Language Models setup in either supported language.
/// </summary>
codeunit 96088 "LangModel 175 Navigation Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>
    /// AC1/AC3: the English Related action is visible, enabled and opens the setup page.
    /// </summary>
    [Test]
    procedure AC01_AC03_EnglishActionOpensSetup()
    begin
        VerifyNavigation(1033);
    end;

    /// <summary>
    /// AC1/AC2/AC3: the Icelandic Related action opens the same setup page.
    /// </summary>
    [Test]
    procedure AC01_AC02_AC03_IcelandicActionOpensSetup()
    begin
        VerifyNavigation(1039);
    end;

    local procedure VerifyNavigation(LanguageId: Integer)
    var
        BifrostPage: TestPage "Bifrost ori";
        SetupPage: TestPage "LangModel Setup ori";
        PreviousLanguage: Integer;
    begin
        // [ASSUMPTION] This navigation has no input; the destination may contain zero language models.
        // [GIVEN] The Bifrost page in the requested language, without requiring a selected record.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        BifrostPage.OpenView();
        Assert.IsTrue(BifrostPage.LangModelSetup.Visible(), 'Language Models setup must be visible.');
        Assert.IsTrue(BifrostPage.LangModelSetup.Enabled(), 'Language Models setup must be enabled.');

        // [WHEN] The user invokes the Related action.
        SetupPage.Trap();
        BifrostPage.LangModelSetup.Invoke();

        // [THEN] The setup page opens and exposes its model and tool counts.
        if LanguageId = 1039 then
            Assert.AreEqual('Uppsetning Bifröst mállíkana', SetupPage.Caption(), 'The setup page must open in Icelandic.')
        else
            Assert.AreEqual('Bifrost Language Models Setup', SetupPage.Caption(), 'The setup page must open in English.');
        Assert.IsTrue(SetupPage.LanguageModelCount.AsInteger() >= 0, 'The setup model count must be readable.');
        Assert.IsTrue(SetupPage.ToolCount.AsInteger() >= 0, 'The setup tool count must be readable.');
        SetupPage.Close();
        BifrostPage.Close();
        GlobalLanguage(PreviousLanguage);
    end;
}
