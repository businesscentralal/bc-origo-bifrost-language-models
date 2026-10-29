namespace Origo.Bifrost.LanguageModels.Test;
using Origo.Bifrost.LanguageModels;

using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>
/// Tests for "LangModel API Client ori".ExtractText — parsing the assistant text out
/// of an OpenAI-compatible chat completions response, including edge cases.
/// </summary>
codeunit 96011 "LangModel API Client Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>
    /// Verifies that the API client extracts text from a standard choices response.
    /// </summary>
    [Test]
    procedure ExtractText_StandardResponse()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        // [GIVEN] A standard OpenAI response
        Response.ReadFrom('{"choices":[{"message":{"content":"Hello world"},"finish_reason":"stop"}]}');

        // [WHEN/THEN]
        Assert.AreEqual('Hello world', ApiClient.ExtractText(Response), 'Should extract content from choices.');
    end;

    /// <summary>
    /// Verifies that an empty choices array yields empty text.
    /// </summary>
    [Test]
    procedure ExtractText_EmptyChoices_ReturnsEmpty()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        Response.ReadFrom('{"choices":[]}');
        Assert.AreEqual('', ApiClient.ExtractText(Response), 'Empty choices should return empty.');
    end;

    /// <summary>
    /// Verifies that a response without choices yields empty text.
    /// </summary>
    [Test]
    procedure ExtractText_NoChoices_ReturnsEmpty()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        Response.ReadFrom('{"id":"test"}');
        Assert.AreEqual('', ApiClient.ExtractText(Response), 'Missing choices should return empty.');
    end;

    /// <summary>
    /// Verifies that null message content yields empty text.
    /// </summary>
    [Test]
    procedure ExtractText_ContentIsNull_ReturnsEmpty()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        // [GIVEN] Response where content is null
        Response.ReadFrom('{"choices":[{"message":{"content":null},"finish_reason":"stop"}]}');

        // [WHEN/THEN]
        Assert.AreEqual('', ApiClient.ExtractText(Response), 'Null content should return empty.');
    end;

    /// <summary>
    /// Verifies that array message content yields empty text.
    /// </summary>
    [Test]
    procedure ExtractText_ContentArray_ReturnsEmpty()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        // [GIVEN] Response where content is an array (multi-modal response) — ExtractText only
        // handles string content on the OpenAI-compatible path.
        Response.ReadFrom('{"choices":[{"message":{"content":[{"type":"text","text":"hello"}]},"finish_reason":"stop"}]}');

        // [WHEN/THEN]
        Assert.AreEqual('', ApiClient.ExtractText(Response), 'Array content should return empty (not a value).');
    end;

    /// <summary>The xAI upload body sends purpose before the file and decodes the base64 content.</summary>
    [Test]
    procedure UploadBody_PurposeBeforeDecodedFile()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Body: Codeunit "Temp Blob";
        Content: BigText;
        BodyIn: InStream;
        Boundary: Text;
        BodyText: Text;
        CrLf: Text[2];
    begin
        ApiClient.WriteProviderFileUpload('my file.pdf', 'application/pdf', 'aGVsbG8=', Boundary, Body);
        Body.CreateInStream(BodyIn);
        Content.Read(BodyIn);
        Content.GetSubText(BodyText, 1);
        CrLf[1] := 13;
        CrLf[2] := 10;
        Assert.IsTrue(StrPos(BodyText, 'name="purpose"') < StrPos(BodyText, 'name="file"'), 'purpose is written before the file.');
        Assert.IsTrue(BodyText.Contains('assistants'), 'The compatibility purpose is assistants.');
        Assert.IsTrue(BodyText.Contains('filename="myfile.pdf"'), 'Spaces are removed from the uploaded file name.');
        Assert.IsTrue(BodyText.Contains('Content-Type: application/pdf'), 'The document MIME type is kept.');
        Assert.IsTrue(BodyText.Contains('hello'), 'Base64 file bytes are decoded into the body.');
        Assert.IsTrue(BodyText.Contains(Boundary), 'The body uses the returned boundary.');
        Assert.IsTrue(StrPos(BodyText, CrLf) > 0, 'Multipart lines use CRLF.');
    end;
}
