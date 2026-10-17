# Skráning - Bifröst mállíkön (is-IS)

## Auðkenni tilboðs

| Reitur | Gildi |
| --- | --- |
| Heiti tilboðs | Bifröst mállíkön |
| Heiti forrits (app.json) | Bifrost Language Models |
| Auðkenni forrits | `f1722684-0c24-4022-a2e0-0f63154aca76` |
| Útgefandi | Origo (sami útgefandi og Bifrost Foundation) |
| Útgáfa | Núverandi útgáfa í `app/app.json` (sett við útgáfu) |
| Nauðsynlegt forrit | Bifrost Foundation, í lágmarksútgáfunni sem `app/app.json` tilgreinir (`7505e808-6e52-4b96-a328-82573391297a`) |
| Vörunúmer (product id) | _Eigandi útgefandaaðgangs Origo fyllir út þegar tilboðið er til_ |

## Stutt samantekt (hámark 100 stafir)

```
Spjallaðu við Business Central með OpenAI, Anthropic, Gemini, xAI, Azure OpenAI eða Copilot.
```

## Lýsing (einfalt HTML; Partner Center birtir ekki Markdown, hámark 3000 stafir með merkjum)

```html
<p>Bifröst mállíkön bæta spjallglugga við þær síður í Business Central þar sem hann gagnast. Notendur biðja aðstoðarmanninn að finna upplýsingar eða vinna verk í Business Central, af þeirri síðu sem þeir eru að vinna á, með þeim gervigreindarveitanda sem fyrirtækið velur. Aðstoðarmaðurinn vinnur með gögn notandans sjálfs og með þeim réttindum sem hann hefur.</p>
<p>Forritið byggir á Bifrost Foundation, sem sér um sjálft spjallið og gerir aðstoðarmanninum kleift að lesa og vinna með gögn í Business Central. Bifröst mállíkön sjá um mállíkönin sjálf.</p>
<p><b>Hvað færðu</b></p>
<ul>
<li><b>Mállíkön.</b> Eitt mállíkan í hverri línu: spjallveitandi, endapunktur, líkan, mörk (tímamörk, hámarksfjöldi tákna og samhengistákn) og hæfniefni sem verður hluti af kerfisfyrirmælum.</li>
<li><b>Nokkrir gervigreindarveitendur.</b> Copilot, OpenAI, Azure OpenAI, sérsniðið LLM, Anthropic, xAI og Google (Gemini).</li>
<li><b>Spjall þar sem þú vinnur.</b> Upplýsingaglugganum Bifröst spjall er bætt við á síður viðskiptamanna, lánardrottna, vara, sölu, innkaupa, færslna og innkominna skjala.</li>
<li><b>Mállíkan fyrir hvern notanda.</b> Kerfisstjóri úthlutar hverjum notanda mállíkani í Uppsetningu notanda Bifröst. Bifröst spjall birtist aðeins notendum sem hafa fengið mállíkan.</li>
<li><b>Einskiptisbeiðnir.</b> Sendu eina fyrirspurn til stillta líkansins og fáðu textann til baka, til notkunar í sjálfvirkni og tímasettum verkum.</li>
</ul>
<p><b>Lyklar og réttindi</b></p>
<ul>
<li>API-lyklar eru geymdir í leyndarmálageymslu Bifrastar.</li>
<li>Hver notandi getur sett inn persónulegan API-lykil, sem hefur forgang yfir sameiginlega lykilinn. Umsjón með sameiginlegum fyrirtækjalykli er sérstök heimildasamstæða (<code>BIFROST ChatSvc ori</code>) og því má fela hana öðrum án þess að veita aðgang að spjallinu.</li>
<li>Aðstoðarmaðurinn vinnur með réttindum innskráða notandans í Business Central.</li>
</ul>
<p><b>Kröfur</b></p>
<ul>
<li>Business Central í skýinu (SaaS).</li>
<li>Bifrost Foundation, sett upp frá AppSource.</li>
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
| Notkunarskilmálar | https://docs.bifrost.origo.is/en-us/licensing/eula/ |
| Þjónusta | https://www.origo.is/ |

Athugið: Í `app.json` Foundation vísa persónuverndarstefna og notkunarskilmálar á `docs.bifrost.origo.is`. Í `app.json` þessa forrits vísa þær enn á `businesscentralal.github.io/bifrost/en-us/foundation/`. Skráningin notar slóðir Foundation; samræma má `app.json` síðar (þar með talið `help` slóðir) ef eigandi útgefandaaðgangs samþykkir.

## Skjámyndir (aðeins lýsingar; myndir á eftir að taka)

Takið þær í prófunarumhverfi með sýnigögnum: fyrirtækið birtist sem CRONUS, notendur sem Example User, engin auðkenni leigjanda og engin raunveruleg persónu- eða fyrirtækjagögn.

1. **Listi yfir mállíkön** - listinn yfir Bifröst mállíkön með nokkrum veitum.
2. **Spjald mállíkans** - veita, endapunktur, líkan, mörk og hæfniefni, ásamt aðgerðum fyrir sameiginlegan og persónulegan API-lykil.
3. **Uppsetningarsíða** - uppsetningarsíða Bifröst mállíkana sem sýnir fjölda líkana, sjálfgefið líkan og hve mörg vantar enn API-lykil.
4. **Spjall á viðskiptamannaspjaldi** - Upplýsingaglugginn Bifröst spjall svarar spurningu um viðskiptamanninn sem er opinn.
5. **Spjall á lista yfir sölupantanir** - glugginn á listasíðu.
6. **Uppsetning notanda** - reiturinn Kóði mállíkans í Uppsetningu notanda Bifröst.
