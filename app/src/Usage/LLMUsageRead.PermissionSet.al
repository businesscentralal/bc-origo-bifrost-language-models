namespace Origo.Bifrost.LanguageModels;

/// <summary>Read-only access to usage metadata for administrators and auditors.</summary>
permissionset 10035440 "BIFROST LLM UseR ori"
{
    Assignable = true;
    Caption = 'Bifrost LLM usage read', MaxLength = 30, Comment = 'is-IS=Lesa mállíkananotkun Bifrastar';
    Permissions = codeunit "LLM Usage Help ori" = X,
                  table "LLM Usage Log ori" = X,
                  tabledata "LLM Usage Log ori" = R,
                  table "LLM Usage Daily ori" = X,
                  tabledata "LLM Usage Daily ori" = R,
                  page "LLM Usage Log ori" = X,
                  page "LLM Usage Daily ori" = X;
}
