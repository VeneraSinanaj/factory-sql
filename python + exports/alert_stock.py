"""
alert_stock.py — Sweet Factory
Vérifie deux niveaux de stock :
  1. stock_alerte (vue) — ingrédients en dessous du seuil minimum
  2. stock_produit      — produits finis en dessous du seuil minimum
Génère un rapport HTML dans exports/ si des alertes existent.
Si tout est OK, affiche un message et ne génère rien.
"""

import sqlite3
import os
import sys
import webbrowser
from datetime import datetime

# Forcer l'encodage UTF-8 pour le terminal Windows (emojis et accents)
sys.stdout.reconfigure(encoding='utf-8')

# ── Configuration ────────────────────────────────────────────
DB_PATH     = os.path.join(os.path.dirname(__file__), "sweetfactory.db")
EXPORTS_DIR = os.path.join(os.path.dirname(__file__), "exports")
TIMESTAMP   = datetime.now().strftime("%Y-%m-%d_%H-%M")
HTML_PATH   = os.path.join(EXPORTS_DIR, f"alerte_stock_{TIMESTAMP}.html")

# ── Requête 1 : stock ingrédients (via vue stock_alerte) ─────
QUERY_INGREDIENTS = """
SELECT
    ingredient,
    fournisseur,
    quantite_disponible,
    quantite_minimum,
    quantite_a_commander
FROM stock_alerte
ORDER BY quantite_a_commander DESC;
"""

# ── Requête 2 : stock produits finis ─────────────────────────
QUERY_PRODUITS = """
SELECT
    p.nom                                               AS produit,
    p.categorie,
    sp.quantite_disponible,
    sp.quantite_minimum,
    (sp.quantite_minimum - sp.quantite_disponible)      AS unites_a_produire
FROM stock_produit sp
JOIN produit p ON p.id = sp.produit_id
WHERE sp.quantite_disponible < sp.quantite_minimum
AND p.actif = 1
ORDER BY unites_a_produire DESC;
"""


def fetch_alertes(conn):
    ing  = conn.execute(QUERY_INGREDIENTS).fetchall()
    prod = conn.execute(QUERY_PRODUITS).fetchall()
    return ing, prod


def make_badge(dispo, minimum):
    if dispo == 0:
        return '<span class="badge rouge">Rupture</span>'
    elif dispo < minimum * 0.5:
        return '<span class="badge orange">Critique</span>'
    else:
        return '<span class="badge jaune">Bas</span>'


