-- ============================================================
-- schema.sql — Sweet Factory
-- Structure complète de la base de données
-- Généré depuis sweetfactory.db
-- ============================================================

PRAGMA foreign_keys = ON;

-- ============================================================
-- TABLES
-- ============================================================

-- Clients individuels (particuliers)
CREATE TABLE particulier (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    nom              TEXT    NOT NULL,
    prenom           TEXT    NOT NULL,
    email            TEXT    NOT NULL UNIQUE,
    telephone        TEXT    NOT NULL,
    adresse          TEXT    NOT NULL,
    ville            TEXT    NOT NULL,
    pays             TEXT    NOT NULL DEFAULT 'France',
    date_naissance   DATE    NOT NULL,
    date_inscription DATE    NOT NULL DEFAULT (DATE('now'))
);

-- Clients professionnels (B2B)
CREATE TABLE entreprise (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nom                 TEXT    NOT NULL,
    email               TEXT    NOT NULL UNIQUE,
    telephone           TEXT    NOT NULL,
    adresse             TEXT    NOT NULL,
    ville               TEXT    NOT NULL,
    pays                TEXT    NOT NULL DEFAULT 'France',
    numero_siret        TEXT    NOT NULL UNIQUE,
    secteur_activite    TEXT    NOT NULL CHECK (secteur_activite IN (
                            'Grande distribution',
                            'Épicerie fine',
                            'Restauration',
                            'Revendeur en ligne',
                            'Autre'
                        )),
    date_creation       DATE    NOT NULL,
    date_inscription    DATE    NOT NULL DEFAULT (DATE('now'))
);

-- Catalogue des produits vendus (chocolats, bonbons, biscuits)
CREATE TABLE produit (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    nom                TEXT    NOT NULL UNIQUE,
    categorie          TEXT    NOT NULL CHECK (categorie IN ('Chocolats', 'Bonbons', 'Biscuits')),
    sous_categorie     TEXT,
    prix_unitaire      REAL    NOT NULL CHECK (prix_unitaire > 0),
    poids_g            REAL    NOT NULL CHECK (poids_g > 0),
    conditionnement    TEXT    NOT NULL CHECK (conditionnement IN (
                           'Boîte individuelle',
                           'Sachet',
                           'Vrac au kg',
                           'Palette'
                       )),
    date_mise_en_vente DATE    NOT NULL,
    date_peremption    DATE    NOT NULL,
    description        TEXT,
    actif              INTEGER NOT NULL DEFAULT 1 CHECK (actif IN (0, 1))
);

-- Ingrédients utilisés dans les recettes
CREATE TABLE ingredient (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    nom            TEXT    NOT NULL UNIQUE,
    unite          TEXT    NOT NULL CHECK (unite IN ('g', 'kg', 'ml', 'cl', 'L')),
    prix_unitaire  REAL    NOT NULL CHECK (prix_unitaire >= 0),
    fournisseur    TEXT,
    allergene      TEXT    CHECK (allergene IN (
                       'Gluten',
                       'Lactose',
                       'Fruits à coque',
                       'Soja',
                       'Œufs',
                       'Aucun',
                       NULL
                   ))
);

-- Niveaux de stock par ingrédient avec alertes minimum/maximum
CREATE TABLE stock (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    ingredient_id        INTEGER NOT NULL UNIQUE REFERENCES ingredient(id) ON DELETE CASCADE,
    quantite_disponible  REAL    NOT NULL DEFAULT 0.0 CHECK (quantite_disponible >= 0),
    quantite_minimum     REAL    NOT NULL CHECK (quantite_minimum >= 0),
    quantite_maximum     REAL    NOT NULL CHECK (quantite_maximum > 0),
    date_mise_a_jour     DATE    NOT NULL DEFAULT (DATE('now')),

    -- Le minimum ne peut pas dépasser le maximum
    CHECK (quantite_minimum < quantite_maximum)
);

-- Association produit <-> ingrédients avec quantités
CREATE TABLE recette (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    produit_id     INTEGER NOT NULL REFERENCES produit(id) ON DELETE CASCADE,
    ingredient_id  INTEGER NOT NULL REFERENCES ingredient(id) ON DELETE RESTRICT,
    quantite       REAL    NOT NULL CHECK (quantite > 0),

    -- Un ingrédient ne peut apparaître qu'une seule fois par recette
    UNIQUE (produit_id, ingredient_id)
);

