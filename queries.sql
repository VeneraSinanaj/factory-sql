-- ============================================================
-- queries.sql — Sweet Factory
-- Requêtes de manipulation quotidienne de la base de données
-- ============================================================

-- ============================================================
-- INSERTIONS
-- ============================================================

-- Un nouveau particulier crée son compte sur le site.
-- On enregistre ses coordonnées complètes.
INSERT INTO particulier (nom, prenom, email, telephone, adresse, ville, date_naissance, date_inscription)
VALUES ('Sinanaj', 'Venera', 'venerasinanaj@gmail.com', '+33 3 88 00 00 01', '8 Rue des Lilas', 'Colmar', '2004-04-21', '2026-04-01');

-- Le particulier vient de s'inscrire et passe immédiatement sa première commande.
-- On crée la commande liée à son compte (particulier_id = 1).
INSERT INTO commande (particulier_id, adresse_livraison, mode_livraison)
VALUES (1, '8 Rue des Lilas, 68000 Colmar', 'Colissimo');

-- On ajoute le détail de sa commande : 3 unités du produit id=1.
-- last_insert_rowid() récupère automatiquement l'id de la commande qu'on vient de créer.
INSERT INTO ligne_commande (commande_id, produit_id, quantite, prix_unitaire)
VALUES (last_insert_rowid(), 1, 3, 3.50);

-- Un nouveau produit est mis en vente : un sachet de chocolats noirs.
INSERT INTO produit (nom, categorie, prix_unitaire, poids_g, conditionnement, date_mise_en_vente, date_peremption)
VALUES ('Chocolat Noir 70%', 'Chocolats', 4.50, 100, 'Sachet', '2026-04-01', '2027-06-01');

-- ============================================================
-- MISES À JOUR
-- ============================================================

-- Un client appelle pour annuler sa commande.
-- On ne peut annuler que les commandes encore "en attente" —
-- une commande déjà partie en livraison ne peut plus être annulée.
UPDATE commande
SET statut = 'annulé'
WHERE id = 3 AND statut = 'en attente';

-- Un client s'est trompé de quantité lors de sa commande.
-- On corrige la ligne, mais seulement si la commande est encore "en attente".
-- La sous-requête vérifie le statut dans la table commande.
UPDATE ligne_commande
SET quantite = 5
WHERE id = 1
AND commande_id IN (
    SELECT id FROM commande WHERE statut = 'en attente'
);

-- On retire un produit de la vente (fin de gamme, rupture définitive).
-- On ne le supprime pas car il apparaît dans d'anciennes commandes (ON DELETE RESTRICT).
-- On le désactive simplement avec le flag actif = 0.
UPDATE produit
SET actif = 0
WHERE id = 2;

-- Le prix d'un produit est réévalué pour la nouvelle saison.
UPDATE produit
SET prix_unitaire = 5.00
WHERE id = 1;

-- Une livraison de fournisseur arrive : on ajoute 50 unités au stock de l'ingrédient id=2.
-- On additionne à la quantité existante plutôt que d'écraser la valeur.
UPDATE stock
SET quantite_disponible = quantite_disponible + 50,
    date_mise_a_jour = DATE('now')
WHERE ingredient_id = 2;

-- Une production vient d'être terminée : on ajoute les unités fabriquées
-- au stock du produit fini. On additionne à l'existant sans écraser.
UPDATE stock_produit
SET quantite_disponible = quantite_disponible + 100,
    date_mise_a_jour = DATE('now')
WHERE produit_id = 1;

-- Quand une commande est validée, on décrémente le stock des produits commandés.
-- Ici : 3 unités du produit id=1 sont réservées pour la commande id=355.
-- La sous-requête vérifie que la commande est bien en attente avant de toucher au stock.
UPDATE stock_produit
SET quantite_disponible = quantite_disponible - 3,
    date_mise_a_jour = DATE('now')
WHERE produit_id = 1
AND EXISTS (
    SELECT 1 FROM ligne_commande lc
    JOIN commande c ON c.id = lc.commande_id
    WHERE lc.produit_id = 1
    AND lc.quantite = 3
    AND c.statut = 'en attente'
);

-- ============================================================
-- SUPPRESSIONS
-- ============================================================