def generate_html(alertes_ing: list, alertes_prod: list) -> str:
    now = datetime.now().strftime("%d/%m/%Y à %H:%M")

    # ── Section ingrédients ───────────────────────────────────
    rows_ing = ""
    for ingredient, fournisseur, dispo, minimum, a_commander in alertes_ing:
        rows_ing += f"""
        <tr>
            <td><strong>{ingredient}</strong></td>
            <td>{fournisseur or '—'}</td>
            <td class="num">{dispo:.1f}</td>
            <td class="num">{minimum:.1f}</td>
            <td class="num commande">{a_commander:.1f}</td>
            <td>{make_badge(dispo, minimum)}</td>
        </tr>"""

    section_ing = f"""
    <h2 style="margin:28px 0 12px;font-size:16px;color:#2c3e50">
        🧂 Matières premières en alerte ({len(alertes_ing)})
    </h2>
    <div class="card">
        <table>
            <thead><tr>
                <th>Ingrédient</th><th>Fournisseur</th>
                <th style="text-align:right">Stock actuel</th>
                <th style="text-align:right">Stock minimum</th>
                <th style="text-align:right">Qté à commander</th>
                <th>Statut</th>
            </tr></thead>
            <tbody>{rows_ing}</tbody>
        </table>
    </div>""" if alertes_ing else """
    <div class="ok-box">✅ Tous les ingrédients sont au-dessus du seuil minimum.</div>"""

    # ── Section produits finis ────────────────────────────────
    rows_prod = ""
    for produit, categorie, dispo, minimum, a_produire in alertes_prod:
        rows_prod += f"""
        <tr>
            <td><strong>{produit}</strong></td>
            <td>{categorie}</td>
            <td class="num">{dispo}</td>
            <td class="num">{minimum}</td>
            <td class="num commande">{a_produire}</td>
            <td>{make_badge(dispo, minimum)}</td>
        </tr>"""

    section_prod = f"""
    <h2 style="margin:28px 0 12px;font-size:16px;color:#2c3e50">
        🍫 Produits finis en alerte ({len(alertes_prod)})
    </h2>
    <div class="card">
        <table>
            <thead><tr>
                <th>Produit</th><th>Catégorie</th>
                <th style="text-align:right">Stock actuel</th>
                <th style="text-align:right">Stock minimum</th>
                <th style="text-align:right">Unités à produire</th>
                <th>Statut</th>
            </tr></thead>
            <tbody>{rows_prod}</tbody>
        </table>
    </div>""" if alertes_prod else """
    <div class="ok-box">✅ Tous les produits finis sont au-dessus du seuil minimum.</div>"""

    nb = len(alertes_ing) + len(alertes_prod)

    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>⚠️ Alerte Stock — Sweet Factory</title>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}

        body {{
            font-family: 'Segoe UI', Arial, sans-serif;
            background: #f4f6f9;
            color: #2d2d2d;
            padding: 40px 20px;
        }}

        .container {{
            max-width: 860px;
            margin: 0 auto;
        }}

        /* En-tête */
        .header {{
            background: linear-gradient(135deg, #c0392b, #e74c3c);
            color: white;
            border-radius: 12px;
            padding: 28px 32px;
            margin-bottom: 24px;
            display: flex;
            align-items: center;
            gap: 20px;
        }}
        .header .icon {{ font-size: 48px; }}
        .header h1 {{ font-size: 26px; font-weight: 700; margin-bottom: 4px; }}
        .header p  {{ font-size: 14px; opacity: 0.85; }}

        /* Résumé */
        .summary {{
            background: #fff3cd;
            border-left: 5px solid #f0a500;
            border-radius: 8px;
            padding: 16px 20px;
            margin-bottom: 24px;
            font-size: 15px;
        }}
        .summary strong {{ color: #c0392b; font-size: 17px; }}

        /* Tableau */
        .card {{
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.08);
            overflow: hidden;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
        }}

        thead {{
            background: #2c3e50;
            color: white;
        }}

        thead th {{
            padding: 14px 16px;
            text-align: left;
            font-size: 13px;
            font-weight: 600;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }}

        tbody tr {{
            border-bottom: 1px solid #f0f0f0;
            transition: background 0.15s;
        }}
        tbody tr:hover {{ background: #fafafa; }}
        tbody tr:last-child {{ border-bottom: none; }}

        td {{
            padding: 14px 16px;
            font-size: 14px;
        }}

        .num {{ text-align: right; font-variant-numeric: tabular-nums; }}
        .commande {{ color: #c0392b; font-weight: 700; font-size: 15px; }}

        /* Badges */
        .badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }}
        .badge.rouge  {{ background: #fde8e8; color: #c0392b; }}
        .badge.orange {{ background: #fde8d8; color: #d35400; }}
        .badge.jaune  {{ background: #fef9e7; color: #b7950b; }}

        /* Pied de page */
        .footer {{
            text-align: center;
            margin-top: 20px;
            font-size: 12px;
            color: #999;
        }}
        .ok-box {{
            background: #eafaf1;
            border-left: 5px solid #27ae60;
            border-radius: 8px;
            padding: 14px 20px;
            font-size: 14px;
            color: #1e8449;
            margin-bottom: 12px;
        }}
    </style>
</head>
<body>
<div class="container">

    <div class="header">
        <div class="icon">⚠️</div>
        <div>
            <h1>Alerte Stock — Sweet Factory</h1>
            <p>Rapport généré le {now}</p>
        </div>
    </div>

    <div class="summary">
        <strong>{nb} alerte{'s' if nb > 1 else ''} au total</strong> —
        {len(alertes_ing)} ingrédient{'s' if len(alertes_ing) > 1 else ''} et
        {len(alertes_prod)} produit{'s' if len(alertes_prod) > 1 else ''} fini{'s' if len(alertes_prod) > 1 else ''}
        en dessous du seuil minimum.
    </div>

    {section_ing}
    {section_prod}

    <div class="footer">
        Sweet Factory — Système de gestion des stocks · {now}
    </div>

</div>
</body>
</html>"""


def main():
    print("🏭 Sweet Factory — Vérification des deux niveaux de stock\n")

    with sqlite3.connect(DB_PATH) as conn:
        alertes_ing, alertes_prod = fetch_alertes(conn)

    if not alertes_ing and not alertes_prod:
        print("✅ Tous les stocks sont au-dessus du seuil minimum.")
        print("   Aucun rapport généré.")
        return

    # Générer le HTML
    os.makedirs(EXPORTS_DIR, exist_ok=True)
    html = generate_html(alertes_ing, alertes_prod)

    with open(HTML_PATH, "w", encoding="utf-8") as f:
        f.write(html)

    if alertes_ing:
        print(f"⚠️  {len(alertes_ing)} ingrédient(s) en alerte :")
        for ing, four, dispo, mini, a_cmd in alertes_ing:
            print(f"   • {ing:<25} stock={dispo:.1f}  min={mini:.1f}  à commander={a_cmd:.1f}")

    if alertes_prod:
        print(f"\n⚠️  {len(alertes_prod)} produit(s) fini(s) en alerte :")
        for prod, cat, dispo, mini, a_prod in alertes_prod:
            print(f"   • {prod:<25} stock={dispo}  min={mini}  à produire={a_prod}")

    print(f"\n📄 Rapport généré → {HTML_PATH}")

    # Ouvrir automatiquement dans le navigateur
    webbrowser.open(f"file:///{HTML_PATH.replace(os.sep, '/')}")
    print("🌐 Ouverture dans le navigateur...")


if __name__ == "__main__":
    main()
