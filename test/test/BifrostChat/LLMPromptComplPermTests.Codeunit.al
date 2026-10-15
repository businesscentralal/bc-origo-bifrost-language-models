namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests that LLM.Prompt.Complete runs for a session that holds only BIFROST Chat ori and BIFROST LLM Chat ori (#66, S4).
/// The provider is the "Mock Bifrost Chat Provider"; no real provider is called.
/// </summary>
codeunit 96032 "LLM Prompt Compl Perm Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'S4-PERM', Locked = true;

    /// <summary>
    /// Verifies that a session with only BIFROST Chat ori and BIFROST LLM Chat ori passes the permission check and reads the language model, in English.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Execute_ChatAndLLMChatOnly_RunsPastPermissionCheck_1033()
    begin
        // [SCENARIO] a user holding only BIFROST Chat ori and BIFROST LLM Chat ori can run LLM.Prompt.Complete (English client).
        VerifyRestrictedUserCompletes(1033);
    end;

    /// <summary>
    /// Verifies that a session with only BIFROST Chat ori and BIFROST LLM Chat ori passes the permission check and reads the language model, in Icelandic.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Execute_ChatAndLLMChatOnly_RunsPastPermissionCheck_1039()
    begin
        // [SCENARIO] a user holding only BIFROST Chat ori and BIFROST LLM Chat ori can run LLM.Prompt.Complete (Icelandic client).
        VerifyRestrictedUserCompletes(1039);
    end;

    /// <summary>
    /// Verifies that a session without BIFROST LLM Chat ori cannot read the language model and fails with the permission error, in English.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Execute_ChatOnlyWithoutLLMChat_FailsWithPermissionError_1033()
    begin
        // [SCENARIO] without BIFROST LLM Chat ori the language model table is not readable (English client).
        VerifyWithoutLLMChatFails(1033);
    end;

    /// <summary>
    /// Verifies that a session without BIFROST LLM Chat ori cannot read the language model and fails with the permission error, in Icelandic.
    /// </summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Execute_ChatOnlyWithoutLLMChat_FailsWithPermissionError_1039()
    begin
        // [SCENARIO] without BIFROST LLM Chat ori the language model table is not readable (Icelandic client).
        VerifyWithoutLLMChatFails(1039);
    end;

    local procedure VerifyRestrictedUserCompletes(LanguageId: Integer)
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        ResponseJson: JsonObject;
        ResponseText: Text;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] a language model with the mock provider and a canned completion
        Initialize();
        MockProvider.SetIsConfigured(true);
        MockProvider.SetCompleteResponse('{"text":"mock completion"}');
        // [GIVEN] a session with only BIFROST Chat ori and BIFROST LLM Chat ori
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST Chat ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM Chat ori');

        // [WHEN] LLM.Prompt.Complete runs for that language model
        ResponseJson := Execute(StrSubstNo('{"prompt":"Hello","roleCode":"%1"}', ModelCodeTok));
        GlobalLanguage(PreviousLanguage);

        // [THEN] it passes the permission check, reads the model and returns the provider's completion
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Success', ResponseJson.GetText('status'), ResponseText);
        Assert.AreEqual('mock completion', ResponseJson.GetText('text'), ResponseText);
        Assert.IsTrue(MockProvider.WasCompletePromptCalled(), 'the mock provider must receive the CompletePrompt call');
    end;

    local procedure VerifyWithoutLLMChatFails(LanguageId: Integer)
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        PreviousLanguage: Integer;
    begin
        // [GIVEN] a language model with the mock provider
        Initialize();
        MockProvider.SetIsConfigured(true);
        MockProvider.SetCompleteResponse('{"text":"mock completion"}');
        // [GIVEN] a session with BIFROST Chat ori but without BIFROST LLM Chat ori
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST Chat ori');

        // [WHEN] LLM.Prompt.Complete runs for that language model
        asserterror Execute(StrSubstNo('{"prompt":"Hello","roleCode":"%1"}', ModelCodeTok));
        GlobalLanguage(PreviousLanguage);

        // [THEN] the read of the language model fails with a permission error and the provider is not called
        Assert.ExpectedError('permission');
        Assert.IsFalse(MockProvider.WasCompletePromptCalled(), 'the provider must not be called without BIFROST LLM Chat ori');
    end;

    local procedure Execute(RequestBody: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        ResponseContentType: Text[100];
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestBody);
        Dispatcher.Execute("Message Type ori"::"LLM.Prompt.Complete", MessageVersion::"1.0", '', '', 'text/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure Initialize()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        MockProvider.Reset();
        if BifrostLanguageModel.Get(ModelCodeTok) then
            BifrostLanguageModel.Delete(true);
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := ModelCodeTok;
        BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        BifrostLanguageModel.Insert(true);
    end;
}
