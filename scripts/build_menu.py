#!/usr/bin/env python3
"""Build the public menu page and the compact menu block for the agent prompt.

Source of truth: data/menu/{food,drinks,venue}.csv
Outputs:
  deploy/web/carta.html      - guest-facing menu page (served by demo-talay-web)
  data/menu/menu_prompt.txt  - compact text injected into the agent's systemMessage
  data/menu/seed_menu_items.sql - idempotent load of table menu_items (migrations/007)

Usage: python3 scripts/build_menu.py
"""
import csv
import html
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MENU = ROOT / "data" / "menu"

ALLERGEN_LABEL = {
    "gluten": "Gluten", "crustaceans": "Crustaceans", "eggs": "Eggs", "fish": "Fish",
    "peanuts": "Peanuts", "soy": "Soy", "milk": "Milk", "tree_nuts": "Tree nuts",
    "celery": "Celery", "mustard": "Mustard", "sesame": "Sesame", "sulphites": "Sulphites",
    "lupin": "Lupin", "molluscs": "Molluscs",
}
DIET_LABEL = {"vegan": "Vegan", "vegetarian": "Vegetarian", "gluten_free": "Gluten-free",
              "gluten_free_on_request": "Gluten-free on request"}
SERVICE_LABEL = {"lunch": "lunch", "afternoon": "afternoon", "dinner": "dinner"}


def read(name):
    with open(MENU / name, newline="") as f:
        return list(csv.DictReader(f))


def split(value):
    return [v for v in value.split("|") if v]


def is_listed(row, today):
    """Available and not yet expired. Upcoming time-bound items are kept, with their dates shown."""
    if row.get("available", "yes") != "yes":
        return False
    end = row.get("available_to")
    return not (end and today > date.fromisoformat(end))


def grouped(rows):
    out = {}
    for r in rows:
        out.setdefault(r["section"], []).append(r)
    return out


def price(r):
    return "included" if r["price_thb"] in ("0", "") else f'{int(r["price_thb"]):,}'


# ---------- compact prompt block ----------

def prompt_block(food, drinks, today):
    lines = [
        "# Menu (prices in THB, plus 10% service and applicable taxes)",
        "Allergens and diets are deliberately not listed here: for any allergy, diet or restriction use the find_dishes tool. Tags: spicy 1-3; contains; service if not all day; dates for time-bound items.",
    ]
    for section, rows in grouped(food).items():
        lines.append(f"## {section}")
        for r in rows:
            tags = [f'spicy {r["spicy"]}'] if r["spicy"] not in ("", "0") else []
            tags += ["contains " + ", ".join(split(r["contains"]))] if r["contains"] else []
            if r["service"] != "all_day":
                tags.append(" & ".join(split(r["service"])) + " only")
            if r["available_from"] or r["available_to"]:
                tags.append(f'only {r["available_from"] or "now"} to {r["available_to"] or "further notice"}')
            desc = f' — {r["description"]}' if r["description"] else ""
            note = f' ({r["notes"]})' if r["notes"] else ""
            lines.append(f'- {r["name"]}{desc}. {price(r)}{note}' + (f' [{"; ".join(tags)}]' if tags else ""))
    lines.append("## Drinks")
    for section, rows in grouped(drinks).items():
        items = "; ".join(
            f'{r["name"]}{" (" + r["description"] + ")" if r["description"] else ""} {price(r)}/{r["unit"]}'
            for r in rows)
        lines.append(f"- {section}: {items}")
    return "\n".join(lines) + "\n"


# ---------- guest-facing page ----------

def badge(text, kind):
    return f'<span class="b b-{kind}">{html.escape(text)}</span>'


