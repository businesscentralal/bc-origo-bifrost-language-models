namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Checks the missing-key hint across languages, page modes and both secret scopes.
/// Browser verification additionally checks the actual rendered field bounds.
/// </summary>
codeunit 96035 "LangModel Hint Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>
    /// Checks the English read-only card through all key-presence transitions.
    /// </summary>
    [Test]
    procedure EnglishRead_KeyPresenceTransitions()
    begin
        VerifyKeyPresenceTransitions(1033, false);
    end;

    /// <summary>
    /// Checks the English editable card through all key-presence transitions.
    /// </summary>
    [Test]
    procedure EnglishEdit_KeyPresenceTransitions()
    begin
        VerifyKeyPresenceTransitions(1033, true);
    end;

    /// <summary>
    /// Checks the Icelandic read-only card through all key-presence transitions.
    /// </summary>
    [Test]
    procedure IcelandicRead_KeyPresenceTransitions()
    begin
        VerifyKeyPresenceTransitions(1039, false);
    end;

    /// <summary>
    /// Checks the Icelandic editable card through all key-presence transitions.
    /// </summary>
    [Test]
    procedure IcelandicEdit_KeyPresenceTransitions()
    begin
        VerifyKeyPresenceTransitions(1039, true);
    end;

    local procedure VerifyKeyPresenceTransitions(LanguageId: Integer; EditMode: Boolean)
    var
        LangModel: Record "Bifrost Language Model ori";
        Secrets: Codeunit "LangModel Secrets ori";
        SyntheticKey: SecretText;
        OriginalLanguage: Integer;
    begin
        // [SCENARIO] #70: no provider calls, clock dependence or shared fixtures.
        // [GIVEN] An owned saved OpenAI model with neither secret scope populated.
        OriginalLanguage := GlobalLanguage(LanguageId);
        LangModel.Init();
        LangModel.Code := CopyStr('XHINT-' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(LangModel.Code));
        LangModel.Validate("Chat Provider", LangModel."Chat Provider"::OpenAI);
        LangModel.Insert(true);
        Assert.IsFalse(Secrets.HasUserKey(LangModel.Code), 'The owned model must start without a personal key.');
        Assert.IsFalse(Secrets.HasServiceKey(LangModel.Code), 'The owned model must start without a shared key.');
        AssertCardHint(LangModel, LanguageId, EditMode, true);

        // [WHEN] A personal key, both keys, or only a shared key is present.
        SyntheticKey := AsSecret('Synthetic hint test value; never sent to a provider');
        Secrets.SetUserKey(LangModel.Code, SyntheticKey);
        AssertCardHint(LangModel, LanguageId, EditMode, false);
        Secrets.SetServiceKey(LangModel.Code, SyntheticKey);
        AssertCardHint(LangModel, LanguageId, EditMode, false);
        Secrets.ClearUserKey(LangModel.Code);
        AssertCardHint(LangModel, LanguageId, EditMode, false);

        // [THEN] Removing the final key restores the localized instruction.
        Secrets.ClearServiceKey(LangModel.Code);
        AssertCardHint(LangModel, LanguageId, EditMode, true);
        LangModel.Validate("Chat Provider", LangModel."Chat Provider"::None);
        LangModel.Modify(true);
        AssertCardHint(LangModel, LanguageId, EditMode, false);
        LangModel.Delete(true);
        GlobalLanguage(OriginalLanguage);
    end;

    local procedure AsSecret(Value: Text) Secret: SecretText
    begin
        Secret := Value;
    end;

    local procedure AssertCardHint(LangModel: Record "Bifrost Language Model ori"; LanguageId: Integer; EditMode: Boolean; ExpectedVisible: Boolean)
    var
        ModelCard: TestPage "Bifrost LangModel Card ori";
        ExpectedPrefix: Text;
    begin
        if EditMode then
            ModelCard.OpenEdit()
        else
            ModelCard.OpenView();
        ModelCard.GoToRecord(LangModel);
        Assert.AreEqual(ExpectedVisible, ModelCard.KeyMissingHintField.Visible(), 'The hint must follow provider and key presence.');
        if ExpectedVisible then begin
            if LanguageId = 1039 then
                ExpectedPrefix := 'Enginn API-lykill'
            else
                ExpectedPrefix := 'No API key is stored';
            Assert.IsTrue(StrPos(ModelCard.KeyMissingHintField.Value(), ExpectedPrefix) = 1, 'The hint must use the selected language.');
        end;
        ModelCard.Close();
    end;
}
