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

    /// <summary>
    /// Returns false so the alternative chat provider stays unconfigured.
    /// </summary>
    procedure IsConfigured(): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Returns an empty JSON configuration for the alternative mock provider.
    /// </summary>
    procedure BuildConfigJson(): Text
    begin
        exit('{}');
    end;

    /// <summary>
    /// Ignores the personal API key in this alternative mock provider.
    /// </summary>
    procedure SaveApiKey(ApiKey: Text)
    begin
    end;

    /// <summary>
    /// Ignores the service API key in this alternative mock provider.
    /// </summary>
    procedure SaveServiceApiKey(ApiKey: Text)
    begin
    end;

    /// <summary>
    /// Returns an empty chat response without calling a provider.
    /// </summary>
    procedure SendChatMessage(PayloadJson: Text): Text
    begin
        exit('');
    end;

    /// <summary>
    /// Returns an empty continuation response without executing tools.
    /// </summary>
    procedure ContinueWithToolResults(ConversationState: Text; ToolResultsJson: Text): Text
    begin
        exit('');
    end;

    /// <summary>
    /// Returns false without adding models to the temporary buffer.
    /// </summary>
    procedure GetAvailableModels(var TempNameValueBuffer: Record "Name/Value Buffer" temporary): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Leaves credentials unchanged because the alternative mock stores none.
    /// </summary>
    procedure ClearCredentials()
    begin
    end;
}
