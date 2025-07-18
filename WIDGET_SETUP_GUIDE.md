# Widget Setup Guide - Komplikaation lisääminen kellotauluun

## 🎯 Tavoite
Lisätä RuuviTemp-lämpötila komplikaationa Apple Watch kellotauluun. Komplikaatio näkyy pienenä pyöreänä elementtinä ylä- tai alarivillä.

## 📱 Tuetut komplikaatiotyypit
- **accessoryCircular** - Pieni pyöreä (ylä/alarivi, 3 kpl rivissä)
- **accessoryCorner** - Kulma (vasen/oikea yläkulma)
- **accessoryRectangular** - Suorakaide (keskellä)

## 🛠️ Widget Extension lisääminen

### 1. Luo uusi Widget Extension target
1. Xcode: **File → New → Target**
2. Valitse: **watchOS → Widget Extension**
3. Asetukset:
   - Product Name: `RuuviTempWidget`
   - Team: Valitse kehitystiimisi
   - Language: Swift
   - ✅ Include Configuration Intent (jos haluat konfiguroitavia widgettejä)
4. Klikkaa **Finish**
5. Aktivoi schema kun Xcode kysyy

### 2. Kopioi widget-koodi
1. Avaa `RuuviTempWidgetCode.swift` (projektin juuressa)
2. Kopioi kaikki koodi tiedostosta
3. Korvaa automaattisesti luotu `RuuviTempWidget.swift` tällä koodilla

### 3. Lisää tarvittavat tiedostot targettiin
Widget-koodi on standalone-toteutus, joten tarvitaan vain:

1. Valitse **RuuviTempWidget** target Xcodessa
2. **Build Phases → Compile Sources → +**
3. Lisää tarvittaessa `SharedModels.swift` jos siinä on `RuuviConfiguration`-struct
4. Widget sisältää oman `WidgetAPIClient`-toteutuksen, joka on optimoitu widgetkäyttöön
   - ✅ Ei @MainActor-riippuvuuksia
   - ✅ Yksinkertaistettu virheenkäsittely
   - ✅ Tuki UserDefaults ja Keychain-konfiguraatiolle

### 4. Päivitä Info.plist
Lisää Widget Extensionin `Info.plist`-tiedostoon:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Widget tarvitsee pääsyn paikalliseen verkkoon Ruuvi Gatewayn yhteyttä varten</string>
```

### 5. Konfiguroi App Group (valinnainen)
Jos haluat jakaa asetukset pääsovelluksen kanssa:

1. Valitse **RuuviTempWidget** target
2. **Signing & Capabilities → + Capability → App Groups**
3. Lisää `group.com.ruuvitempwatch`
4. Varmista että sama App Group on myös pääsovelluksessa

Widget-koodi tukee automaattisesti:
- UserDefaults-konfiguraatiota App Groupin kautta
- Keychain-tallennusta
- Debug-tilassa kovakoodattuja arvoja

## 🎨 Komplikaation ulkoasu

### accessoryCircular (Pieni pyöreä)
```swift
var accessoryCircularView: some View {
    ZStack {
        Circle()
            .fill(Color.black.opacity(0.2))
        
        VStack(spacing: 0) {
            Text("\(temperature, specifier: "%.1f")")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("°C")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}
```

### accessoryCorner (Kulma)
```swift
var accessoryCornerView: some View {
    HStack(spacing: 2) {
        Image(systemName: "thermometer")
            .font(.system(size: 14))
        
        Text("\(temperature, specifier: "%.1f")°")
            .font(.system(size: 16, weight: .semibold))
    }
    .foregroundColor(.white)
}
```

### accessoryRectangular (Suorakaide)
```swift
var accessoryRectangularView: some View {
    HStack {
        VStack(alignment: .leading) {
            Text("Ulkoilma")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text("\(temperature, specifier: "%.1f") °C")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
        
        Spacer()
        
        Image(systemName: "thermometer")
            .font(.system(size: 24))
            .foregroundColor(.blue)
    }
}
```

## 📲 Komplikaation lisääminen kellotauluun

### 1. Build ja asenna
1. Valitse **RuuviTempWidget** schema
2. Build and Run (⌘R)
3. Valitse Apple Watch kohde

### 2. Lisää kellotauluun
1. Paina pitkään kellotaulua Apple Watchissa
2. Valitse **Edit**
3. Paina komplikaatiopaikkaa (esim. ylärivi)
4. Vieritä ja etsi **RuuviTemp**
5. Valitse se
6. Paina Digital Crown tallentaaksesi

## 🔧 DEBUG-tila widgetissä

Widget käyttää samoja kovakoodattuja arvoja DEBUG-tilassa:

```swift
#if DEBUG
let token = "dT5ObtUF/OV6lxhBE2EcxP+lgn715akLrn9Qe/TMTaE="
let macAddress = "EF:AF:84:20:B1:82"
#else
let token = loadFromKeychain(key: "ruuvi_access_token") ?? ""
let macAddress = UserDefaults.standard.string(forKey: "ruuvi_mac_address") ?? ""
#endif
```

## ⚠️ Muista
- Widget päivittyy ~15 minuutin välein
- watchOS rajoittaa päivitystiheyttä akun säästämiseksi
- Voit pakottaa päivityksen avaamalla pääsovelluksen
- Widget toimii vain kun iPhone on lähellä

## 🐛 Vianetsintä

### "Widget ei näy valikossa"
1. Varmista että widget on asennettu: Xcode → Product → Clean Build Folder
2. Poista ja asenna sovellus uudelleen
3. Käynnistä Apple Watch uudelleen

### "Näyttää vain --.-"
1. Tarkista että gateway vastaa: `curl http://192.168.1.39/history`
2. Varmista että token ja MAC ovat oikein (DEBUG-tilassa kovakoodattu)
3. Avaa pääsovellus kerran (luo keychain-arvot)

### "Ei päivity"
1. Normaalia - watchOS rajoittaa päivityksiä
2. Avaa pääsovellus pakottaaksesi päivitys
3. Tarkista että iPhone on Bluetooth-kantamassa

## 📝 Huomioita uudesta toteutuksesta

`RuuviTempWidgetCode.swift` sisältää:
- Standalone Widget Extension -koodin
- Optimoitu `WidgetAPIClient` (ei @MainActor-riippuvuuksia)
- Kolme widget-tyyppiä (circular, corner, rectangular)
- Automaattinen virheenkäsittely ja placeholder-tila
- Tuki sekä UserDefaults- että Keychain-konfiguraatiolle
- Debug-tilassa kovakoodatut tunnukset kehitykseen