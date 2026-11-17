# Generates 01-database.dot from the tables in backend/app/models: python3 gen_database.py > 01-database.dot
import sys

# (table, [(col, type, flags)]) grouped by module; flags: PK FK UQ ENC GEO
M = {
 "Users": ("#FDECEE", [
  ("users", [("id","uuid","PK"),("email","citext","UQ"),("password_hash","varchar(255)",""),("name","varchar(120)",""),("phone","varchar(20)",""),("role","user_role",""),("created_at","timestamptz",""),("updated_at","timestamptz","")]),
  ("devices", [("id","uuid","PK"),("user_id","uuid","FK"),("apns_token","varchar(255)","UQ"),("platform","platform",""),("created_at","timestamptz","")]),
 ]),
 "Medical profile": ("#EAF3FB", [
  ("medical_profiles", [("user_id","uuid","PK FK"),("full_name","varchar(120)",""),("date_of_birth","date",""),("blood_type","blood_type",""),("allergies","bytea","ENC"),("conditions","bytea","ENC"),("medications","bytea","ENC"),("qr_token","varchar(64)","UQ"),("updated_at","timestamptz","")]),
  ("emergency_contacts", [("id","uuid","PK"),("user_id","uuid","FK"),("name","varchar(120)",""),("relationship","varchar(60)",""),("phone","varchar(20)",""),("position","int","")]),
  ("dependent_profiles", [("id","uuid","PK"),("owner_id","uuid","FK"),("relationship","varchar(60)",""),("full_name","varchar(120)",""),("date_of_birth","date",""),("blood_type","blood_type",""),("allergies","bytea","ENC"),("conditions","bytea","ENC"),("medications","bytea","ENC"),("qr_token","varchar(64)","UQ"),("created_at","timestamptz",""),("updated_at","timestamptz","")]),
  ("dependent_contacts", [("id","uuid","PK"),("dependent_id","uuid","FK"),("name","varchar(120)",""),("relationship","varchar(60)",""),("phone","varchar(20)",""),("position","int","")]),
 ]),
 "Emergency": ("#FFF4E5", [
  ("emergency_reports", [("id","uuid","PK"),("user_id","uuid","FK"),("reporting_for","reporting_for",""),("patient_name","varchar(120)",""),("reason","varchar(255)",""),("injured_count","int",""),("injury","varchar(255)",""),("place","varchar(255)",""),("reference","varchar(255)",""),("mental_state","varchar(60)",""),("breathing","varchar(60)",""),("skin","varchar(60)",""),("transcript","text",""),("ai_summary","text",""),("medical_summary","text",""),("share_token","varchar(32)","UQ"),("location","geography(Point)","GEO"),("address","varchar(255)",""),("status","report_status",""),("sent_at","timestamptz",""),("created_at","timestamptz","")]),
 ]),
 "Family circle": ("#EEF7EE", [
  ("circles", [("id","uuid","PK"),("name","varchar(80)",""),("created_by","uuid","FK"),("created_at","timestamptz","")]),
  ("circle_members", [("circle_id","uuid","PK FK"),("user_id","uuid","PK FK"),("role","circle_role",""),("shares_location","bool",""),("relationship","varchar(40)",""),("joined_at","timestamptz","")]),
  ("circle_invitations", [("id","uuid","PK"),("circle_id","uuid","FK"),("invited_by","uuid","FK"),("contact","varchar(255)",""),("name","varchar(120)",""),("relationship","varchar(40)",""),("token","varchar(64)","UQ"),("status","invitation_status",""),("expires_at","timestamptz",""),("created_at","timestamptz","")]),
  ("user_locations", [("user_id","uuid","PK FK"),("location","geography(Point)","GEO"),("updated_at","timestamptz","")]),
  ("wellbeing_checks", [("id","uuid","PK"),("user_id","uuid","FK"),("requested_by","uuid","FK"),("alert_id","uuid","FK"),("report_id","uuid","FK"),("status","wellbeing_status",""),("created_at","timestamptz",""),("answered_at","timestamptz","")]),
 ]),
 "Alerts": ("#F3EEFA", [
  ("official_alerts", [("id","uuid","PK"),("source","varchar(80)",""),("type","varchar(60)",""),("title","varchar(160)",""),("description","text",""),("area_name","varchar(120)",""),("severity","severity",""),("area","geography(MultiPolygon)","GEO"),("starts_at","timestamptz",""),("expires_at","timestamptz","")]),
  ("community_reports", [("id","uuid","PK"),("user_id","uuid","FK"),("type","community_report_type",""),("details","text",""),("location","geography(Point)","GEO"),("created_at","timestamptz",""),("expires_at","timestamptz","")]),
  ("community_report_confirmations", [("report_id","uuid","PK FK"),("user_id","uuid","PK FK"),("created_at","timestamptz","")]),
  ("community_report_flags", [("report_id","uuid","PK FK"),("user_id","uuid","PK FK"),("created_at","timestamptz","")]),
 ]),
 "Learning": ("#F2F2F2", [
  ("guides", [("id","varchar(80)","PK"),("title","varchar(120)",""),("icon","varchar(80)",""),("keywords","text[]",""),("manual_page","int",""),("position","int",""),("steps","jsonb","")]),
  ("lessons", [("id","uuid","PK"),("title","varchar(120)",""),("description","text",""),("duration_seconds","int",""),("video_url","varchar(500)",""),("guide_id","varchar(80)","FK"),("publisher","text",""),("steps","text[]",""),("position","int","")]),
  ("lesson_completions", [("user_id","uuid","PK FK"),("lesson_id","uuid","PK FK"),("completed_at","timestamptz","")]),
 ]),
}

