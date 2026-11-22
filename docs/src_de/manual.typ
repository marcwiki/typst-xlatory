
#import "/lib/mod.typ": (
  layout-regex-box,
  layout-title-page,
  layout-body-text,
  title-author,
  title-main,
  title-sub,
  title-note,
  title-publisher,
  book-template,
  meta-teaser,
  question-cursive,
  dropcap-par,
  summary-box,
  two-column-row,
  speaker,
  small-note,
  align-right,
)

// 1. Titelseiten-Layout aktivieren (ohne [...] um den Inhalt!)
#show: layout-title-page

#title-author[Marc Günthardt] <title:author>

#title-main[typst-xlatory] <title:main>

#title-sub[Verlustfreie Roundtrip-Übersetzung für Typst-Bücher] <title:sub>

#title-note[Handbuch & Referenzprojekt] <title:note>

#title-publisher[Version 0.96 — Open-Source-Dokumentation] <title:pub>

#pagebreak()

// 2. Normales Seiten- und Absatz-Layout wiederherstellen
#show: book-template.with(lang: "de", book-title: "typst-xlatory")

#show: layout-body-text

#outline(
  title: [Inhaltsverzeichnis],
  target: heading.where(level: 1).or(heading.where(level: 2)),
  depth: 2,
)

#pagebreak()

= Eine Umgebung zur Erstellung und Übersetzung von PDF Dokumenten <h1_id_1>

== Zielsetzung <h2_id_2:cl-numbered>

- Die erstellten PDF Dokumente sollen bis ins Detail kontrollierbar und definierbar sein.<p_id_3>

- Die Umgebung soll die effiziente Bereitstellung von Dokumenten in mehreren Sprachen ermöglichen.<p_id_4>

- Der Fokus liegt auf Textinhalten, mathematische Formeln werden nicht unterstützt.<p_id_5>

- Ein späterer Ausbau zur automatisierten Erstellung von alternativen Formaten wie HTML oder Obidian Markdown soll mit vernünftigem Aufwand möglich sein. <p_id_6>

- Es sollen ausschliesslich Open Source Komponenten zum Einsatz kommen.<p_id_7>

== Entstehungsgeschichte und Architektur<h2_id_8:cl-numbered>

#dropcap-par[Zu Beginn nahm ich an, dass der EPUB 3 Standard eine sinnvolle Basis sein könnte, und habe mit allerlei PDF Generatoren versucht, ein komplexeres Format zu erstellen. Dies gelang mir einzig mit dem Prince-Generator einigermassen, was leider nicht Open Source ist, und auch sehr aufwendig werden kann, wenn die Vorgaben komplex sind. Die Idee war für mich verlockend, eine Single Source of Truth im Epub 3 Format, und daraus sollten die PDF-Formate erstellt werden. Ein Buch wäre so automatisch als Print-Medium wie auch als Epub verfügbar. Da ein Epub intern HTML verwendet, war die Einbindung von OmegaT als Übersetzhungsumgebung gut unterstützt. Diesen Ansatz musst ich irgendwann als gescheitert betrachten, da die mir verfügbaren Open Source PDF Generatoren eine präzise Gestaltung von PDF-Formaten nicht unterstützt haben.] <p_id_9>

Also habe ich meinen Blickwinkel darauf gerichtet, welche Umgebungen es überhaupt gibt, die eine effiziente und präzise Umsetzung von PDF Formaten erlauben. Dabei bin ich auf Typst gestossen, das meistens in akademischen Umgebungen verwendet wird, und unter vielem anderen auch die Darstellung von mathematischen Formeln erlaubt. Auf jeden Fall unterstützt Typst die Umsetzung von Texten nach PDF bestens, man muss ja nicht das ganze Funktionsspektrum nutzen. Ein weiterer grosser Vorteil von Typst liegt in seinen Möglichkeiten zur Standardisierung und Vereinheitlichung von Formaten. Bei der Übersetzung einer ganzen Buchreihe mit ähnlichen oder gleichen Formaten kann man so auf eine einzige Bibliothek von Formatierungsfunktionen zurückgreifen, und alle Bücher der Reihe werden in allen Sprachen gleich formatiert, sofern die Sprachen von links nach rechts und von oben nach unten geschrieben werden.<p_id_10>