-- ============================================================
-- SUPPRESSION D'UN INGRÉDIENT — Impact sur les autres tables
-- ============================================================
--
-- Contexte : Sweet Factory décide d'arrêter d'utiliser la Gélatine
-- (ingredient id=14) car elle passe à une recette végane.
-- Avant de supprimer, il faut comprendre l'impact sur chaque table :
--
--   TABLE         CONTRAINTE              EFFET
--   ─────────────────────────────────────────────────────────
--   recette       ON DELETE RESTRICT  →  BLOQUE la suppression
--                                        si l'ingrédient est
--                                        encore dans une recette
--   stock         ON DELETE CASCADE   →  Supprime automatiquement
--                                        la ligne de stock liée
--
-- ÉTAPE 1 — Vérifier dans combien de recettes l'ingrédient apparaît
-- (à exécuter avant de supprimer, pour anticiper l'impact)
SELECT p.nom AS produit, r.quantite, i.unite
FROM recette r
JOIN produit p    ON p.id = r.produit_id
JOIN ingredient i ON i.id = r.ingredient_id
WHERE r.ingredient_id = 14;
-- Résultat : liste des produits dont la recette sera impactée

-- ÉTAPE 2 — Vérifier son stock actuel avant suppression
SELECT quantite_disponible, quantite_minimum
FROM stock
WHERE ingredient_id = 14;
-- Ce stock sera supprimé automatiquement par CASCADE à l'étape 4

-- ÉTAPE 3 — Supprimer l'ingrédient des recettes
-- Obligatoire en premier : sans ça, la suppression de l'ingrédient
-- sera bloquée par la contrainte ON DELETE RESTRICT de la table recette.
DELETE FROM recette WHERE ingredient_id = 14;

-- ÉTAPE 4 — Supprimer l'ingrédient
-- La ligne correspondante dans stock est supprimée automatiquement
-- grâce à ON DELETE CASCADE — pas besoin de le faire manuellement.
DELETE FROM ingredient WHERE id = 14;
--
-- Après exécution :
--   ✓ ingredient id=14 supprimé
--   ✓ recette    toutes les lignes ingredient_id=14 supprimées (étape 3)
--   ✓ stock      ligne ingredient_id=14 supprimée automatiquement (CASCADE)
--   ✓ ligne_commande  intacte — les anciennes commandes ne référencent
--                     pas directement les ingrédients, seulement les produits
-- ============================================================

-- Quand un produit est désactivé (actif=0), son stock produit devient inutile.
-- ON DELETE CASCADE supprime automatiquement la ligne dans stock_produit
-- si on supprime le produit. Mais comme on désactive sans supprimer,
-- on remet le stock à 0 manuellement pour refléter qu'il n'est plus commercialisé.
UPDATE stock_produit
SET quantite_disponible = 0,
    date_mise_a_jour = DATE('now')
WHERE produit_id = 2;

-- ============================================================
-- SUPPRESSION D'UN PRODUIT — Impact sur les autres tables
-- ============================================================
--
-- Contexte : Sweet Factory veut supprimer définitivement un produit
-- qui n'a jamais été commandé (id=19, nouveau produit test).
--
--   TABLE           CONTRAINTE              EFFET
--   ─────────────────────────────────────────────────────────
--   ligne_commande  ON DELETE RESTRICT  →  BLOQUE si le produit
--                                          est dans une commande
--   stock_produit   ON DELETE CASCADE   →  Supprime automatiquement
--                                          le stock du produit
--   recette         ON DELETE CASCADE   →  Supprime automatiquement
--                                          la recette du produit
--
-- ÉTAPE 1 — Vérifier que le produit n'est dans aucune commande
-- Si cette requête retourne des lignes, on ne peut pas supprimer
-- (ON DELETE RESTRICT bloquera) — il faut désactiver à la place (actif=0)
SELECT COUNT(*) AS nb_commandes
FROM ligne_commande
WHERE produit_id = 19;

-- ÉTAPE 2 — Supprimer le produit
-- Si le produit n'est dans aucune commande, on peut le supprimer.
-- recette et stock_produit seront nettoyés automatiquement (CASCADE).
DELETE FROM produit WHERE id = 19;
--
-- Après exécution :
--   ✓ produit id=19 supprimé
--   ✓ recette        toutes les lignes produit_id=19 supprimées (CASCADE)
--   ✓ stock_produit  ligne produit_id=19 supprimée automatiquement (CASCADE)
--   ✗ Si le produit était dans ligne_commande → ERREUR (RESTRICT)
--     → Dans ce cas, utiliser UPDATE produit SET actif=0 à la place
-- ============================================================