-- Commandes passées par des particuliers ou des entreprises
CREATE TABLE commande (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    particulier_id    INTEGER REFERENCES particulier(id) ON DELETE SET NULL,
    entreprise_id     INTEGER REFERENCES entreprise(id) ON DELETE SET NULL,
    statut            TEXT    NOT NULL DEFAULT 'en attente'
                              CHECK (statut IN ('en attente', 'en cours', 'livré', 'annulé')),
    adresse_livraison TEXT    NOT NULL,
    mode_livraison    TEXT    NOT NULL CHECK (mode_livraison IN (
                          'Colissimo',
                          'Transporteur palette',
                          'Retrait usine',
                          'Chronopost'
                      )),
    frais_livraison   REAL    NOT NULL DEFAULT 0.0,
    date_commande     DATE    NOT NULL DEFAULT (DATE('now')),
    date_livraison    DATE,

    -- Un client est soit un particulier soit une entreprise, jamais les deux
    CHECK (
        (particulier_id IS NOT NULL AND entreprise_id IS NULL) OR
        (particulier_id IS NULL AND entreprise_id IS NOT NULL)
    )
);

-- Détail des produits commandés dans chaque commande
CREATE TABLE ligne_commande (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    commande_id    INTEGER NOT NULL REFERENCES commande(id) ON DELETE CASCADE,
    produit_id     INTEGER NOT NULL REFERENCES produit(id) ON DELETE RESTRICT,
    quantite       INTEGER NOT NULL CHECK (quantite > 0),
    prix_unitaire  REAL    NOT NULL CHECK (prix_unitaire >= 0),
    remise_pct     REAL    NOT NULL DEFAULT 0.0
                           CHECK (remise_pct >= 0 AND remise_pct <= 100)
);

-- ============================================================
-- INDEX
-- ============================================================

-- Recherche rapide des commandes d'une entreprise
CREATE INDEX idx_commande_entreprise ON commande(entreprise_id);

-- Recherche rapide des commandes d'un particulier
CREATE INDEX idx_commande_particulier ON commande(particulier_id);

-- Filtrage des commandes par statut (en attente, livré, etc.)
CREATE INDEX idx_commande_statut ON commande(statut);

-- Jointure rapide ligne_commande -> commande
CREATE INDEX idx_ligne_commande ON ligne_commande(commande_id);

-- Jointure rapide stock -> ingredient
CREATE INDEX idx_stock_ingredient ON stock(ingredient_id);

-- ============================================================
-- VUES
-- ============================================================

-- Vue complète des commandes : client, produit, montant par ligne (remise incluse)
CREATE VIEW commande_detail AS
SELECT
    c.id                                                        AS commande_id,
    c.date_commande,
    c.statut,
    COALESCE(p.nom || ' ' || p.prenom, e.nom)                  AS client,
    CASE WHEN p.id IS NOT NULL THEN 'Particulier' ELSE 'Entreprise' END AS type_client,
    pr.nom                                                      AS produit,
    lc.quantite,
    lc.prix_unitaire,
    lc.remise_pct,
    ROUND(lc.quantite * lc.prix_unitaire * (1 - lc.remise_pct / 100.0), 2) AS montant_ligne
FROM commande c
JOIN ligne_commande lc ON lc.commande_id = c.id
JOIN produit pr        ON pr.id = lc.produit_id
LEFT JOIN particulier p ON p.id = c.particulier_id
LEFT JOIN entreprise e  ON e.id = c.entreprise_id;

-- Stock des produits finis disponibles à l'expédition
-- Permet de savoir si on peut honorer une commande sans relancer la production
CREATE TABLE stock_produit (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    produit_id           INTEGER NOT NULL UNIQUE REFERENCES produit(id) ON DELETE CASCADE,
    quantite_disponible  INTEGER NOT NULL DEFAULT 0 CHECK (quantite_disponible >= 0),
    quantite_minimum     INTEGER NOT NULL CHECK (quantite_minimum >= 0),
    quantite_maximum     INTEGER NOT NULL CHECK (quantite_maximum > 0),
    date_mise_a_jour     DATE    NOT NULL,

    -- Le seuil minimum ne peut pas dépasser le maximum
    CHECK (quantite_minimum < quantite_maximum)
);

-- Ingrédients en dessous du seuil minimum — à réapprovisionner
CREATE VIEW stock_alerte AS
SELECT
    i.nom                   AS ingredient,
    i.fournisseur,
    s.quantite_disponible,
    s.quantite_minimum,
    (s.quantite_minimum - s.quantite_disponible) AS quantite_a_commander
FROM stock s
JOIN ingredient i ON i.id = s.ingredient_id
WHERE s.quantite_disponible < s.quantite_minimum;
