# Kroegentocht HHC '09 – scorebord

## Mappen
- `public/index.html` – de app (één bestand). Praat via `/api/rpc` met de database.
- `api/rpc.js` – Vercel-serverfunctie die aanvragen doorstuurt naar Supabase. Het Supabase-adres en de sleutel staan alleen in de omgevingsvariabelen, niet in de code of de browser.
- `.env` – (alleen lokaal, niet op GitHub) `SUPABASE_URL`, `SUPABASE_KEY` en `KT_PIN`. Voorbeeld: `.env.example`.
- `public/icon.png`, `public/manifest.webmanifest` – icoon en "zet op beginscherm".
- `vercel.json` – Vercel-instellingen (geen build nodig, map `public` wordt online gezet).
- `supabase/opruimen_supabase.sql` – verwijdert na afloop alles uit Supabase.
- PDF's (kaartjes) staan in de hoofdmap en worden **niet** online gezet.

## Online zetten op Vercel
**Optie A – via GitHub (aangeraden, elke wijziging gaat automatisch live)**
1. Repository: https://github.com/joeydf12/kroegentocht
2. Ga naar vercel.com > Add New > Project > kies de repository.
3. Framework Preset: **Other**.
4. Klap **Environment Variables** open en plak de inhoud van `.env` erin (Vercel herkent `NAAM=waarde`-regels en maakt er automatisch losse variabelen van). Klik Deploy.
5. Vanaf nu: elke push naar GitHub = binnen ±20 seconden live.

Wijzig je later een variabele (Settings > Environment Variables), doe dan Deployments > ⋯ > Redeploy.

**Optie B – zonder GitHub**
1. `npx vercel` in deze map (eerste keer inloggen), `npx vercel env add` voor de drie variabelen, daarna `npx vercel --prod`.

## Links
| Link | Wat |
|---|---|
| `/` of `/#scorebord` | ranglijst voor iedereen |
| `/teams` | checklist en spellen per team (afvinken en punten invullen) |
| `/beheer` | logboek, teams, kaartjes, instellingen – staat niet in het menu, alleen via deze link |
| `/beamer` | ranglijst groot op een tv/beamer (scherm blijft aan) |

Oude links met `scorebord.html` sturen automatisch door.

## Is alles live?
- **Scores**: ja. Elk scherm haalt elke 3 seconden de stand op uit Supabase (ook direct na terugkomen in de app of na herstel van de verbinding). Onderaan de ranglijst staat een groen bolletje met "bijgewerkt X s geleden".
- **Code**: de html wordt niet gecachet (`no-cache`), dus na een nieuwe deploy krijgt iedereen bij herladen meteen de nieuwe versie.

## Geen pincodes
Er hoeft niemand in te loggen: iedereen die de link heeft kan afvinken en punten invullen, en via `/beheer` ook alles beheren.
Dat werkt doordat de serverfunctie (`api/rpc.js`) zelf de beheerderspincode uit `KT_PIN` invult; die komt nooit in de browser.
Deel de link daarom alleen met de spelersraad. Op de beamer kun je gewoon het scorebord laten zien.
In het logboek staat bij elke actie "Beheerder", omdat iedereen via dezelfde pincode werkt.

Let op: verander de beheerderspincode niet in de database (of pas dan ook `KT_PIN` in Vercel aan en doe een Redeploy), anders kan niemand meer iets wijzigen.

## Na afloop opruimen
1. Beheer > Instellingen > "Download back-up (JSON)".
2. Plak `supabase/opruimen_supabase.sql` in de Supabase SQL-editor en voer uit.
3. Verwijder eventueel het project in Vercel.
