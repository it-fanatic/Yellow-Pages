--[[
    Yellow-Pages: Standard-Händlermaterialien und deren Kaufpreise beim NPC
    Preise sind in Kupfer angegeben (1 Gold = 10000, 1 Silber = 100, 1 Kupfer = 1)
--]]

YellowPages = YellowPages or {}
YellowPages.VendorReagents = {
    -- Alchemie / Phiolen
    [3371]  = { name = "Leere Phiole",            price = 4,      category = "Alchemie" },
    [3372]  = { name = "Verbleite Phiole",        price = 30,     category = "Alchemie" },
    [8925]  = { name = "Kristallphiole",          price = 400,    category = "Alchemie" },
    [18256] = { name = "Erfüllte Phiole",         price = 1600,   category = "Alchemie" },

    -- Schneiderei / Fäden & Farbstoffe
    [2320]  = { name = "Grober Faden",            price = 10,     category = "Schneiderei" },
    [2321]  = { name = "Feiner Faden",            price = 100,    category = "Schneiderei" },
    [4291]  = { name = "Seidenfaden",             price = 500,    category = "Schneiderei" },
    [8343]  = { name = "Schwerer Seidenfaden",    price = 2000,   category = "Schneiderei" },
    [14341] = { name = "Runenfaden",              price = 5000,   category = "Schneiderei" },
    [38426] = { name = "Eterniumfaden",           price = 30000,  category = "Schneiderei" },
    [2604]  = { name = "Bleichmittel",            price = 25,     category = "Schneiderei" },
    [2605]  = { name = "Roter Farbstoff",         price = 50,     category = "Schneiderei" },
    [4340]  = { name = "Blauer Farbstoff",        price = 50,     category = "Schneiderei" },
    [4341]  = { name = "Gelber Farbstoff",        price = 50,     category = "Schneiderei" },
    [4342]  = { name = "Grauer Farbstoff",        price = 100,    category = "Schneiderei" },
    [6260]  = { name = "Grüner Farbstoff",        price = 100,    category = "Schneiderei" },
    [6261]  = { name = "Orangener Farbstoff",     price = 100,    category = "Schneiderei" },
    [10290] = { name = "Violetter Farbstoff",     price = 250,    category = "Schneiderei" },
    [4357]  = { name = "Schwarzer Farbstoff",     price = 1000,   category = "Schneiderei" },

    -- Schmiedekunst & Bergbau / Flussmittel & Kohle
    [2880]  = { name = "Schwaches Flussmittel",   price = 20,     category = "Schmiedekunst" },
    [3466]  = { name = "Starkes Flussmittel",     price = 200,    category = "Schmiedekunst" },
    [3857]  = { name = "Kohle",                   price = 50,     category = "Schmiedekunst" },
    [10620] = { name = "Elementarflussmittel",    price = 2000,   category = "Schmiedekunst" },

    -- Lederverarbeitung / Salz & Fäden
    [4289]  = { name = "Salz",                    price = 10,     category = "Lederverarbeitung" },
    [8170]  = { name = "Raffiniertes Tiefsteinsalz", price = 1000, category = "Lederverarbeitung" },

    -- Ingenieurskunst / Holz & Schießpulver
    [4470]  = { name = "Einfaches Holz",          price = 37,     category = "Ingenieurskunst" },
    [4471]  = { name = "Hartholz",                price = 200,    category = "Ingenieurskunst" },

    -- Kochen / Gewürze & Zutaten
    [2678]  = { name = "Milde Gewürze",           price = 10,     category = "Kochen" },
    [2692]  = { name = "Scharfe Gewürze",         price = 20,     category = "Kochen" },
    [3713]  = { name = "Feine Gewürze",           price = 100,    category = "Kochen" },
    [3081]  = { name = "Einfaches Mehl",          price = 25,     category = "Kochen" },
    [159]   = { name = "Erfrischendes Quellwasser", price = 25,   category = "Kochen" },
    [4536]  = { name = "Glänzender roter Apfel",  price = 25,     category = "Kochen" },

    -- Inschriftenkunde / Pergament
    [39354] = { name = "Leichtes Pergament",      price = 20,     category = "Inschriftenkunde" },
    [39501] = { name = "Schweres Pergament",      price = 100,    category = "Inschriftenkunde" },
    [39502] = { name = "Widerstandsfähiges Pergament", price = 500, category = "Inschriftenkunde" },

    -- Verzauberkunst / Ruten (sofern beim Händler kaufbar)
    [6217]  = { name = "Kupferrute",              price = 124,    category = "Verzauberkunst" },
}

function YellowPages:IsVendorReagent(itemID)
    if not itemID then return false end
    return self.VendorReagents[itemID] ~= nil
end

function YellowPages:GetVendorReagentPrice(itemID)
    if not itemID then return 0 end
    local info = self.VendorReagents[itemID]
    return info and info.price or 0
end
