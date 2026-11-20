# Kroegentocht HHC '09 – scorebord

## Mappen
- `public/index.html` – de app (één bestand). Praat live met Supabase (project HHCdatabase).
- `public/icon.png`, `public/manifest.webmanifest` – icoon en "zet op beginscherm".
- `vercel.json` – Vercel-instellingen (geen build nodig, map `public` wordt online gezet).
- `supabase/beveiliging_sessies.sql` – **aangeraden** beveiligingsupdate (zie hieronder).
- `supabase/opruimen_supabase.sql` – verwijdert na afloop alles uit Supabase.
- PDF's (kaartjes) staan in de hoofdmap en worden **niet** online gezet.

## Online zetten op Vercel
**Optie A – via GitHub (aangeraden, elke wijziging gaat automatisch live)**
1. Maak een (privé) repository op GitHub en zet deze map erin (bijv. met GitHub Desktop).
2. Ga naar vercel.com > Add New > Project > kies de repository.
3. Framework Preset: **Other**. Verder niets invullen (alles staat in `vercel.json`). Klik Deploy.
4. Vanaf nu: elke push naar GitHub = binnen ±20 seconden live.

**Optie B – zonder GitHub**
1. `npx vercel` in deze map (eerste keer inloggen), daarna `npx vercel --prod` om live te zetten.

## Links
| Link | Wat |
|---|---|
| `/` of `/#scorebord` | ranglijst voor iedereen |
| `/teams` | checklist per team |
| `/beheer` | logboek, teams, kaartjes, gebruikers, instellingen |
| `/beamer` | ranglijst groot op een tv/beamer (scherm blijft aan) |

Oude links met `scorebord.html` sturen automatisch door.

## Is alles live?
- **Scores**: ja. Elk scherm haalt elke 3 seconden de stand op uit Supabase (ook direct na terugkomen in de app of na herstel van de verbinding). Onderaan de ranglijst staat een groen bolletje met "bijgewerkt X s geleden".
- **Code**: de html wordt niet gecachet (`no-cache`), dus na een nieuwe deploy krijgt iedereen bij herladen meteen de nieuwe versie.

## Beveiliging (belangrijk als de link openbaar is)
Nu kan iemand met technische kennis via de API alle 10.000 pincodes van 4 cijfers proberen.
Plak `supabase/beveiliging_sessies.sql` in de Supabase SQL-editor om dat te verhelpen:
na 8 foute pogingen wordt een IP 10 minuten geblokkeerd en de app gebruikt daarna een onraadbare sessiecode.
De app werkt met én zonder dit script; na het uitvoeren moet iedereen één keer opnieuw inloggen.

## Pincodes
Er is één beheerder-pincode en één pincode per spelersraadlid/team.
De pincodes staan **niet** in deze (openbare) repository, maar alleen lokaal in `PINCODES.md` en in Beheer > Gebruikers.

## Na afloop opruimen
1. Beheer > Instellingen > "Download back-up (JSON)".
2. Plak `supabase/opruimen_supabase.sql` in de Supabase SQL-editor en voer uit.
3. Verwijder eventueel het project in Vercel.
