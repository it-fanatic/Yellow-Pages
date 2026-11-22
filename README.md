# 📖 Yellow-Pages — The Guild Crafting & Gathering Directory (EN / DE)

**Yellow-Pages ("Die Gelben Seiten der Gilde")** is a standalone guild profession directory, material & Auction House cost calculator, interactive crafting order system (supporting both **online** and **offline** crafters), and automated Shopping List for **World of Warcraft (WoW Forever, Classic Era, Cataclysm Classic & Retail)**.

---

## ✨ Features (English)

* **🛠️ All Crafting, Gathering & Secondary Professions:**
  * Covers **Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring**, **Herbalism, Mining, Skinning**, as well as **Cooking & First Aid**.
  * Automatically scans crafting recipes when opening your profession window and detects gathering skill ranks automatically upon login or skill-up.
* **🔄 100% Standalone Guild Synchronization:**
  * Synchronizes recipes, skill levels, and online status across guild members silently via Blizzard's native addon channel — no external client or website required.
* **💰 Live Material & Cost Calculator (Bags, Bank, Vendor & AH):**
  * Displays your own bag and bank stock (`Have / Need`, with built-in *Syndicator / Baganator* integration).
  * Distinguishes fixed NPC vendor prices from live Auction House prices (*Auctionator*, *TradeSkillMaster (TSM)*, *Auctioneer*).
* **✉️ Interactive 4-Step Crafting Order Workflow (Online & Offline Crafters):**
  1. **Request:** Click **Request** on any crafter to transmit your order and current material stock.
  2. **Offline Guild Relay (Store & Forward):** Even if the crafter is **offline**, you can send the request! It is stored in the guild relay and delivered automatically as soon as the crafter logs in.
  3. **Crafter Inspection & 1-Click Reply:** The crafter clicks `[Yellow-Pages: Open Request]` in chat to inspect missing materials vs. their own bags/bank and replies with one click (*All Mats Ready!*, *Get Remaining Mats*, *Bring ALL Mats!*, or *Busy / No Time*).
  4. **Order Confirmation:** The requester clicks `[Yellow-Pages: Confirm & Place Order]` in chat.
* **🛒 Automated Shopping List (AH & Vendor Pop-Up) & Crafter Order Queue:**
  * **For Requesters:** Missing materials are automatically added to the **Shopping List**, which pops up automatically when opening the **Auction House** (1-click transfer to AH search) or a **Vendor** (1-click direct purchase of the exact needed quantity).
  * **For Crafters:** Confirmed orders enter the **Order Queue** and are automatically ticked off as **Done** the moment the item is crafted!
* **🌍 Bilingual (`enUS` & `deDE`):** Automatically adapts to your WoW client language.

---

## ✨ Funktionen (Deutsch)

* **🛠️ Alle Herstellungs-, Sammel- & Nebenberufe:**
  * Unterstützt **Alchemie, Schmiedekunst, Verzauberkunst, Ingenieurskunst, Lederverarbeitung, Schneiderei**, die Sammelberufe **Kräuterkunde, Bergbau, Kürschnerei** sowie **Kochkunst & Erste Hilfe**.
  * Scannt Handwerksrezepte automatisch beim Öffnen des Berufsfensters und erkennt Sammelberufe anhand der aktuellen Fertigkeitsstufe automatisch beim Login.
* **🔄 100% Standalone Gilden-Synchronisation:**
  * Synchronisiert Rezepte, Skill-Stufen und Online-Status direkt im Spiel über den Gilden-Addon-Kanal.
* **💰 Materialbestand & Preisberechnung (Tasche, Bank, Händler & AH):**
  * Prüft deinen eigenen Bestand in Taschen und auf der Bank (`Besitz / Bedarf`, inkl. *Syndicator / Baganator*-Unterstützung).
  * Berechnet Händler-Zutaten mit festen NPC-Preisen und Handelswaren mit aktuellen Auktionshaus-Preisen (*Auctionator*, *TSM*, *Auctioneer*).
* **✉️ Interaktives 4-Schritte-Auftragssystem (Online & Offline):**
  1. **Anfragen:** Klicke beim gewünschten Handwerker auf **Anfragen** – dein Materialbestand wird direkt mitgesendet.
  2. **Offline-Anfragen (Gilden-Relais):** Auch an **Offline-Handwerker** können Anfragen gestellt werden! Sie werden im Gilden-Relais gespeichert und dem Handwerker beim nächsten Login automatisch zugestellt.
  3. **Handwerker-Prüfung & 1-Klick-Antwort:** Der Handwerker klickt im Chat auf `[Yellow-Pages: Anfrage öffnen]`, sieht deinen Fehlbestand abgeglichen mit seiner eigenen Tasche/Bank und antwortet per Klick (*Alle Mats da!*, *Rest-Mats anfordern*, *Alle Mats anfordern* oder *Gerade keine Zeit*).
  4. **Auftragsbestätigung:** Der Anfragende bestätigt per Klick im Chat auf `[Yellow-Pages: Auftrag bestätigen]`.
* **🛒 Automatische Einkaufsliste (AH & Händler Pop-Up) & Auftragsliste:**
  * **Für Auftraggeber:** Fehlende Materialien landen automatisch in der **Einkaufsliste**, die sich beim Öffnen des **Auktionshauses** (1-Klick-Suche) und bei **Händlern** (1-Klick-Direktkauf der benötigten Menge) automatisch als Pop-Up öffnet.
  * **Für Handwerker:** Bestätigte Aufträge landen in der **Auftragsliste** und werden beim Herstellen des Gegenstands automatisch als **Erledigt** abgehakt.

---

## ⌨️ Slash Commands / Chat-Befehle

| Command | Description (EN) | Beschreibung (DE) |
| :--- | :--- | :--- |
| `/yp` or `/yellowpages` | Open / close main window | Hauptfenster öffnen / schließen |
| `/yp scan` | Scan currently open profession | Geöffnetes Berufsfenster scannen |
| `/yp sync` | Broadcast professions to guild | Gilden-Synchronisation starten |
| `/yp shop` | Toggle Shopping List | Einkaufsliste öffnen / schließen |
| `/yp orders` | Toggle Crafter Order Queue | Auftragsliste öffnen / schließen |
| `/yp info` | Open Info & Guide page | Info- & Anleitungs-Seite öffnen |
| `/yp reset` | Reset local guild database | Lokale Gilden-Datenbank zurücksetzen |
