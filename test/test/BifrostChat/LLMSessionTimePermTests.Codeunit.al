namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests that LLM.Prompt.Complete still completes, and now also sends a real SESSION TIME block from Foundation, for each
/// role combination that runs it today (language-models#99 AC09). Foundation's real block is used, so a missing grant
/// would show as a prompt without a block (fail open) and fail these tests.
/// </summary>
codeunit 96061 "LLM Session Time Perm Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'LM99-PERM', Locked = true;

    /// <summary>Verifies the API, Chat and LLM Chat baseline gets a block, in English.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ApiChatLlmChat_PromptHoldsABlock_1033()
    begin
        VerifyBlockIsSent('BIFROST API ori', 1033);
    end;

    /// <summary>Verifies the API, Chat and LLM Chat baseline gets a block, in Icelandic.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ApiChatLlmChat_PromptHoldsABlock_1039()
    begin
        VerifyBlockIsSent('BIFROST API ori', 1039);
    end;

    /// <summary>Verifies Read in place of API, plus Chat and LLM Chat, gets a block, in English.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ReadChatLlmChat_PromptHoldsABlock_1033()
    begin
        VerifyBlockIsSent('BIFROST Read ori', 1033);
    end;

    /// <summary>Verifies Read in place of API, plus Chat and LLM Chat, gets a block, in Icelandic.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ReadChatLlmChat_PromptHoldsABlock_1039()
    begin
        VerifyBlockIsSent('BIFROST Read ori', 1039);
    end;

    /// <summary>Verifies Full, plus Chat and LLM Chat, gets a block, in English.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure FullChatLlmChat_PromptHoldsABlock_1033()
    begin
        VerifyBlockIsSent('BIFROST Full ori', 1033);
    end;

    /// <summary>Verifies Full, plus Chat and LLM Chat, gets a block, in Icelandic.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure FullChatLlmChat_PromptHoldsABlock_1039()
    begin
        VerifyBlockIsSent('BIFROST Full ori', 1039);
    end;

    local procedure VerifyBlockIsSent(TransportSet: Code[20]; LanguageId: Integer)
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        ResponseJson: JsonObject;
        ResponseText: Text;
        SystemToken: JsonToken;
        Payload: JsonObject;
        PreviousLanguage: Integer;
    begin
        Initialize();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet(TransportSet);
        LibraryLowerPermissions.AddPermissionSet('BIFROST Chat ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM Chat ori');

        ResponseJson := Execute(StrSubstNo('{"prompt":"Hello","roleCode":"%1"}', ModelCodeTok), LanguageId);
        GlobalLanguage(PreviousLanguage);

        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Success', ResponseJson.GetText('status'), ResponseText);
        Assert.IsFalse(ResponseJson.Contains('warnings'), 'No sessionTimeUnavailable warning: ' + ResponseText);
        Assert.IsTrue(ResponseJson.Contains('sessionTime'), 'The response carries sessionTime: ' + ResponseText);
        Assert.IsTrue(Payload.ReadFrom(MockProvider.GetLastCompletePayload()), 'The provider got a payload');
        Assert.IsTrue(Payload.Get('systemPrompt', SystemToken), 'The provider got a system prompt');
        Assert.IsTrue(SystemToken.AsValue().AsText().StartsWith('SESSION TIME ('), 'The system prompt starts with the block');
    end;

    local procedure Execute(RequestBody: Text; LanguageId: Integer) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseContentType: Text[100];
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestBody);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Complete", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure Initialize()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST Full ori');
        MockProvider.Reset();
        MockProvider.SetIsConfigured(true);
        MockProvider.SetCompleteResponse('{"text":"mock completion"}');
        if BifrostLanguageModel.Get(ModelCodeTok) then
            BifrostLanguageModel.Delete(true);
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := ModelCodeTok;
        BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        BifrostLanguageModel.Insert(true);
    end;
}
