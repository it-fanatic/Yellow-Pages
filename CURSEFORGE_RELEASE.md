# Yellow-Pages – CurseForge Release Package (English & German)

Dieses Dokument enthält alle fertigen Copy-&-Paste-Texte, Metadaten und die Schritt-für-Schritt-Anleitung für die Erstveröffentlichung (**v1.0.0**) von **Yellow-Pages** auf CurseForge.

---

## 1. CurseForge Submission Fields (Projekt-Erstellung)

### 📌 Project Metadata
* **Project Name:** `Yellow-Pages - Guild Crafting & Gathering Directory`
* **CurseForge Project ID:** `1823713`
* **Project Slug (URL):** `yellow-pages-guild-directory` *(oder `yellow-pages`)*
* **Short Description / Summary** *(max. 200 Zeichen)*:
> Guild profession & gathering directory with live AH/vendor cost calculator, bag/bank inventory check, automated AH/vendor shopping list, and clickable online & offline crafting orders!

* **Primary Category:** `Guild`
* **Secondary Categories:** `Professions`, `Tradeskill`, `Auction & Economy`, `Chat & Communication`
* **License:** `MIT License`
* **Project Avatar / Icon:** `icon.png` (400×400+ Quadratisches Projekt-Logo – falls du ein individuelles Logo möchtest, kann ich dir sofort eines generieren!)

---

### 📝 Full Project Description (Markdown für CurseForge – Englisch & Deutsch)

Kopiere den folgenden Block direkt in das **Description**-Feld auf CurseForge:

```markdown
# 📖 YELLOW-PAGES — The Guild Crafting & Gathering Directory 🛠️

**Yellow-Pages ("Die Gelben Seiten der Gilde")** turns your guild's professions into a seamless, interactive crafting and gathering network!

Browse every recipe and gatherable resource known across your entire guild, compare your own bag & bank materials against live **Auction House** and **NPC Vendor** prices, and send interactive crafting requests to both **online** and **offline** guild crafters — 100% standalone in-game!

---

## ✨ Key Features (English)

### 🛠️ 1. All Crafting, Gathering & Secondary Professions
* **Crafting Professions:** Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring.
* **Gathering Professions:** Herbalism, Mining (including Smelting), and Skinning — automatically unlocked by skill rank (`1–300`) without needing a crafting window!
* **Secondary Professions:** Cooking & First Aid.
* **Sorting & Filtering:** Filter by profession, item quality (Common to Legendary), online crafters, or search by recipe name or reagent; sort by Name, Level, or Quality.

### 💰 2. Smart Material Stock & Cost Calculator
* **Bag & Bank Check (`Have / Need`):** Automatically checks your bags and cached bank inventory (with native **Syndicator / Baganator** support).
* **Vendor vs. Auction House Pricing:** Built-in NPC vendor reagent database combined with live Auction House pricing via **Auctionator**, **TradeSkillMaster (TSM)**, or **Auctioneer**.

### ✉️ 3. Interactive 4-Step Crafting Orders (Online & Offline!)
1. **1-Click Request:** Select a recipe, choose your desired quantity, and click **Request** next to a guild crafter. Your existing material stock is transmitted automatically.
2. **Offline Crafter Relay (Store & Forward):** Want to request an item from an offline guild member? Just click **Request**! Yellow-Pages stores the order in the guild relay across online members and automatically delivers it to the crafter the moment they log in.
3. **Crafter Inspection & 4 Reply Options:** The crafter clicks `[Yellow-Pages: Open Request]` directly in chat to see what materials the requester has vs. the crafter's own bags & bank, and replies with a single click:
   * ✅ **All Mats Ready!** *(Crafter covers any missing materials)*
   * 📦 **Get Remaining Mats** *(Requester only buys what neither player has)*
   * 🎒 **Bring ALL Mats!** *(Requester provides all materials, even if the crafter has them in stock)*
   * ⏳ **Busy / No Time** *(Polite decline when in a dungeon/raid)*
4. **1-Click Confirmation:** The requester clicks `[Yellow-Pages: Confirm & Place Order]` in chat to seal the deal!

### 🛒 4. Automated AH/Vendor Shopping List & Crafter Order Queue
* **Shopping List Pop-Up (Requester):** Upon confirming an order, any missing materials are automatically placed on your **Shopping List**.
  * Opens automatically at the **Auction House** -> click any item to search it in the AH immediately!
  * Opens automatically at **NPC Vendors** -> click any vendor reagent to buy the exact needed quantity immediately!
* **Order Queue (Crafter):** Confirmed orders are added to the crafter's **Order List** and automatically tick off as **Done** when the item is crafted!

### 🌍 5. Bilingual & Multi-Client Ready
* Automatically detects **English (`enUS`/`enGB`)** and **German (`deDE`)** client locales.
* Built in the warm brown-and-gold **Forever Profession Trainer** aesthetic with quick-access side tabs and an integrated **Info & Guide** tab.

---

## 🇩🇪 Deutsche Beschreibung — Die Gelben Seiten der Gilde

**Yellow-Pages** vernetzt alle Handwerker, Sammler und Mitglieder deiner Gilde direkt im Spiel – komplett ohne externe Webseiten oder Zusatzprogramme!

### 🌟 Wichtigste Funktionen
* **Alle Berufe auf einen Blick:** Unterstützt alle 6 Haupt-Herstellungsberufe, die 3 Sammelberufe (**Kräuterkunde, Bergbau, Kürschnerei** – automatisch nach Skill-Stufe erkannt!) sowie **Kochkunst & Erste Hilfe**.
* **Material- & Kostenrechner:** Prüft deinen eigenen Taschen- und Bank-Bestand (inkl. *Syndicator / Baganator*) und berechnet feste Händler-Preise sowie aktuelle Auktionshaus-Preise (*Auctionator*, *TSM*, *Auctioneer*).
* **Interaktives Auftragssystem (Online & Offline):**
  * **Anfrage senden:** Übermittelt direkt deinen aktuellen Materialbestand an den Handwerker.
  * **Offline-Handwerker (Gilden-Relais):** Anfragen an Offline-Spieler werden gildenweit zwischengespeichert und dem Handwerker beim nächsten Login automatisch zugestellt!
  * **Klickbare Chat-Links:** Der Handwerker öffnet die Anfrage per Klick im Chat, sieht den Material-Abgleich mit seiner eigenen Tasche/Bank und antwortet mit einem Klick (*Alle Mats da!*, *Rest-Mats anfordern*, *Alle Mats anfordern* oder *Gerade keine Zeit*).
* **Automatische Einkaufsliste & Auftragsliste:**
  * Nach Klick auf `[Yellow-Pages: Auftrag bestätigen]` landen fehlende Materialien automatisch in deiner **Einkaufsliste**. Diese öffnet sich automatisch am **Auktionshaus** (1-Klick-Suche) und bei **Händlern** (1-Klick-Direktkauf)!
  * Beim Handwerker landet der Auftrag in der **Auftragsliste** und wird beim Herstellen automatisch als **Erledigt** abgehakt.

---

## ⌨️ Slash Commands / Chat-Befehle

| Command | Description (EN) | Beschreibung (DE) |
| :--- | :--- | :--- |
| `/yp` or `/yellowpages` | Toggle main window | Hauptfenster öffnen / schließen |
| `/yp scan` | Scan open profession window | Geöffnetes Berufsfenster scannen |
| `/yp sync` | Broadcast professions to guild | Gilden-Synchronisation starten |
| `/yp shop` | Toggle Shopping List | Einkaufsliste öffnen / schließen |
| `/yp orders` | Toggle Crafter Order Queue | Auftragsliste öffnen / schließen |
| `/yp info` | Open Info & Guide page | Info- & Anleitungs-Seite öffnen |
| `/yp reset` | Reset local guild database | Lokale Gilden-Datenbank zurücksetzen |
```