Allerdings konnte ich zunächst meine OmegaT Übersetzungsumgebung nicht auf Typst-Dateien anwenden, es gab keine Filter mit ausreichender Funktionalität. Also habe ich ein Programm geschrieben, das Typst-Dateien in eine für OmegaT lesbare Struktur bringt. Dabei erhält jeder Absatz in Typst ein Label mit einer ID, und diese ID ist dann der Schlüssel zu den Texten in OmegaT. Ein Zusatzprogramm nimmt das Originaldokument und die übersetzten Texte und erstellt daraus ein übersetztes Dokument, das genau so formatiert ist wie das Original.<p_id_11>

Damit ist das Typst-Originaldokument meine "Single Source of Truth" und gibt die Struktur sowie das Format vor für daraus abgeleiteten, übersetzten Dokumente.<p_id_12>

Da ich den von mir verwendeten Sprachumfang von Typst mittlerweile recht gut kenne, könnte ich statt der Schlüssel-Wert-Paare wahlweise auch andere Formate generieren, zum Beispiel HTML oder Obsidian Markup. Einem Ausbau zur Generierung von alternativen Formaten steht also nichts im Wege. <p_id_13>

= Einführung und Motivation <h1:einfuehrung>

#meta-teaser[Wie lassen sich mehrsprachige Bücher in Typst pflegen, ohne Layout und Inhalt zu entkoppeln?] <teaser:intro>

#question-cursive[Warum scheitert das einfache Kopieren von Typst-Dateien bei wachsenden Buchprojekten?] <q:intro>

#dropcap-par[Wer ein Buch oder eine umfangreiche Dokumentation in Typst schreibt und in mehrere Sprachen übersetzen möchte, stösst schnell auf ein klassisches Problem. Kopiert man die `.typ`-Dateien für jede Sprache und übersetzt direkt im Quelltext, laufen Layout und Inhalt auseinander.] <p:intro-1>

Jede spätere Anpassung an Schriftgrössen, Abständen oder Makros muss dann mühsam in jeder einzelnen Sprachdatei nachgezogen werden. Gleichzeitig fehlen in einem reinen Texteditor wichtige Werkzeuge professioneller Übersetzer wie Translation Memories und Terminologie-Datenbanken. <p:intro-2>

== Die Lösung: Trennung von Inhalt und Layout <h2:loesung>

#dropcap-par[Dieses Werkzeug schlägt eine Brücke zwischen der modernen Satzwelt von Typst und etablierten Übersetzungsprogrammen (CAT-Tools). Statt rohe Typst-Dateien manuell zu duplizieren, extrahiert der Transpiler ausschliesslich die übersetzbaren Texte in standardisierte Java-`.properties`-Dateien.] <p:loesung-1>

Nach der Übersetzung setzt der Reconstructor die Zieltexte wieder exakt in die ursprüngliche Typst-Struktur ein. Alle Layout-Anweisungen, Abstände, Verweise und benutzerdefinierten Funktionen bleiben dabei vollständig erhalten. <p:loesung-2>

== Tool-Unabhängigkeit (Loose Coupling) <h2:loose-coupling>

#dropcap-par[Das System ist bewusst nicht an ein bestimmtes Übersetzungsprogramm gebunden. Da als Austauschformat gewöhnliche `.properties`-Dateien dienen, lässt sich der Workflow problemlos mit Programmen wie OmegaT, Poedit, Weblate oder Crowdin verbinden.] <p:coupling-1>

Wechselt ein Autor später das Übersetzungswerkzeug, bleiben sämtliche Typst-Quelldateien und die Projekt-Konfiguration unverändert. <p:coupling-2>

= Installation und Voraussetzungen <h1:installation>

#dropcap-par[Für den Einsatz der Übersetzungs-Pipeline werden drei Komponenten auf dem System benötigt:] <p:inst-1>

- *Typst*: Zum Kompilieren der fertigen `.typ`-Dateien in druckfertige PDF-Dokumente. <p:inst-list-1>

- *Ein CAT-Tool*: Zum Beispiel das kostenlose Open-Source-Programm OmegaT für die eigentliche Übersetzungsarbeit. <p:inst-list-2>

