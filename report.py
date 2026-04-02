"""
report.py — Sweet Factory
Génère automatiquement trois rapports CSV :
  1. Chiffre d'affaires par mois
  2. Produits les plus vendus
  3. État des stocks (ingrédients + produits finis)
Les fichiers sont exportés dans le dossier exports/ avec la date du jour dans le nom.
"""

import sqlite3
import csv
import os
from datetime import date

# ── Configuration ────────────────────────────────────────────
DB_PATH      = os.path.join(os.path.dirname(__file__), "sweetfactory.db")
EXPORTS_DIR  = os.path.join(os.path.dirname(__file__), "exports")
TODAY        = date.today().strftime("%Y-%m")   # ex : 2026-04

# ── Requêtes (issues de analysis.sql) ───────────────────────

# Requête 3 — Chiffre d'affaires par mois
QUERY_CA_PAR_MOIS = """
SELECT
    strftime('%Y-%m', c.date_commande)          AS mois,
    COUNT(DISTINCT c.id)                        AS nb_commandes,
    ROUND(SUM(lc.quantite * lc.prix_unitaire * (1 - lc.remise_pct / 100.0)), 2) AS chiffre_affaires
FROM commande c
JOIN ligne_commande lc ON lc.commande_id = c.id
WHERE c.statut != 'annulé'
GROUP BY mois
ORDER BY mois;
"""

# Requête 1 — Produits les plus vendus
QUERY_PRODUITS_VENDUS = """
SELECT
    p.nom                           AS produit,
    p.categorie,
    SUM(lc.quantite)                AS total_vendu,
    ROUND(SUM(lc.quantite * lc.prix_unitaire * (1 - lc.remise_pct / 100.0)), 2) AS chiffre_affaires
FROM ligne_commande lc
JOIN produit p ON p.id = lc.produit_id
GROUP BY p.id, p.nom, p.categorie
ORDER BY total_vendu DESC;
"""

# Requête 3 — État des stocks (ingrédients + produits finis)
QUERY_STOCKS = """
SELECT
    'Ingrédient'                    AS type,
    i.nom                           AS article,
    i.unite                         AS unite,
    s.quantite_disponible           AS stock_actuel,
    s.quantite_minimum              AS stock_minimum,
    CASE WHEN s.quantite_disponible < s.quantite_minimum
         THEN 'ALERTE' ELSE 'OK' END AS statut
FROM stock s
JOIN ingredient i ON i.id = s.ingredient_id

UNION ALL

SELECT
    'Produit fini'                  AS type,
    p.nom                           AS article,
    'unités'                        AS unite,
    sp.quantite_disponible          AS stock_actuel,
    sp.quantite_minimum             AS stock_minimum,
    CASE WHEN sp.quantite_disponible < sp.quantite_minimum
         THEN 'ALERTE' ELSE 'OK' END AS statut
FROM stock_produit sp
JOIN produit p ON p.id = sp.produit_id
WHERE p.actif = 1

ORDER BY statut DESC, type, article;
"""


def export_to_csv(cursor, filename: str) -> str:
    """
    Exporte les résultats du curseur dans un fichier CSV.
    Retourne le chemin complet du fichier créé.
    """
    os.makedirs(EXPORTS_DIR, exist_ok=True)
    filepath = os.path.join(EXPORTS_DIR, filename)

    headers = [desc[0] for desc in cursor.description]
    rows    = cursor.fetchall()

    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    return filepath


def run_reports():
    print(f"📦 Sweet Factory — Rapport mensuel ({TODAY})")
    print(f"   Base de données : {DB_PATH}\n")

    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row

        # ── Rapport 1 : CA par mois ───────────────────────
        cur = conn.execute(QUERY_CA_PAR_MOIS)
        filename_ca = f"rapport_{TODAY}_ca_par_mois.csv"
        path_ca = export_to_csv(cur, filename_ca)
        print(f"✅ Chiffre d'affaires par mois  → {path_ca}")

        # Aperçu console (3 dernières lignes)
        with open(path_ca, encoding="utf-8") as f:
            lines = f.readlines()
        print("   Aperçu :")
        for line in lines[:1] + lines[-3:]:
            print("  ", line.rstrip())

        print()

        # ── Rapport 2 : Produits les plus vendus ─────────
        cur = conn.execute(QUERY_PRODUITS_VENDUS)
        filename_prod = f"rapport_{TODAY}_produits_plus_vendus.csv"
        path_prod = export_to_csv(cur, filename_prod)
        print(f"✅ Produits les plus vendus      → {path_prod}")

        # Aperçu console (top 5)
        with open(path_prod, encoding="utf-8") as f:
            lines = f.readlines()
        print("   Aperçu (top 5) :")
        for line in lines[:6]:
            print("  ", line.rstrip())

        print()

        # ── Rapport 3 : État des stocks ───────────────────
        cur = conn.execute(QUERY_STOCKS)
        filename_stock = f"rapport_{TODAY}_etat_stocks.csv"
        path_stock = export_to_csv(cur, filename_stock)
        print(f"✅ État des stocks               → {path_stock}")

        # Aperçu console (lignes en alerte uniquement)
        with open(path_stock, encoding="utf-8") as f:
            lines = f.readlines()
        alertes = [l for l in lines[1:] if 'ALERTE' in l]
        print(f"   {len(alertes)} alerte(s) détectée(s) :")
        for line in alertes:
            print("  ", line.rstrip())

    print("\n🎉 Export terminé.")


if __name__ == "__main__":
    run_reports()