def item_html(r):
    badges = [badge(DIET_LABEL[d], "diet") for d in split(r["diet"])]
    if r["spicy"] not in ("", "0"):
        badges.append(badge("Spicy " + "•" * int(r["spicy"]), "spicy"))
    if r["service"] != "all_day":
        badges.append(badge(" & ".join(SERVICE_LABEL[s] for s in split(r["service"])), "svc"))
    if r["available_from"] or r["available_to"]:
        fmt = lambda d: date.fromisoformat(d).strftime("%-d %b %Y")
        span = " – ".join(fmt(d) for d in (r["available_from"], r["available_to"]) if d)
        badges.append(badge(span, "svc"))
    allergens = ", ".join(ALLERGEN_LABEL[a] for a in split(r["allergens"]))
    notes = r["notes"].removeprefix("Signature").strip(" .") if r["notes"] else ""
    sig = r["notes"].startswith("Signature") if r["notes"] else False
    parts = [
        '<li class="item">',
        '<div class="row"><h3>' + html.escape(r["name"])
        + (' <span class="sig">Signature</span>' if sig else "") + "</h3>"
        + f'<span class="price">{price(r)}</span></div>',
    ]
    if r.get("description"):
        parts.append(f'<p class="desc">{html.escape(r["description"])}</p>')
    if notes:
        parts.append(f'<p class="note">{html.escape(notes)}</p>')
    meta = "".join(badges)
    if allergens:
        meta += f'<span class="alg">Contains: {html.escape(allergens)}</span>'
    if meta:
        parts.append(f'<div class="meta">{meta}</div>')
    parts.append("</li>")
    return "".join(parts)


def drink_html(r):
    desc = f'<p class="desc">{html.escape(r["description"])}</p>' if r["description"] else ""
    return (f'<li class="item"><div class="row"><h3>{html.escape(r["name"])}</h3>'
            f'<span class="price">{price(r)}<small> / {html.escape(r["unit"])}</small></span></div>{desc}</li>')


def slug(text):
    return "".join(c if c.isalnum() else "-" for c in text.lower()).strip("-")[:40]


