# RuuviTempWatch

watchOS-sovellus RuuviTag-anturin lämpötilan näyttämiseen Apple Watchissa **Ruuvi Cloud API:n** kautta. Sovellus sisältää WidgetKit-komplikaation accessoryCircular-muodossa.

## Ominaisuudet

- 🌡️ Näyttää RuuviTag-anturin lämpötilan Celsius-asteina
- ☁️ Käyttää Ruuvi Cloud APIa (vaatii internetyhteyden)
- ⌚ Natiivi watchOS-sovellus Montserrat-fontilla
- 🔄 Automaattinen päivitys ~15 minuutin välein
- 🎯 Komplikaatiot kellotauluun:
  - **accessoryCircular** - Pieni pyöreä (ylä/alarivi, 3 kpl)
  - **accessoryCorner** - Kulmawidget
  - **accessoryRectangular** - Suorakaide keskellä
- 🔐 Turvallinen tokenin tallennus Keychainiin
- 📊 Näyttää myös kosteuden, paineen ja akun tilan
- ⚙️ Asetukset Access Tokenin ja MAC-osoitteen muuttamiseen
- 🔧 Tukee Ruuvi Cloud offset-kalibrointeja

## Ruuvi Cloud API

Sovellus käyttää Ruuvi Cloud APIa datan hakemiseen:

### Yhteys
- Osoite: `https://network.ruuvi.com/sensors-dense?measurements=true`
- Autentikointi: Bearer token
- Internetyhteys vaaditaan

### Access Token hankinta
1. Rekisteröidy: 
   ```bash
   curl -X POST https://network.ruuvi.com/register \
     -H 'Content-Type: application/json' \
     -d '{"email":"your@email.com"}'
   ```
2. Vahvista sähköpostiin tuleva koodi
3. Käytä saatua tokenia sovelluksessa

### Vastausmuoto
API palauttaa RAWv2-formaatissa hex-dataa:
```json
{
  "result": "success",
  "data": {
    "sensors": [{
      "sensor": "EF:AF:84:20:B1:82",
      "name": "Ulkoilma",
      "measurements": [{
        "data": "0201061BFF9904050EB76FDCCA170048FFE004207F1685FABEEFAF8420B182",
        "rssi": -60,
        "timestamp": 1737037888
      }],
      "offsetTemperature": 0,
      "offsetHumidity": 0,
      "offsetPressure": 0
    }]
  }
}
```

## RAWv2-lämpötilan dekoodaus

RuuviTag lähettää dataa RAWv2-formaatissa (Data Format 5). Sovellus etsii `990405` headerin ja parsii sen jälkeiset tavut:

### Datan rakenne (headerin jälkeen)
- **Tavut 0-1: Lämpötila** (signed int16) × 0.005 °C
- **Tavut 2-3: Kosteus** (uint16) × 0.0025 %RH
- **Tavut 4-5: Paine** (uint16 + 50000) / 100 hPa
- **Tavut 12-13: Akku & TX-teho** (bat = (raw >> 5) + 1600 mV)

### Esimerkkejä
- `0EB7` → 3767 × 0.005 = 18.835 °C
- `01C3` → 451 × 0.005 = 2.255 °C
- `FE70` → -400 × 0.005 = -2.0 °C

## Projektin rakenne

```
RuuviTempWatch/
├── RuuviTempWatch Watch App/
│   ├── RuuviTempWatchApp.swift      # Pääsovellus ja taustapäivitys
│   ├── ContentView.swift            # Päänäkymä lämpötilan näyttämiseen
│   ├── OnboardingView.swift         # Ensikäynnistyksen asetukset
│   ├── SettingsView.swift           # Asetusnäkymä
│   ├── RuuviAPIClient.swift         # Ruuvi Cloud API-kommunikaatio
│   ├── HexParser.swift              # RAWv2-datan parsinta (990405 header)
│   ├── TemperatureWidget.swift      # WidgetKit-komplikaatio (kommentoitu)
│   ├── Info.plist                   # Sovelluksen konfiguraatio
│   └── Assets.xcassets/
│       └── Montserrat-Bold.ttf      # Mukautettu fontti
├── Tests/
│   └── HexParserTests.swift         # Unit-testit hex-parsinnalle
├── RuuviTempWidgetCode.swift        # Valmis widget-koodi (standalone)
└── WIDGET_SETUP_GUIDE.md            # Widget-asennusohjeet
```