---

## 2. File Upload Details (Für den Tab "Files" auf CurseForge)

* **Upload-Datei:** [`YellowPages.zip`](file:///f:/Documents/Projekte/Yellow-Pages/YellowPages.zip) *(liegt fertig gepackt im Hauptordner `f:\Documents\Projekte\Yellow-Pages\YellowPages.zip`)*
* **Display Name / Version:** `Yellow-Pages v1.0.0`
* **Release Type:** `Release`
* **Changelog / Release Notes:**
```text
Yellow-Pages v1.0.0 — Initial Release!
- Complete guild profession & recipe directory with automatic P2P guild synchronization.
- Support for all Crafting Professions, Gathering Professions (Herbalism, Mining, Skinning auto-detected by skill rank), and Secondary Professions (Cooking, First Aid).
- Warm brown & gold "Forever Profession Trainer" UI design with right-side profession tabs, dynamic portrait, and integrated Info & Guide page.
- Live material & cost calculator with bag/bank inventory tracking (including Syndicator/Baganator support), fixed NPC vendor prices, and live Auction House prices (Auctionator, TSM, Auctioneer).
- 4-step interactive crafting order system via clickable chat links with 4 crafter reply options.
- Store & Forward Guild Relay for sending crafting requests to offline crafters (delivered automatically upon login).
- Automated Shopping List pop-up at the Auction House (1-click search) and NPC Vendors (1-click direct buy).
- Automated Crafter Order Queue that ticks off orders upon crafting the item.
- Full bilingual localization (English enUS/enGB & German deDE) and WoW Forever surname support.
```