def page(food, drinks, venue):
    sections = list(grouped(food).items()) + [("Drinks · " + s, rows) for s, rows in grouped(drinks).items()]
    nav = "".join(f'<a href="#{slug(s)}">{html.escape(s.replace("Drinks · ", ""))}</a>' for s, _ in sections)
    body = []
    for s, rows in sections:
        render = drink_html if s.startswith("Drinks") else item_html
        body.append(f'<section id="{slug(s)}"><h2>{html.escape(s)}</h2><ul>'
                    + "".join(render(r) for r in rows) + "</ul></section>")
    hours = " · ".join(html.escape(venue[k]) for k in ("hours_lunch", "hours_afternoon", "hours_dinner"))
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<meta name="theme-color" content="#1F2D3D">
<title>Flames — Menu</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
:root {{ --navy:#1F2D3D; --cream:#F5EDDE; --cream-soft:#FBF6EC; --gold:#B89968; --sage:#7A8E7D;
  --ink:#1A1F26; --muted:#6B7280; --border:rgba(31,45,61,.12); }}
* {{ box-sizing:border-box; margin:0; padding:0; }}
body {{ font-family:'Inter',-apple-system,sans-serif; color:var(--ink); background:var(--cream-soft);
  line-height:1.55; -webkit-font-smoothing:antialiased; }}
header {{ background:var(--navy); color:var(--cream); padding:28px 16px 22px; text-align:center; }}
header h1 {{ font-family:'Cormorant Garamond',serif; font-weight:600; font-size:34px; letter-spacing:.04em; }}
header p {{ font-size:13px; opacity:.8; margin-top:4px; }}
nav {{ position:sticky; top:0; z-index:2; background:var(--cream); border-bottom:1px solid var(--border);
  display:flex; gap:6px; overflow-x:auto; padding:10px 16px; scrollbar-width:none; }}
nav a {{ flex:0 0 auto; font-size:13px; color:var(--navy); text-decoration:none; padding:5px 11px;
  border:1px solid var(--border); border-radius:999px; background:#fff; white-space:nowrap; }}
main {{ max-width:760px; margin:0 auto; padding:8px 16px 40px; }}
section {{ scroll-margin-top:56px; padding-top:22px; }}
h2 {{ font-family:'Cormorant Garamond',serif; font-weight:600; font-size:24px; color:var(--navy);
  border-bottom:1px solid var(--gold); padding-bottom:4px; margin-bottom:6px; }}
ul {{ list-style:none; }}
.item {{ padding:12px 0; border-bottom:1px solid var(--border); }}
.row {{ display:flex; justify-content:space-between; gap:12px; align-items:baseline; }}
h3 {{ font-size:15.5px; font-weight:600; }}
.price {{ font-weight:600; color:var(--navy); white-space:nowrap; font-variant-numeric:tabular-nums; }}
.price small {{ font-weight:400; color:var(--muted); }}
.sig {{ font-size:11px; font-weight:600; color:var(--gold); text-transform:uppercase; letter-spacing:.06em; margin-left:4px; }}
.desc {{ font-size:14px; color:#3b4250; margin-top:2px; }}
.note {{ font-size:13px; color:var(--muted); font-style:italic; margin-top:2px; }}
.meta {{ display:flex; flex-wrap:wrap; gap:6px; margin-top:6px; align-items:center; }}
.b {{ font-size:11.5px; padding:1px 8px; border-radius:999px; }}
.b-diet {{ background:#e7efe8; color:#3f5a45; }}
.b-spicy {{ background:#f8e3dc; color:#9a3b20; }}
.b-svc {{ background:#ecebf4; color:#434070; }}
.alg {{ font-size:12px; color:var(--muted); }}
.notice {{ background:#fff; border:1px solid var(--border); border-left:3px solid var(--gold); border-radius:8px;
  padding:12px 14px; font-size:13.5px; margin-top:18px; }}
footer {{ font-size:12.5px; color:var(--muted); text-align:center; padding:0 16px 32px; max-width:760px; margin:0 auto; }}
</style>
</head>
<body>
<header>
  <h1>FLAMES</h1>
  <p>Beach grill &amp; bar · Talay Cliff Resort &amp; Spa, Koh Samui</p>
  <p>{hours}</p>
</header>
<nav aria-label="Menu sections">{nav}</nav>
<main>
  <div class="notice">Please inform our team of any allergy or dietary requirement before ordering. Allergens listed are the 14 major allergens; our kitchen handles all of them, so cross-contact cannot be fully excluded. All prices in Thai Baht, subject to 10% service charge and applicable taxes.</div>
  {"".join(body)}
</main>
<footer>Demo menu for the Khun Aran concierge. Fictional restaurant and prices.</footer>
</body>
</html>
"""


# ---------- seed for menu_items ----------

ALL_SERVICES = ["lunch", "afternoon", "dinner"]


def sql_text(v):
    return "'" + v.replace("'", "''") + "'"


def sql_array(values):
    return "ARRAY[" + ", ".join(sql_text(v) for v in values) + "]::TEXT[]" if values else "'{}'::TEXT[]"


def sql_date(v):
    return sql_text(v) + "::DATE" if v else "NULL"


def seed_sql(food, drinks):
    rows = []
    for kind, items in (("food", food), ("drink", drinks)):
        for r in items:
            service = ALL_SERVICES if kind == "drink" or r["service"] == "all_day" else split(r["service"])
            rows.append("(" + ", ".join([
                sql_text(r["id"]), sql_text(kind), sql_text(r["section"]), sql_text(r["name"]),
                sql_text(r["description"]), str(int(r["price_thb"] or 0)),
                sql_text(r["unit"]) if r.get("unit") else "NULL",
                sql_array(service), sql_array(split(r["allergens"])), sql_array(split(r.get("diet", ""))),
                str(int(r.get("spicy") or 0)), sql_array(split(r["contains"])),
                "true" if r["available"] == "yes" else "false",
                sql_date(r.get("available_from", "")), sql_date(r.get("available_to", "")),
                sql_text(r["notes"]),
            ]) + ")")
    return ("-- Generated by scripts/build_menu.py from data/menu/*.csv. Do not edit by hand.\n"
            "-- Replaces the whole menu atomically.\nBEGIN;\nDELETE FROM menu_items;\n"
            "INSERT INTO menu_items (id, kind, section, name, description, price_thb, unit, service,"
            " allergens, diet, spicy, contains, available, available_from, available_to, notes) VALUES\n"
            + ",\n".join(rows) + ";\nCOMMIT;\n")


def main():
    today = date.today()
    food = [r for r in read("food.csv") if is_listed(r, today)]
    drinks = [r for r in read("drinks.csv") if is_listed(r, today)]
    venue = {r["key"]: r["value"] for r in read("venue.csv")}
    (ROOT / "deploy" / "web" / "carta.html").write_text(page(food, drinks, venue))
    (MENU / "menu_prompt.txt").write_text(prompt_block(food, drinks, today))
    (MENU / "seed_menu_items.sql").write_text(seed_sql(read("food.csv"), read("drinks.csv")))
    print(f"{len(food)} dishes, {len(drinks)} drinks (as of {today})")


if __name__ == "__main__":
    main()
