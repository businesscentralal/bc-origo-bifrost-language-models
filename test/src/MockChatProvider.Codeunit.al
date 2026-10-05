namespace Origo.Bifrost.LanguageModels.Test;

using Microsoft.Utilities;
using Origo.Bifrost;

/// <summary>
/// Minimal "Chat Provider ori" implementation behind the test-only value "Mock Chat Provider Type".MockOtherProvider.
/// It is never called; the claim tests only need the value to stand for another app that holds the chat provider.
/// </summary>
codeunit 96021 "Mock Chat Provider" implements "Chat Provider ori"
{
    Access = Internal;

    procedure IsConfigured(): Boolean
    begin
        exit(false);
    end;

    procedure BuildConfigJson(): Text
    begin
        exit('{}');
    end;

    procedure SaveApiKey(ApiKey: Text)
    begin
    end;

    procedure SaveServiceApiKey(ApiKey: Text)
    begin
    end;

    procedure SendChatMessage(PayloadJson: Text): Text
    begin
        exit('');
    end;

    procedure ContinueWithToolResults(ConversationState: Text; ToolResultsJson: Text): Text
    begin
        exit('');
    end;

    procedure GetAvailableModels(var TempNameValueBuffer: Record "Name/Value Buffer" temporary): Boolean
    begin
        exit(false);
    end;

    procedure ClearCredentials()
    begin
    end;
}
