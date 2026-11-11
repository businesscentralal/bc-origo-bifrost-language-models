namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Registers the Bifrost Language Models message types on the Bifrost Foundation message type enum.
/// Bifrost Language Models contributes the one-shot language model completion type.
/// </summary>
enumextension 10035399 "LangModel Message Type ori" extends "Message Type ori"
{
    /// <summary>
    /// One-shot LLM completion. Sends system + user prompt to the configured provider
    /// and returns the text response. No tools, no chat Bootstrap, no conversation state.
    /// </summary>
    value(10035399; "LLM.Prompt.Complete")
    {
        Caption = 'LLM.Prompt.Complete', Locked = true;
        Implementation = "Msg Interface ori" = "LLM Prompt Compl Impl ori", "Msg Discovery ori" = "LLM Prompt Compl Impl ori", "Msg Contract ori" = "LLM Prompt Compl Impl ori";
    }

    /// <summary>
    /// Headless question with read-only Bifrost tools (#101). Read effect, mandatory caps, no timeout.
    /// </summary>
    value(10035432; "LLM.Prompt.Ask")
    {
        Caption = 'LLM.Prompt.Ask', Locked = true;
        Implementation = "Msg Interface ori" = "LLM Prompt Ask Impl ori", "Msg Discovery ori" = "LLM Prompt Ask Impl ori", "Msg Contract ori" = "LLM Prompt Ask Impl ori";
    }
}
