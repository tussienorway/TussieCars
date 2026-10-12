# TussieCars – bruksanvisning

TussieCars er et arkadespill med kampbilløp i 3D. Du kjører mot fem andre biler på 16 baner, skyter missiler, legger miner og kjemper om premiepenger, poeng og plass på premiepallen. Maskoten Tussie, en rød og hvit langhåret katt, sitter ved hver startlinje og følger med.

Spillet finnes for Windows, Android-mobil og Meta Quest (VR). Menyene i spillet er på engelsk. Under **How to Play** i hovedmenyen finner du en kort versjon av denne bruksanvisningen.

---

## 1. Last ned og installer

Du kan [spille i nettleseren](https://tussienorway.github.io/TussieCars/) uten å installere noe. Flerspiller og Quest-appen finnes i de nedlastbare versjonene på [release-siden](https://github.com/tussienorway/TussieCars/releases/latest).

### Windows
1. Last ned `TussieCars-Windows-Setup.exe`.
2. Dobbeltklikk filen. Hvis Windows viser «Windows beskyttet PCen din», trykker du **Mer info** og deretter **Kjør likevel**. Advarselen kommer fordi spillet ikke er signert av en kjent utgiver.
3. Installasjonen legger en snarvei på skrivebordet og i Start-menyen. **TussieCars VR** starter PC VR (Quest Link, Air Link eller SteamVR). Uten hodesett starter spillet som vanlig.

### Android-mobil
1. Last ned `TussieCars.apk` på telefonen.
2. Åpne filen. Telefonen spør om du vil tillate installering fra denne kilden. Si ja.
3. Start **TussieCars** fra appskuffen. Spillet kjøres liggende.

### Meta Quest 3 (og Quest 2, 3S og Pro)
1. Slå på **utviklermodus**: åpne Meta Horizon-appen på mobilen og gå til *Enheter → headsetet ditt → Headset-innstillinger → Utviklermodus*. Meta krever at du lager en gratis utviklerkonto første gang.
2. Koble headsetet til PC-en med en USB-C-kabel. Ta på headsetet og trykk **Tillat** når det spør om USB-feilsøking.
3. Installer `TussieCars-Quest.apk` på én av disse måtene:
   - Med [SideQuest](https://sidequestvr.com): dra APK-filen inn i vinduet.
   - Med kommandolinjen: `adb install -r TussieCars-Quest.apk`
4. I headsetet åpner du **Bibliotek**, velger filteret **Ukjente kilder** og starter **TussieCars VR**.

### PC VR (Quest Link, Air Link eller SteamVR)
Start Quest Link eller SteamVR først, og dobbeltklikk deretter `TussieCars-VR.bat` i Windows-mappen. Uten VR starter spillet som vanlig på skjermen.

---

## 2. Kontroller

### Tastatur
| Handling | Spiller 1 | Spiller 2 (delt skjerm) |
| --- | --- | --- |
| Gass | W eller pil opp | I |
| Brems og revers | S eller pil ned | K |
| Styr | A / D eller piltaster | J / L |
| Drift | Mellomrom | M |
| Nitro | Shift | N |
| Missil forover | C | U |
| Mine | X | O |
| Missil bakover | V | P |
| Pause | Esc | |

Du kan endre tastene under **Settings**.

### Håndkontroll (Xbox og lignende)
- Høyre avtrekker: gass. Venstre avtrekker: brems. Venstre stikke: styring.
- **Y**: nitro. Trykk inn venstre stikke: drift.
- **RB**: missil. **LB**: mine. **X**: missil bakover. **Start**: pause.

### Mobil (berøring)
- Venstre side: styrepute. Legg tommelen på puten og skyv mot venstre eller høyre.
- Høyre side: **ACCEL** (gass), **BRAKE**, **BOOST** (nitro), **DRIFT**, **FIRE** (missil), **MINE** og **REAR** (missil bakover).
- Telefonen vibrerer når du krasjer eller blir truffet.

### VR (Quest-kontrollere)
| Handling | Knapp |
| --- | --- |
| Gass | Høyre avtrekker |
| Brems | Venstre avtrekker |
| Styr | Hvilken som helst av stikkene |
| Nitro | A |
| Drift | B |
| Missil forover | Høyre grep |
| Mine | Venstre grep |
| Missil bakover | X |
| Bytt kamera (jaktkamera eller takkamera) | Y |
| Pause | Meny-knappen (venstre kontroller) |
| Sentrer bildet på nytt | Hold inne Meta-knappen |

I menyene peker du med kontrolleren og trykker avtrekkeren for å klikke. Stikken scroller. Når du pauser et løp, kommer laserne tilbake så du kan velge **Resume**, **Retire** eller **Quit race**.

**Tips for VR:** Begynn med **jaktkameraet** (standard). Det er mest komfortabelt. Takkameraet er mer intenst. Du kan bytte under *Settings → VR camera*, eller med Y-knappen mens du kjører.

---

## 3. Slik kjører du

- **Mål:** kom først over målstreken. De fleste baner har tre runder, og rundetelleren står øverst på skjermen. Du må kjøre gjennom alle sjekkpunktene i riktig rekkefølge, så snarveier teller ikke. Står det **WRONG WAY** i rødt, kjører du feil vei.
- **HUD-en øverst** viser plassering, runde, tid, skade (HP), nitro, ammunisjon og fart. Kartet nede til høyre viser deg som gul prikk og motstanderne som røde prikker.
- **Nitro:** den gule linjen er nitrotanken. Den fyller du på tre måter:
  - **Drift** gjennom svinger: hold drift-knappen mens du svinger.
  - **Slipstrøm:** legg deg rett bak en annen bil.
  - **Boost-felt** på veien og blå (cyan) kasser.
  
  Bruk nitroen på langsidene.
- **Skade:** autovernet er hardt. Krasjer du i fart, mister du HP, og du sliter på bilen hvis du skraper langs veggen. Ved 0 HP er bilen vraket, og du får ingen premie. Reparer i garasjen mellom løpene, for skaden blir med til neste løp.
- **Underlag:** olje gjør veien glatt, og vann og sand bremser deg. Gress og vegger stopper deg.
- **I regn** har du 20 % mindre veigrep. Brems tidligere.

### Våpen og kasser
| Kasse | Gir |
| --- | --- |
| Oransje | Missiler forover |
| Rød | Miner |
| Grønn | Reparasjon |
| Blå (cyan) | Nitro |

Missiler går rett fram, bakovermissiler tar biler som ligger bak deg, og miner blir liggende der du slipper dem.

### Målgang og premiepall
Når du krysser målstreken, glir svarte filmstriper inn og kameraet sirkler rundt bilen din mens plassering og tid vises. Etterpå vises **premiepallen**: de tre beste bilene står på gull, sølv og bronse med navneskilt, Tussie sitter ved siden av, og det regner konfetti. Deretter kommer resultatskjermen.

---

## 4. Spillmoduser

### Karriere (New Career)
1. Velg navn og vanskelighetsgrad: **Rookie** (snillere motstandere), **Pro** (normal) eller **Ace** (raskere motstandere og høyere premier).
2. Du starter i en **Sprint Dart** med 2 800 dollar.
3. Hvert løp koster startavgift. Du vinner premiepenger og poeng etter plassering, men får ingen premie hvis bilen blir vraket.
4. Kommer du blant de tre beste sammenlagt i en serie, låser du opp neste serie: **Club Cup → National Series → Turbo Championship → Masters Cup**.
5. **Rival Bounty:** i hvert løp har du en navngitt rival. Rivalen er merket rødt på banen og rosa på kartet. Slår du rivalen, får du en dusør på 40 % av vinnerpremien.
6. **Garage:** her kjøper du motor, toppfart, bremser, dekk, panser, karosseri (mer HP), missiler, miner, bakovermissiler, ammo-stativ og pit-verktøy. Senere kan du kjøpe nye biler: **Harbor Viper**, **Iron Mule** og **Night Fang**. Her reparerer du også bilen.

**Continue** fortsetter karrieren du har lagret. Spillet lagrer automatisk.

### Exhibition
Et frittstående løp på hvilken som helst av de 16 banene, uten startavgift og uten poeng. Før du velger bane, kan du krysse av for:
- **Two players, split screen:** to spillere på samme skjerm (ikke i VR).
- **Rain:** regn og vått underlag.
- **Knockout:** ingen runder. Hvert 20. sekund blir bilen på sisteplass slått ut, og den siste bilen som står igjen, vinner.

### Daily Duel
Én ny utfordring hver dag: en fast bane med en vri, for eksempel natt, miner overalt, våpen til alle eller monsunregn. Du kjører mot ditt eget **spøkelse**, altså din beste tur fra tidligere samme dag. Kjører du hver dag, bygger du opp en rekke (streak).

### Multiplayer (flerspiller)
Opptil 4 personer kan kjøre sammen. Resten av feltet fylles med datastyrte biler.
- **Samme WiFi:** den ene trykker **QUICK HOST**. De andre åpner **Multiplayer** og trykker på lobbyen som dukker opp. Du trenger ikke skrive IP-adresse.
- **Over internett:** gjesten skriver inn IP-adressen og porten (7777) til den som er vert, og trykker **Join**. Verten må kanskje åpne port 7777 i ruteren.
- Etter hvert løp kan dere kjøre omkamp. Spillet teller poeng i en **Party Grand Prix** så lenge dere spiller sammen.

Mobil, PC og Quest kan spille sammen på samme WiFi.

---

## 5. Innstillinger (Settings)
- **Master, Music, Effects:** lydvolum.
- **Fullscreen:** fullskjerm på PC.
- **Screen shake:** kameraet rister når du blir truffet. Slå det av hvis du blir uvel.
- **Graphics:** Auto, Low, Medium, High eller Ultra. Auto er Medium i nettleseren og High på Windows. Nettleseren hopper over effekter som Compatibility-renderereren ikke kan tegne.
- **VR camera:** jaktkamera eller takkamera. Vises bare i VR.
- **Touch controls:** auto, alltid på eller alltid av.
- **Tastebindinger:** klikk på en handling og trykk den nye tasten.

---

## 6. Gode tips
- Brems **før** svingen, ikke i den.
- Spar et missil til siste langside.
- Drift gjennom lange svinger for å fylle nitroen, og bruk den med en gang du er ute av svingen.
- Hold deg unna autovernet. Det er den vanligste grunnen til at bilen blir vraket.
- Kjøp **armor** og **hull** tidlig i karrieren. Da tåler bilen mer.
- Pass på rivalen. Dusøren gir mange ekstra penger.

---

## 7. Hvis noe ikke virker
| Problem | Løsning |
| --- | --- |
| Windows stopper programmet | Trykk «Mer info» og deretter «Kjør likevel». |
| Ser ikke lobbyen på WiFi | Trykk **Rescan**. Noen gjestenettverk blokkerer søk; skriv da inn IP-adressen til verten. |
| Quest: finner ikke spillet | Bibliotek → filteret **Ukjente kilder**. |
| Quest: bildet står skjevt | Hold inne Meta-knappen for å sentrere på nytt. |
| Quest: blir uvel | Bruk jaktkameraet, slå av Screen shake og ta pauser. |
| Mobil: knappene er for små eller vanskelige | Snu telefonen til liggende modus. Touch-kontrollene kan slås på eller av i Settings. |

---

## 8. For utviklere
Spillet er laget i **Godot 4.7.2** (GDScript). `README.md` forklarer hvordan du kjører spillet fra kildekoden, kjører testene (`godot --headless --path . -- --test`) og bygger Windows-, Android- og Quest-versjonene.
