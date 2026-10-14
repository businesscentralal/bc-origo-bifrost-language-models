# Skráning - Bifröst mállíkön (is-IS)

## Auðkenni tilboðs

| Reitur | Gildi |
| --- | --- |
| Heiti tilboðs | Bifröst mállíkön |
| Heiti forrits (app.json) | Bifrost Language Models |
| Auðkenni forrits | `f1722684-0c24-4022-a2e0-0f63154aca76` |
| Útgefandi | Origo (sami útgefandi og Bifrost Foundation) |
| Útgáfa | Núverandi útgáfa í `app/app.json` (sett við útgáfu) |
| Nauðsynlegt forrit | Bifrost Foundation 28.0.1.0 eða nýrra (`7505e808-6e52-4b96-a328-82573391297a`) |
| Vörunúmer (product id) | _Eigandi útgefandaaðgangs Origo fyllir út þegar tilboðið er til_ |

## Stutt samantekt (hámark 100 stafir)

```
Spjallaðu við Business Central með OpenAI, Anthropic, Gemini, xAI, Azure OpenAI eða Copilot.
```

## Lýsing (einfalt HTML; Partner Center birtir ekki Markdown, hámark 3000 stafir með merkjum)

```html
<p>Bifröst mállíkön tengja Bifröst við það mállíkan sem þú velur. Notendur spjalla við Business Central af þeirri síðu sem þeir eru að vinna á, og aðstoðarmaðurinn svarar út frá gögnum þeirra sjálfra með þeim réttindum sem þeir hafa.</p>
<p>Forritið byggir á Bifrost Foundation, sem sér um sjálft spjallið og MCP verkfæraþjóninn sem gerir aðstoðarmanninum kleift að lesa og vinna með gögn í Business Central. Bifröst mállíkön sjá um mállíkönin sjálf.</p>
<p><b>Hvað færðu</b></p>
<ul>
<li><b>Mállíkön.</b> Eitt mállíkan í hverri línu: spjallveitandi, endapunktur, líkan, mörk (tímamörk, hámarksfjöldi tákna og samhengistákn) og hæfniefni sem verður hluti af kerfisfyrirmælum.</li>
<li><b>Sjö spjallveitendur.</b> Copilot, OpenAI, Azure OpenAI, sérsniðið LLM, Anthropic, xAI og Google (Gemini), allir á bak við sama veituviðmót.</li>
<li><b>Spjall á 36 stöðluðum síðum.</b> Upplýsingaglugganum Bifröst spjall er bætt við á síður viðskiptamanna, lánardrottna, vara, sölu, innkaupa, færslna og innkominna skjala.</li>
<li><b>Mállíkan fyrir hvern notanda.</b> Kerfisstjóri úthlutar hverjum notanda mállíkani í Uppsetningu notanda Bifröst. Bifröst spjall birtist aðeins notendum sem hafa fengið mállíkan.</li>
<li><b>Einskiptisbeiðnir.</b> Skilaboðategundin LLM.Prompt.Complete sendir kvaðningu til stillta líkansins og skilar textanum, til notkunar í handritum og tímasettum verkum.</li>
</ul>
<p><b>Lyklar og réttindi</b></p>
<ul>
<li>Forritið geymir aldrei API-lykil sjálft. Lyklar eru geymdir í leyndarmálageymslu Foundation og fluttir sem leynitexti alla leið í HTTP-haus beiðninnar.</li>
<li>Hver notandi getur sett inn persónulegan API-lykil, sem hefur forgang yfir sameiginlega lykilinn. Umsjón með sameiginlegum fyrirtækjalykli er sérstök heimildasamstæða (BIFROST ChatSvc ori) og því má fela hana öðrum án þess að veita aðgang að spjallinu.</li>
<li>Verkfærakall keyra með réttindum innskráða notandans í Business Central.</li>
</ul>
<p><b>Kröfur</b></p>
<ul>
<li>Business Central í skýinu (SaaS), útgáfa 28.</li>
<li>Bifrost Foundation 28.0.1.0 eða nýrra.</li>
<li>Aðgangur og API-lykill hjá völdum veitanda (ekki þörf fyrir Copilot). Kveikja þarf á <b>Allow HttpClient Requests</b> fyrir forritið í Extension Management, því allir ytri veitendur þurfa á því að halda.</li>
</ul>
```

## Leitarorð (Partner Center leyfir allt að 3; fleiri til vara)

1. Bifröst
2. spjall
3. mállíkan

Til vara: gervigreind, LLM, OpenAI, Anthropic, Gemini, Copilot, aðstoðarmaður.

## Flokkar

- Aðalflokkur: Productivity (staðfestið nákvæmt heiti í flokkalista Partner Center)
- Aukaflokkur: sá flokkur fyrir gervigreind eða spjall sem tilboðsformið stingur upp á, ef hann er í boði.

## Tungumál og markaðir

- Tungumál: enska (en-US) og íslenska (is-IS), í samræmi við `supportedLocales` í `app.json`.
- Markaðir: sömu markaðir og Bifrost Foundation er skráð á. Forritið er smíðað fyrir W1-staðfærslu.

## Tenglar

| Reitur | Slóð |
| --- | --- |
| Vefsíða | https://docs.bifrost.origo.is |
| Hjálp | https://docs.bifrost.origo.is/is-is/language-models/ |
| Persónuverndarstefna | https://docs.bifrost.origo.is/en-us/licensing/privacy/ |
| Notkunarskilmálar (EULA) | https://docs.bifrost.origo.is/en-us/licensing/eula/ |
| Þjónusta | https://www.origo.is/ |

Athugið: Í `app.json` Foundation vísa persónuverndarstefna og EULA á `docs.bifrost.origo.is`. Í `app.json` þessa forrits vísa þær enn á `businesscentralal.github.io/bifrost/en-us/foundation/`. Skráningin notar slóðir Foundation; samræma má `app.json` síðar (þar með talið `help` slóðir) ef eigandi útgefandaaðgangs samþykkir.

## Skjámyndir (aðeins lýsingar; myndir á eftir að taka)

1. **Listi yfir mállíkön** - listinn yfir Bifröst mállíkön með nokkrum veitum.
2. **Spjald mállíkans** - veita, endapunktur, líkan, mörk og færnitexti, ásamt aðgerðum fyrir sameiginlegan og persónulegan API-lykil.
3. **Uppsetningarsíða** - uppsetningarsíða Bifröst mállíkana sem sýnir fjölda líkana, sjálfgefið líkan og hve mörg vantar enn API-lykil.
4. **Spjall á viðskiptamannaspjaldi** - Upplýsingaglugginn Bifröst spjall svarar spurningu um viðskiptamanninn sem er opinn.
5. **Spjall á lista yfir sölupantanir** - glugginn á listasíðu.
6. **Uppsetning notanda** - reiturinn Kóði mállíkans í Uppsetningu notanda Bifröst.