- *typst-xlatory*: Das kompilierte Kommandozeilen-Werkzeug für den Export und Import der Texte. <p:inst-list-3>

== Empfohlene Verzeichnisstruktur <h2:verzeichnisstruktur>

#dropcap-par[Damit Vorlagen, Originaltexte, Übersetzungsdateien und fertige Sprachausgaben sauber getrennt bleiben, empfiehlt sich folgende Ordnerstruktur pro Buchprojekt:] <p:dir-1>

#raw(
  block: true,
  "mein-buch/\n├── projekt.yaml\n├── lib/\n├── src_de/\n├── i18n/\n│   ├── source/\n│   ├── target_en/\n│   └── target_ru/\n├── out_en/\n└── out_ru/",
) <raw:dir-tree>

Die einzelnen Verzeichnisse erfüllen folgende Aufgaben: <p:dir-2>

- *`projekt.yaml`*: Zentrale Konfigurationsdatei für Pfade und Übersetzungsregeln. <p:dir-list-1>

- *`lib/`*: Gemeinsame Typst-Vorlagen und Layout-Makros für alle Sprachen. <p:dir-list-2>

- *`src_de/`*: Originaltexte des Buches in der Quellsprache. <p:dir-list-3>

- *`i18n/source/`*: Exportierte `.properties`-Dateien als Eingabe für das CAT-Tool. <p:dir-list-4>

- *`i18n/target_en/` und `i18n/target_ru/`*: Übersetzte `.properties`-Dateien aus dem CAT-Tool. <p:dir-list-5>

- *`out_en/` und `out_ru/`*: Rekonstruierte, kompilierbare Typst-Dateien in den Zielsprachen. <p:dir-list-6>

Alle rekonstruierten Sprachversionen greifen über relative Pfade auf denselben `lib/`-Ordner zu. Eine Design-Änderung in der Vorlage wirkt sich dadurch sofort auf sämtliche Sprachausgaben aus. <p:dir-2>

= Schnellstart <h1:schnellstart>

#dropcap-par[In fünf kurzen Schritten entsteht aus einem deutschen Typst-Dokument eine mehrsprachige Publikation.] <p:quick-1>

== Schritt 1: Quelldatei mit Labels anlegen <h2:schritt-1>

#dropcap-par[Lege im Ordner `src_de/` eine Datei `kapitel1.typ` an und versehe Überschriften sowie Absätze mit eindeutigen Labels in spitzen Klammern:] <p:s1-1>

#raw(
  block: true,
  "= Mein erstes Kapitel <h1:kapitel-1>\n\nDies ist ein Beispielabsatz mit *fettgedrucktem* Text. <p:absatz-1>",
) <raw:s1-code>

== Schritt 2: Projekt-Konfiguration erstellen <h2:schritt-2>

#dropcap-par[Erstelle im Hauptordner des Projekts eine Datei `projekt.yaml`, welche die Verzeichnisse und Zielsprachen festlegt:] <p:s2-1>

#raw(
  block: true,
  "project:\n  source_dir: \"src_de\"\n  i18n_source_dir: \"i18n/source\"\n\ntargets:\n  - lang: \"en\"\n    i18n_target_dir: \"i18n/target_en\"\n    output_dir: \"out_en\"\n  - lang: \"ru\"\n    i18n_target_dir: \"i18n/target_ru\"\n    output_dir: \"out_ru\"",
) <raw:s2-code>

== Schritt 3: Texte für die Übersetzung exportieren <h2:schritt-3>

#dropcap-par[Starte den Export über die Kommandozeile:] <p:s3-1>

#raw(
  block: true,
  "typst-json-printer --config projekt.yaml",
) <raw:s3-code>

Im Ordner `i18n/source/` liegt nun die Datei `kapitel1.properties` mit allen extrahierten Textsegmenten bereit. <p:s3-2>

== Schritt 4: Übersetzung im CAT-Tool durchführen <h2:schritt-4>

#dropcap-par[Lade die Datei `kapitel1.properties` in dein Übersetzungsprogramm (z. B. OmegaT) und erzeuge nach der Übersetzung die Zieldateien in `i18n/target_en/` beziehungsweise `i18n/target_ru/`.] <p:s4-1>

