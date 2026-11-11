namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Permission tests of LLM.Prompt.Ask (#101, AC04 and AC17): the chat gates refuse with PermissionDenied before the
/// provider is called, and the three role combinations run Ask end to end with the scripted mock provider and one read tool.
/// </summary>
codeunit 96064 "LLM Prompt Ask Perm Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'ASK-PERM', Locked = true;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Ask_WithoutChatGate_PermissionDenied_1033()
    begin
        // [SCENARIO AC04] no BIFROST Chat ori: PermissionDenied, English
        VerifyDenied(false, 1033);
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Ask_WithoutChatGate_PermissionDenied_1039()
    begin
        // [SCENARIO AC04] no BIFROST Chat ori: PermissionDenied, Icelandic
        VerifyDenied(false, 1039);
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Ask_WithoutLLMChat_PermissionDeniedNamingSet_1033()
    begin
        // [SCENARIO AC04] no BIFROST LLM Chat ori: PermissionDenied naming the set, English
        VerifyDenied(true, 1033);
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Ask_WithoutLLMChat_PermissionDeniedNamingSet_1039()
    begin
        // [SCENARIO AC04] no BIFROST LLM Chat ori: PermissionDenied naming the set, Icelandic
        VerifyDenied(true, 1039);
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Ask_ApiChatLLMChat_RunsWithReadTool()
    begin
        // [SCENARIO AC17] BIFROST API ori + BIFROST Chat ori + BIFROST LLM Chat ori
        VerifyRuns('BIFROST API ori');
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Ask_ReadChatLLMChat_RunsWithReadTool()
    begin
        // [SCENARIO AC17] BIFROST Read ori in place of the API set
        VerifyRuns('BIFROST Read ori');
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Ask_FullChatLLMChat_RunsWithReadTool()
    begin
        // [SCENARIO AC17] BIFROST Full ori + the two chat sets
        VerifyRuns('BIFROST Full ori');
    end;

    local procedure VerifyRuns(RoleSet: Code[20])
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        Initialize();
        MockProvider.EnqueueAnswer('{"type":"tool_calls","toolCalls":[{"id":"c1","name":"who_am_i","arguments":{}}],"conversationState":"{\"messages\":[],\"model\":\"mock\"}"}');
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"ok"}');
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet(RoleSet);
        LibraryLowerPermissions.AddPermissionSet('BIFROST Chat ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM Chat ori');

        ResponseJson := Execute(StrSubstNo('{"question":"Who am I?","roleCode":"%1"}', ModelCodeTok), 1033);

        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Success', ResponseJson.GetText('status'), ResponseText);
        Assert.AreEqual(1, ResponseJson.GetInteger('toolCalls'), ResponseText);
        Assert.AreEqual(0, ResponseJson.GetInteger('toolErrors'), ResponseText);
        Assert.AreEqual('ok', ResponseJson.GetText('answer'), ResponseText);
    end;

    local procedure VerifyDenied(WithChatGate: Boolean; LanguageId: Integer)
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        ResponseJson: JsonObject;
        ResponseText: Text;
        PreviousLanguage: Integer;
    begin
        Initialize();
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"must not be used"}');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST API ori');
        if WithChatGate then
            LibraryLowerPermissions.AddPermissionSet('BIFROST Chat ori');

        ResponseJson := Execute(StrSubstNo('{"question":"Q","roleCode":"%1"}', ModelCodeTok), LanguageId);
        GlobalLanguage(PreviousLanguage);

        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('PermissionDenied', ResponseJson.GetText('code'), ResponseText);
        Assert.IsTrue(ResponseJson.GetText('nextStep').Contains('BIFROST LLM Chat ori'), 'the next step names BIFROST LLM Chat ori');
        if LanguageId = 1039 then
            Assert.AreEqual('Þú hefur ekki heimild til að spyrja mállíkan.', ResponseJson.GetText('error'), 'Icelandic refusal')
        else
            Assert.AreEqual('You do not have permission to ask a language model.', ResponseJson.GetText('error'), 'English refusal');
        Assert.IsFalse(MockProvider.WasSendChatMessageCalled(), 'the provider must not be called');
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
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Ask", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
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
        if BifrostLanguageModel.Get(ModelCodeTok) then
            BifrostLanguageModel.Delete(true);
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := ModelCodeTok;
        BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        BifrostLanguageModel.Insert(true);
    end;
}
