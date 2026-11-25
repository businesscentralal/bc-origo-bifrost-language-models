namespace Origo.Bifrost.LanguageModels;

/// <summary>Allows administrators to configure and run app-controlled compression, without direct log writes.</summary>
permissionset 10035441 "BIFROST LLM Use ori"
{
    Assignable = true;
    Caption = 'Bifrost LLM usage admin', MaxLength = 30, Comment = 'is-IS=Stýra mállíkananotkun Bifrastar';
    IncludedPermissionSets = "BIFROST LLM UseR ori";
    Permissions = tabledata "LLM Usage Log ori" = d,
                  tabledata "LLM Usage Daily ori" = imd,
                  table "LLM Usage Setup ori" = X,
                  tabledata "LLM Usage Setup ori" = RIMD,
                  page "LLM Usage Setup ori" = X,
                  codeunit "LLM Usage Compression ori" = X,
                  codeunit "LLM Usage Retention ori" = X;
}
