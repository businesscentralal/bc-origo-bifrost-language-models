namespace Origo.Bifrost.LanguageModels.Test;

using System.Security.AccessControl;

/// <summary>Restricted test caller: user visibility and indirect permission-assignment reads only.</summary>
permissionset 96038 "LM Wizard Read ori"
{
    Assignable = false;
    Permissions = tabledata User = R,
                  tabledata "Access Control" = r;
}