== Schritt 5: Zielsprachen rekonstruieren und PDF bauen <h2:schritt-5>

#dropcap-par[Führe abschliessend den Import-Befehl aus und kompiliere die erzeugten Typst-Dateien:] <p:s5-1>

#raw(
  block: true,
  "typst-json-printer --config projekt.yaml --import\ntypst compile out_en/kapitel1.typ\ntypst compile out_ru/kapitel1.typ",
) <raw:s5-code>

In den Zielordnern stehen nun fertige Typst-Dateien und PDFs in allen konfigurierten Sprachen bereit. <p:s5-2>

= Typst für die Übersetzung strukturieren <h1:best-practices>

#dropcap-par[Damit der Roundtrip zwischen Typst und dem CAT-Tool auch bei grösseren Buchprojekten zuverlässig funktioniert, haben sich einige Grundregeln für das Schreiben der Quelldateien bewährt.] <p:bp-1>

== Eindeutige Labels nutzen <h2:labels>

#dropcap-par[Jede Überschrift, jeder Absatz und jede übersetzbare Funktion sollte mit einem eindeutigen Label in spitzen Klammern abgeschlossen werden, beispielsweise `<p:einleitung-1>` oder `<box:merksatz-2>`.] <p:labels-1>

Ohne explizites Label vergibt der Transpiler automatisch fortlaufende Nummern. Fügt ein Autor später mitten im Kapitel einen neuen Absatz ein, verschieben sich alle nachfolgenden Nummern, was im CAT-Tool zu falschen Zuordnungen führen kann. <p:labels-2>

Mit festen Labels bleibt jedes Textsegment dauerhaft an seinen Bezeichner gebunden, unabhängig davon, wo im Dokument Absätze ergänzt oder verschoben werden. <p:labels-3>

== Information Hiding anwenden <h2:information-hiding>

#dropcap-par[Komplexe Layout-Anweisungen wie `#set par(...)`, `#show ...` oder verschachtelte `#block(...)`-Container gehören nicht direkt in den Fliesstext. Lagere solche Formatierungen konsequent als benannte Funktionen in deine Vorlagendatei im `lib/`-Ordner aus.] <p:ih-1>

Im eigentlichen Kapiteltext rufst du anschliessend nur noch kompakte, einzeilige Makros auf. Dadurch sieht der Übersetzer im CAT-Tool ausschliesslich den reinen Inhalt ohne störenden Layout-Code. <p:ih-2>

== Eigene Typst-Funktionen gestalten <h2:eigene-funktionen>

#dropcap-par[Eigene Layout-Komponenten wie Infoboxen, Zitatkästen oder Fazit-Blöcke werden vom Transpiler automatisch erkannt. Übergibst du den Haupttext in eckigen Klammern, exportiert ihn das Werkzeug direkt als übersetzbares Segment.] <p:fn-1>

Zusätzlich erkennt der Transpiler alle benannten Argumente, deren Wert in doppelten Anführungszeichen steht. Ein Aufruf wie `#fazit(title: "Zusammenfassung:")[Der eigentliche Inhalt.] <box:fazit-1>` erzeugt automatisch zwei getrennte Einträge in der `.properties`-Datei: einen für den Titel und einen für den Inhalt. <p:fn-2>

== Layout-Umschalter per `#show` statt Container-Klammern <h2:show-vs-container>

#dropcap-par[Sollen für einen Dokumentabschnitt spezielle Seitenränder oder Absatzregeln gelten (etwa für die Titelseite oder den Hauptteil), dürfen diese Layout-Funktionen nicht als grosse Container in eckigen Klammern um ganze Kapitel gelegt werden.] <p:show-1>

Der Transpiler behandelt den Inhalt innerhalb eckiger Klammern als einzelnes zusammenhängendes Textsegment und zerlegt darin verschachtelte Überschriften oder weitere Makros nicht weiter. <p:show-2>

Nutze stattdessen die Typst-Anweisung `#show:`, um ein Layout für den nachfolgenden Text zu aktivieren, ohne den Dokumentbaum zu verschachteln: <p:show-3>

