# API Token Security Guidelines

## ⚠️ TÄRKEÄÄ: Tokenien turvallisuus

### Älä koskaan:
- ❌ Commitoi todellisia API-tokeneita GitHubiin
- ❌ Kovakoodaa tokeneita Swift-koodiin
- ❌ Jaa tokeneita julkisesti

### Tee aina:
- ✅ Käytä Keychain-tallennusta tokeneille
- ✅ Pyydä käyttäjältä token ensikäynnistyksessä
- ✅ Käytä ympäristömuuttujia kehityksessä
- ✅ Dokumentoi vain esimerkkitokeneita

## Nykyinen toteutus

### 1. Tokenien tallennus (turvallinen)
```swift
// RuuviAPIClient.swift
@AppStorage("ruuvi_access_token") private var accessToken = ""

// OnboardingView.swift
saveToKeychain(key: "ruuvi_access_token", value: accessToken)
```

### 2. Kehitysympäristö
- Tokenit ovat `.env.local` tiedostossa (ei commitoida)
- Käyttäjä syöttää tokenin ensikäynnistyksessä
- Token tallennetaan Keychainiin

### 3. Dokumentaatiossa
- README:ssä on esimerkkitokenit (OK)
- Nämä ovat kehityskäyttöön
- Production-tokenit eivät saa näkyä missään

## Token-tyypit

### Read-only token
- Vain lukuoikeudet
- Käytetään normaalisti sovelluksessa
- Turvallisempi vaihtoehto

### Read/write token
- Luku- ja kirjoitusoikeudet
- Käytetään vain tarvittaessa
- Suurempi turvallisuusriski

## Suositukset

### 1. Kehitysvaihe
```bash
# Käytä .env.local tiedostoa (ei commitoida)
source .env.local
echo $RUUVI_READONLY_TOKEN
```

### 2. TestFlight/Beta
- Luo erilliset beta-tokenit
- Rajoita käyttöoikeudet
- Monitoroi käyttöä

### 3. Production
- Luo production-spesifiset tokenit
- Käytä token rotation -käytäntöä
- Implementoi token expiry

## Token Rotation

### Suunnitelma:
1. Tokenit vanhenevat 90 päivän välein
2. Käyttäjä saa ilmoituksen 7 päivää ennen
3. Uusi token syötetään asetuksissa
4. Vanha token poistetaan Keychainista

## Hätätilanne

Jos token vuotaa:
1. Revokoi token välittömästi Ruuvi-palvelussa
2. Päivitä sovellus uudella tokenilla
3. Ilmoita käyttäjille
4. Analysoi vuodon syy

## Tarkistuslista ennen committia

- [ ] Onko .gitignore ajan tasalla?
- [ ] Onko .env.local .gitignoressa?
- [ ] Onko koodissa kovakoodattuja tokeneita?
- [ ] Onko README:ssä vain esimerkkitokeneita?
- [ ] Toimiiko Keychain-tallennus?

## Kehitysvinkit

### Mock-token testaukseen:
```swift
#if DEBUG
let mockToken = "MOCK_TOKEN_FOR_TESTING_ONLY"
#endif
```

### Environment-based tokens:
```swift
enum Environment {
    case development
    case staging  
    case production
    
    var apiToken: String? {
        // Palauta nil, pakota käyttäjä syöttämään
        return nil
    }
}
```