## Widget-toteutus

Projekti sisältää valmiin widget-koodin (`RuuviTempWidgetCode.swift`), joka tarjoaa:

- **Kolme widget-tyyppiä:**
  - `accessoryCircular` - Pieni pyöreä widget (3 kpl rivissä)
  - `accessoryCorner` - Kulmawidget (vasen/oikea yläkulma)  
  - `accessoryRectangular` - Suorakaide-widget (keskellä)

- **Ominaisuudet:**
  - Lämpötilan, kosteuden ja akun tilan näyttö
  - Automaattinen päivitys 15 min välein
  - Virhetilojen käsittely (verkkovirheet, token-ongelmat)
  - Debug-tilassa kovakoodatut tunnukset kehitykseen
  - Tuki UserDefaults-konfiguraatiolle ja Keychain-tallennukselle

- **Käyttöönotto:**
  - Kopioi koodi uuteen Widget Extension -targetiin
  - Lisää App Group (`group.com.ruuvitempwatch`)
  - Katso yksityiskohtaiset ohjeet: `WIDGET_SETUP_GUIDE.md`

## Asennus ja käyttö

### ⚠️ Tärkeät esivalmistelut

1. **Lisää App Icon -kuvakkeet:**
   - Katso ohjeet: `Assets.xcassets/AppIcon.appiconset/LUEMIN_KUVAKKEET_PUUTTUVAT.md`
   - Voit käyttää Bakery-sovellusta tai appicon.co-palvelua
   - Tai poista väliaikaisesti AppIcon-vaatimus Build Settings → App Icon Set Name

2. **Lisää Montserrat-Bold fontti:**
   - Lataa: https://fonts.google.com/specimen/Montserrat
   - Korvaa placeholder: `Assets.xcassets/Montserrat-Bold.ttf`

3. **Hanki Ruuvi Cloud Access Token:**
   - Rekisteröidy sähköpostilla API:in
   - Vahvista sähköpostiin tuleva koodi
   - Tallenna token turvallisesti

### Käynnistys

1. Avaa projekti Xcodessa
2. Valitse Watch App -kohde
3. Build & Run Apple Watchille (⌘R)
4. ~~Syötä Ruuvi Cloud Access Token ja MAC-osoite ensikäynnistyksessä~~

**HUOM:** Kehitysvaiheessa (DEBUG) käytetään kovakoodattuja arvoja:
- Token: `753130313934/p9vdCYTTJDRxz5J3tmHfpgYm4J5ZlnGHrRqXshypwPyTm4sN3zkGrcp9vfcllvt5`
- MAC: `EF:AF:84:20:B1:82`
- Onboarding ohitetaan automaattisesti

## Taustapäivitys

Sovellus rekisteröi BGAppRefreshTask-tehtävän, joka:
- Pyytää päivitystä ~15 minuutin välein
- watchOS säätää lopullisen aikataulun akun ja käytön mukaan
- Päivitys tapahtuu taustalla ilman sovelluksen avaamista

## Virheenkäsittely

Sovellus käsittelee seuraavat virhetilanteet:
- 401: Virheellinen Access Token
- 403: Ei oikeuksia anturiin
- 404: Palvelin ei vastaa
- 429: Liikaa pyyntöjä (rate limit)
- Verkkovirheet ja timeout (30s)
- Virheellinen data tai puuttuva header

## Unit-testit

Projekti sisältää kattavat unit-testit HexParser-luokalle, jotka testaavat:
- RAWv2 headerin (990405) tunnistus
- Positiiviset ja negatiiviset lämpötilat
- Ääriarvot (min/max)
- Virheelliset syötteet
- Eri muotoilut (välilyönnit, isot/pienet kirjaimet)

## Versiohistoria

- **v1.1.0** (2025-01-17)
  - Vaihdettu Ruuvi Cloud API:n käyttöön
  - Korjattu RAWv2 hex-datan parsinta (990405 header)
  - Lisätty offset-kalibrointien tuki
  - Parannettu virheenkäsittelyä
  - Päivitetty dokumentaatio
  - Lämpötila ja astemerkki samalle riville

- **v1.0.0** 
  - Alkuperäinen julkaisu paikallisella gateway-tuella

## Lisenssi

MIT License