#raw(
  block: true,
  "#show: layout-title-page\n\n#title-main[Mein Buchtitel] <title:main>\n\n#pagebreak()\n\n#show: layout-body-text",
) <raw:show-example>

Auf diese Weise bleiben alle Überschriften, Absätze und Funktionsaufrufe auf der obersten Ebene erhalten und werden als separate Segmente an das CAT-Tool übergeben. <p:show-4>

= Konfigurations-Referenz <h1:konfiguration>

#dropcap-par[Das gesamte Verhalten der Export- und Import-Pipeline wird über eine zentrale YAML-Datei gesteuert. Über den Parameter `--config` lässt sich für jedes Buchprojekt eine eigene Konfigurationsdatei angeben.] <p:cfg-1>

#summary-box(
  title: "Merksatz:",
)[Stabile Labels und ausgelagerte Makros sorgen dafür, dass Übersetzer im CAT-Tool ausschliesslich reinen Inhalt bearbeiten, während das Buchlayout zentral gesteuert bleibt.] <box:bp-summary>


== Bereich project <h2:cfg-project>

#dropcap-par[Unter `project` werden die gemeinsamen Ausgangsverzeichnisse des Projekts festgelegt:] <p:cfg-proj-1>

- *`source_dir`*: Pfad zum Verzeichnis mit den Typst-Quelldateien in der Originalsprache. <p:cfg-proj-list-1>

- *`i18n_source_dir`*: Zielordner, in den die generierten `.properties`-Dateien für das CAT-Tool geschrieben werden. <p:cfg-proj-list-2>

== Bereich targets <h2:cfg-targets>

#dropcap-par[Unter `targets` lässt sich eine beliebige Anzahl an Zielsprachen definieren. Beim Aufruf mit `--import` verarbeitet das Werkzeug alle aufgeführten Sprachen in einem einzigen Durchgang:] <p:cfg-tgt-1>

- *`lang`*: Kurzbezeichnung der Zielsprache zur Protokollierung auf der Konsole (zum Beispiel `en` oder `ru`). <p:cfg-tgt-list-1>

- *`i18n_target_dir`*: Verzeichnis, in dem das CAT-Tool die übersetzten `.properties`-Dateien dieser Sprache ablegt. <p:cfg-tgt-list-2>

- *`output_dir`*: Zielverzeichnis für die fertig rekonstruierten Typst-Dateien der jeweiligen Sprache. <p:cfg-tgt-list-3>

== Bereich hide_functions <h2:cfg-hide>

#dropcap-par[Funktionen, die ausschliesslich das Layout steuern und keinen übersetzbaren Text enthalten (wie `pagebreak`, `outline`, `v` oder `h`), werden unter `hide_functions` aufgelistet. Diese Aufrufe werden beim Export übersprungen und beim Import unverändert in das Zieldokument übernommen.] <p:cfg-hide-1>

== Bereich ignore_named_args <h2:cfg-ignore-args>

#dropcap-par[Manche Typst-Funktionen erwarten technische Parameter als Textzeichenkette, etwa `font: "Libertinus Serif"` oder `align: "left"`. Damit solche Steuerwerte nicht versehentlich im CAT-Tool zur Übersetzung angeboten werden, lassen sich deren Argumentnamen unter `ignore_named_args` ausschliessen.] <p:cfg-ign-1>

= Praxisbeispiel aus der Buchproduktion <h1:praxisbeispiel>

#dropcap-par[Dieses Handbuch selbst dient als vollständiges Referenzprojekt für den beschriebenen Workflow. Der deutsche Ausgangstext befindet sich im Verzeichnis `docs/src_de/`, während die Layout-Komponenten zentral in `docs/lib/` gepflegt werden.] <p:praxis-1>

Aus dieser einzigen Quelle werden über die Konfigurationsdatei `docs/docs.yaml` die englische und die russische Fassung generiert. Beide Zielversionen binden dieselben Makros ein und erreichen dadurch ohne manuelle Nachbearbeitung ein identisches Druckbild. <p:praxis-2>

== Live-Demonstration der Layout-Komponenten <h2:live-demo>

#dropcap-par[Die folgende Übersicht zeigt das Zusammenspiel von zweispaltigen Zeilen und Dialog-Makros im mehrsprachigen Satz:] <p:demo-1>

