namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>
/// A second value on Foundation's "Chat Provider Type ori", so the claim tests can make another app
/// hold the chat provider and prove that Language Models leaves it unchanged (#35).
/// </summary>
enumextension 96020 "Mock Chat Provider Type" extends "Chat Provider Type ori"
{
    value(96020; MockOtherProvider)
    {
        Caption = 'Mock other provider', Comment = 'is-IS=Önnur prófunarveita';
        Implementation = "Chat Provider ori" = "Mock Chat Provider";
    }
}