# (child, fk_col, parent, one_to_one)
FKS = [
 ("devices","user_id","users",0),
 ("medical_profiles","user_id","users",1),
 ("emergency_contacts","user_id","users",0),
 ("dependent_profiles","owner_id","users",0),
 ("dependent_contacts","dependent_id","dependent_profiles",0),
 ("emergency_reports","user_id","users",0),
 ("circles","created_by","users",0),
 ("circle_members","circle_id","circles",0),
 ("circle_members","user_id","users",0),
 ("circle_invitations","circle_id","circles",0),
 ("circle_invitations","invited_by","users",0),
 ("user_locations","user_id","users",1),
 ("wellbeing_checks","user_id","users",0),
 ("wellbeing_checks","requested_by","users",0),
 ("wellbeing_checks","alert_id","official_alerts",0),
 ("wellbeing_checks","report_id","emergency_reports",0),
 ("community_reports","user_id","users",0),
 ("community_report_confirmations","report_id","community_reports",0),
 ("community_report_confirmations","user_id","users",0),
 ("community_report_flags","report_id","community_reports",0),
 ("community_report_flags","user_id","users",0),
 ("lessons","guide_id","guides",0),
 ("lesson_completions","user_id","users",0),
 ("lesson_completions","lesson_id","lessons",0),
]

def pk_col(t):
    for _, (_, tables) in M.items():
        for name, cols in tables:
            if name == t:
                return next(c for c, _, f in cols if "PK" in f)

def table(name, cols):
    rows = [f'<tr><td colspan="3" bgcolor="#C8102E"><font color="white"><b>{name}</b></font></td></tr>']
    for c, ty, f in cols:
        tags = []
        if "PK" in f: tags.append("PK")
        if "FK" in f: tags.append("FK")
        if "UQ" in f: tags.append("UQ")
        if "ENC" in f: tags.append("ENC")
        if "GEO" in f: tags.append("PostGIS")
        col = f"<b>{c}</b>" if "PK" in f else c
        rows.append(f'<tr><td port="{c}" align="left">{col}</td><td align="left"><font color="#555555">{ty}</font></td><td port="{c}_r" align="left"><font color="#C8102E" point-size="9">{" ".join(tags) or " "}</font></td></tr>')
    return f'  {name} [label=<<table border="0" cellborder="1" cellspacing="0" cellpadding="4" bgcolor="white">{"".join(rows)}</table>>];'

out = ['// Generated from backend/app/models; render with: dot -Tpng -Gdpi=200 01-database.dot -o ../png/01-database.png',
       'digraph database {',
       '  graph [rankdir=LR, splines=spline, nodesep=0.5, ranksep=1.6, fontname="Helvetica", label=<<b>Enlace Vital - Database (PostgreSQL + PostGIS on Supabase, RLS on every table)</b>>, labelloc=t, fontsize=22, pad=0.4];',
       '  node [shape=plain, fontname="Helvetica", fontsize=11];',
       '  edge [color="#555555", dir=both, arrowsize=0.9];']
for i, (mod, (color, tables)) in enumerate(M.items()):
    out.append(f'  subgraph cluster_{i} {{ label=<<b>{mod}</b>>; fontsize=16; style="rounded,filled"; fillcolor="{color}"; color="#BBBBBB";')
    for name, cols in tables:
        out.append("  " + table(name, cols))
    out.append('  }')
for child, fk, parent, one in FKS:
    head = "teeodot" if one else "crowodot"
    out.append(f'  {parent}:{pk_col(parent)}_r:e -> {child}:{fk}:w [arrowhead={head}, arrowtail=teetee];')
out.append('  legend [label=<<table border="0" cellborder="0" cellspacing="2" cellpadding="3" bgcolor="white"><tr><td align="left"><b>Legend</b></td></tr><tr><td align="left">PK primary key · FK foreign key · UQ unique</td></tr><tr><td align="left">ENC: encrypted with MEDICAL_DATA_KEY (Fernet)</td></tr><tr><td align="left">PostGIS: geography, SRID 4326, GiST index</td></tr><tr><td align="left">Crow\'s foot: many · bar: one · circle: optional</td></tr></table>>, shape=box, style="rounded", color="#BBBBBB"];')
out.append('}')
sys.stdout.write("\n".join(out) + "\n")