#two-column-row(
  label: [*Autor*],
)[Schreibt den deutschen Ausgangstext einmalig mit festen Labels.] <row:demo-1>
#two-column-row(
  label: [*Tool*],
)[Extrahiert alle Segmente verlustfrei in standardisierte `.properties`-Dateien.] <row:demo-2>

#v(5mm)

#speaker(big-indent: true)[Autor:] <spk:author>

#dropcap-par[Ich habe gerade im dritten Kapitel einen neuen Absatz eingefügt. Muss ich jetzt alle Übersetzungen neu ordnen?] <p:dlg-1>

#speaker(big-indent: true)[Übersetzer:] <spk:translator>

#dropcap-par[Nein, dank der festen Labels bleiben alle bestehenden Sätze im Translation Memory erhalten.] <p:dlg-2>

#small-note[Hinweis: Alle gezeigten Blöcke stammen direkt aus der Vorlagen-Bibliothek unter `docs/lib/`.] <note:demo>

#align-right[Stand: November 2026 — Open-Source-Referenz] <right:date>

= Fehlerbehebung und Tipps für den Buchalltag <h1:troubleshooting>

#dropcap-par[In der täglichen Arbeit mit wachsenden Buchmanuskripten helfen folgende Hinweise, typische Stolpersteine schnell zu lösen:] <p:ts-1>

- *Nachträgliche Korrekturen im Original*: Ändert sich ein Satz im deutschen Ausgangstext, genügt ein erneuter Export. Im CAT-Tool bleiben alle unveränderten Sätze dank des Translation Memories als exakte Treffer erhalten, sodass nur der geänderte Satz neu übersetzt werden muss. <p:ts-list-1>

- *Fehlende Übersetzung im Zieldokument*: Erscheint im rekonstruierten Typst-Dokument der Platzhalter `DE_TRANSLATION_MISSING`, wurde der entsprechende Eintrag im CAT-Tool noch nicht übersetzt oder die Zieldatei nach der Übersetzung noch nicht neu geschrieben. <p:ts-list-2>

- *Sonderzeichen und Formatierungen*: Inline-Formatierungen wie `*bold*`, `_italic_` oder Querverweise (`#link(...)`) werden vom Parser erkannt und als geschützte Tags an das CAT-Tool übergeben. Achte beim Übersetzen darauf, diese Tags an den passenden Stellen im Zielsatz beizubehalten. <p:ts-list-3>

== In OmegaT die Pfade für source und target einrichten <h2:omegat-paths>

Anstatt sich unter Windows durch die verschachtelten Datei-Dialoge von OmegaT zu klicken, kannst man die Pfade für source und target bei geschlossenem OmegaT auch direkt mit einem Texteditor in der Datei omegat.project (im jeweiligen externen OmegaT-Projektordner) anpassen. Dort stehen die Pfade als simple XML-Tags (`<source_dir>...</source_dir>` und `<target_dir>...</target_dir>`), was deutlich schneller und fehlerfreier funktioniert.

== Geschützte Tags in OmegaT einrichten <h2:omegat-tags>

#dropcap-par[Damit Inline-Formatierungen und Code-Schnipsel in Backticks wie `.typ` sowie interne Typst-Verweise beim Übersetzen nicht versehentlich verändert werden, sollten sie in OmegaT als benutzerdefinierte Tags geschützt werden.] <p:ot-tags-1>

Öffne dazu in OmegaT das Menü *Optionen* -> *Einstellungen* -> *Tag-Verarbeitung* und trage folgenden regulären Ausdruck in das Feld *Regulärer Ausdruck für benutzerdefinierte Tags* ein: <p:ot-tags-2>

#layout-regex-box()

Achte beim Einfügen darauf, dass sich am Anfang und am Ende der Zeile kein versehentliches Leerzeichen befindet, da dieses sonst als leeres Tag gewertet wird. Lade das Projekt anschliessend mit der Taste `F5` neu, um die neuen Tags sofort sichtbar zu machen. <p:ot-tags-3>

Wähle auch die Checkbox "Übersetzte Tags dürfen anders angeordnet sein".<p:ot-tags-4>


