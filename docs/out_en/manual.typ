#import "../lib/mod.typ": (
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

#title-author[Marc Gänthardt] <title:author>

#title-main[typst-xlatory] <title:main>

#title-sub[Lossless round-trip translation for Typst books] <title:sub>

#title-note[Manual & Sample Project] <title:note>

#title-publisher[Version 0.96 — Open-Source Documentation] <title:pub>

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

= An environment for creating and translating PDF documents <h1_id_1>

== Objective <h2_id_2:cl-numbered>

- The PDF documents generated should be fully controllable and customizable down to the finest detail. <p_id_3>

- The environment should enable the efficient delivery of documents in multiple languages. <p_id_4>

\n- The focus is on text content; mathematical formulas are not supported. <p_id_5>

- A future expansion to enable the automated generation of alternative formats, such as HTML or Obisian Markdown, should be possible with a reasonable amount of effort. <p_id_6>

- Only open-source components should be used. <p_id_7>

== History and Architecture <h2_id_8:cl-numbered>

#dropcap-par[\nAt first, I assumed that the EPUB 3 standard might be a good starting point, so I tried using all kinds of PDF generators to create a more complex format. I was only able to do this reasonably well using the Prince Generator, which, unfortunately, is not open source and can also be very time-consuming when the specifications are complex. I found the idea appealing—a single source of truth in the EPUB 3 format, from which the PDF files would be generated. \nA book would automatically be available both as a print publication and as an ePub. Since an ePub uses HTML internally, the integration of OmegaT as a translation environment was well supported. At some point, I had to conclude that this approach had failed, since the open-source PDF generators available to me did not support precise formatting of PDF files.] <p_id_9>

So I focused my attention on identifying which environments actually exist that allow for the efficient and precise implementation of PDF formats. In the process, I came across Typst, which is mostly used in academic settings and, among other things, allows for the display of mathematical formulas. In any case, Typst does an excellent job of converting text to PDF—you don't have to use the full range of features. Another major advantage of Typst is its ability to standardize and unify formats. When translating an entire book series with similar or identical formats, you can use a single library of formatting functions, and all books in the series will be formatted identically in all languages, provided those languages are written from left to right and top to bottom. <p_id_10>

However, at first I was unable to use my OmegaT translation environment with Typst files; there were no filters with sufficient functionality. So I wrote a program that converts Typst files into a format that OmegaT can read. \nIn this process, each paragraph in Typst is assigned a label with an ID, and this ID then serves as the key to the texts in OmegaT. A separate program takes the translated texts and uses the original document and these texts to create a translated document that is formatted exactly like the original. <p_id_11>

\nThis makes the original Typst document my “single source of truth” and defines the structure and format for all translated documents. <p_id_12>

Since I'm quite familiar with the language features I use in Typst, I could optionally generate other formats instead of key-value pairs—for example, HTML or Obisian Markup. <p_id_13>

= Introduction and Motivation <h1:einfuehrung>

#meta-teaser[How can multilingual books be managed in Typst without separating the layout from the content?] <teaser:intro>

#question-cursive[Why does simply copying Typst files fail as book projects grow?] <q:intro>

#dropcap-par[Anyone who writes a book or a lengthy document in Typst and wants to translate it into multiple languages will quickly run into a common problem. If you copy the  `.typ`  files for each language and translate directly in the source code, the layout and content will become mismatched.] <p:intro-1>

Any subsequent adjustments to font sizes, spacing, or macros must then be painstakingly applied to each individual language file. At the same time, a basic text editor lacks important tools used by professional translators, such as translation memories and terminology databases. <p:intro-2>

== The Solution: Separating Content from Layout <h2:loesung>

#dropcap-par[This tool bridges the gap between Typst's modern typesetting environment and established translation software (CAT tools). Instead of manually duplicating raw Typst files, the transpiler extracts only the translatable text into standardized Java  `.properties`  files.] <p:loesung-1>

After translation, the Reconstructor reinsert the target texts exactly into the original Typst structure. All layout instructions, spacing, references, and user-defined functions are fully preserved in the process. <p:loesung-2>

== Tool Independence (Loose Coupling) <h2:loose-coupling>

#dropcap-par[The system is intentionally not tied to any specific translation program. Since standard  `.properties`  files are used as the exchange format, the workflow can be easily integrated with programs such as OmegaT, Poedit, Weblate, or Crowdin.] <p:coupling-1>

If an author switches to a different translation tool later on, all Typst source files and the project configuration remain unchanged. <p:coupling-2>

= Installation and Prerequisites <h1:installation>

#dropcap-par[To use the translation pipeline, three components are required on the system:] <p:inst-1>

- *Typst*  : To compile the finished  `.typ`  files into print-ready PDF documents. <p:inst-list-1>

-  *A CAT tool* : For example, the free, open-source program OmegaT for the actual translation work. <p:inst-list-2>

-  *typst-json-printer*  : The compiled command-line tool for exporting and importing text. <p:inst-list-3>

== Recommended Directory Structure <h2:verzeichnisstruktur>

#dropcap-par[To ensure that templates, source texts, translation files, and finished language versions remain clearly separated, we recommend the following folder structure for each book project:] <p:dir-1>

#raw(block: true, "mein-buch/\n├── projekt.yaml\n├── lib/\n├── src_de/\n├── i18n/\n│   ├── source/\n│   ├── target_en/\n│   └── target_ru/\n├── out_en/\n└── out_ru/") <raw:dir-tree>

All reconstructed language versions access the same  `lib/`  folder via relative paths. As a result, a design change in the template immediately affects all language versions. <p:dir-2>

-  *`projekt.yaml`*  : Central configuration file for paths and translation rules. <p:dir-list-1>

-  *`lib/`*  : Shared Typest-templates and layout macros for all languages. <p:dir-list-2>

-  *`src_de/`* : Original texts from the book in the source language. <p:dir-list-3>

-  *`i18n/source/`*  : Exported  `.properties`  files as input for the CAT tool. <p:dir-list-4>

-  *`i18n/target_en/`  and  `i18n/target_ru/`* : Translated  `.properties`  files from the CAT tool. <p:dir-list-5>

-  *`out_en/`  and  `out_ru/`* : Reconstructed, compilable TypeST files in the target languages. <p:dir-list-6>

All reconstructed language versions access the same  `lib/`  folder via relative paths. As a result, a design change in the template immediately affects all language versions. <p:dir-2>

= Quick Start <h1:schnellstart>

#dropcap-par[In five quick steps, a German Typst document is transformed into a multilingual publication.] <p:quick-1>

== Step 1: Create a source file with labels <h2:schritt-1>

#dropcap-par[Create a file named  `kapitel1.typ`  in the  `src_de/`  folder and assign unique labels in angle brackets to headings and paragraphs:] <p:s1-1>

#raw(block: true, "= Mein erstes Kapitel <h1:kapitel-1>\n\nDies ist ein Beispielabsatz mit *fettgedrucktem* Text. <p:absatz-1>") <raw:s1-code>

== Step 2: Create a project configuration <h2:schritt-2>

#dropcap-par[In the project's main folder, create a file named  `projekt.yaml`  that specifies the directories and target languages:] <p:s2-1>

#raw(block: true, "project:\n  source_dir: \"src_de\"\n  i18n_source_dir: \"i18n/source\"\n\ntargets:\n  - lang: \"en\"\n    i18n_target_dir: \"i18n/target_en\"\n    output_dir: \"out_en\"\n  - lang: \"ru\"\n    i18n_target_dir: \"i18n/target_ru\"\n    output_dir: \"out_ru\"") <raw:s2-code>

== Step 3: Export text for translation <h2:schritt-3>

#dropcap-par[Start the export from the command line:] <p:s3-1>

#raw(block: true, "typst-json-printer --config projekt.yaml") <raw:s3-code>

The file  `kapitel1.properties` , containing all the extracted text segments, is now located in the  `i18n/source/`  folder. <p:s3-2>

== Step 4: Translate using the CAT tool <h2:schritt-4>

#dropcap-par[Load the file  `kapitel1.properties`  into your translation program (e.g., OmegaT) and, after translating, create the target files in  `i18n/target_en/`  or  `i18n/target_ru/` .] <p:s4-1>

== Step 5: Reconstruct the target languages and build the PDF <h2:schritt-5>

#dropcap-par[Finally, run the import command and compile the generated TypeS files:] <p:s5-1>

#raw(block: true, "typst-json-printer --config projekt.yaml --import\ntypst compile out_en/kapitel1.typ\ntypst compile out_ru/kapitel1.typ") <raw:s5-code>

The target folders now contain the finished Typst files and PDFs in all configured languages. <p:s5-2>

= Structure the text for translation <h1:best-practices>

#dropcap-par[To ensure that the round trip between Typst and the CAT tool works reliably even for larger book projects, a few basic rules for writing source files have proven effective.] <p:bp-1>

== Use Unambiguous Labels <h2:labels>

#dropcap-par[Every heading, paragraph, and translatable element should be enclosed in angle brackets with a unique label, such as  `<p:einleitung-1>`  or  `<box:merksatz-2>` .] <p:labels-1>

If no explicit label is provided, the transpiler automatically assigns sequential numbers. If an author later inserts a new paragraph in the middle of a chapter, all subsequent numbers shift, which can lead to incorrect mappings in the CAT tool. <p:labels-2>

With fixed labels, each text segment remains permanently linked to its identifier, regardless of where paragraphs are added or moved within the document. <p:labels-3>

== Apply Information Hiding <h2:information-hiding>

#dropcap-par[Complex layout instructions such as  `#set par(...)` ,  `#show ...` , or nested  `#block(...)`  containers do not belong directly in the body text. Consistently move such formatting code into named functions in your template file in the  `lib/`  folder.] <p:ih-1>

In the actual chapter text, you then only call concise, single-line macros. This allows the translator to see only the content itself in the CAT tool, without any distracting layout code. <p:ih-2>

== Create Your Own Type Functions <h2:eigene-funktionen>

#dropcap-par[Custom layout components such as infoboxes, quote boxes, or summary blocks are automatically recognized by the transpiler. If you enter the main text in square brackets, the tool will export it directly as a translatable segment.] <p:fn-1>

In addition, the transpiler recognizes all named arguments whose values are enclosed in double quotes. A call such as  `#fazit(title: "Zusammenfassung:")[Der eigentliche Inhalt.] <box:fazit-1>`  automatically generates two separate entries in the  `.properties`  file: one for the title and one for the content. <p:fn-2>

== Layout toggle using  `#show`  instead of container brackets <h2:show-vs-container>

#dropcap-par[If specific page margins or paragraph rules are to apply to a section of a document (such as the title page or the main body), these layout features must not be applied as large containers enclosed in square brackets around entire chapters.] <p:show-1>

The Transpiler treats the content within square brackets as a single, contiguous text segment and does not further parse any nested headings or other macros within it. <p:show-2>

Instead, use the Typst command  `#show:`  to apply a layout to the text that follows without nesting the document tree: <p:show-3>

#raw(block: true, "#show: layout-title-page\n\n#title-main[Mein Buchtitel] <title:main>\n\n#pagebreak()\n\n#show: layout-body-text") <raw:show-example>

This ensures that all headings, paragraphs, and function calls at the top level are preserved and passed to the CAT tool as separate segments. <p:show-4>

= Configuration Reference <h1:konfiguration>

#dropcap-par[The entire behavior of the export and import pipeline is controlled via a central YAML file. The  `--config`  parameter allows you to specify a separate configuration file for each book project.] <p:cfg-1>

#summary-box(title: "Mnemonic:")[Stable labels and external macros ensure that translators work exclusively on the actual content in the CAT tool, while the book layout remains centrally controlled.] <box:bp-summary>

== Project Area <h2:cfg-project>

#dropcap-par[The  `project`  section specifies the shared root directories for the project:] <p:cfg-proj-1>

-  *`source_dir`*  : Path to the directory containing the Typst source files in the original language. <p:cfg-proj-list-1>

-  *`i18n_source_dir`* : Destination folder where the generated  `.properties`  files are written for the CAT tool. <p:cfg-proj-list-2>

== “Targets” section <h2:cfg-targets>

#dropcap-par[Under  `targets` , you can define any number of target languages. When run with  `--import` , the tool processes all listed languages in a single pass:] <p:cfg-tgt-1>

-  *`lang`*  : Abbreviation for the target language used for console logging (for example,  `en`  or  `ru` ). <p:cfg-tgt-list-1>

-  *`i18n_target_dir`* : Directory where the CAT tool stores the translated  `.properties`  files for this language. <p:cfg-tgt-list-2>

-  *`output_dir`*  : Destination directory for the fully reconstructed Typst files for the respective language. <p:cfg-tgt-list-3>

== Section hide_functions <h2:cfg-hide>

#dropcap-par[Functions that control only the layout and do not contain any translatable text (such as  `pagebreak` ,  `outline` ,  `v` , or  `h` ) are listed under  `hide_functions` . These calls are skipped during export and are carried over unchanged into the destination document during import.] <p:cfg-hide-1>

== “ignore_named_args” section <h2:cfg-ignore-args>

#dropcap-par[Some Typst functions expect technical parameters as text strings, such as  `font: "Libertinus Serif"`  or  `align: "left"` . To prevent such tax values from being accidentally offered for translation in the CAT tool, their argument names can be excluded using  `ignore_named_args` .] <p:cfg-ign-1>

= A Practical Example from Book Production <h1:praxisbeispiel>

#dropcap-par[This manual itself serves as a complete reference project for the workflow described. The German source text is located in the  `docs/src_de/`  directory, while the layout components are maintained centrally in  `docs/lib/` .] <p:praxis-1>

The English and Russian versions are generated from this single source via the configuration file  `docs/docs.yaml` . Both target versions incorporate the same macros and thus produce an identical print output without the need for manual post-processing. <p:praxis-2>

== Live Demonstration of Layout Components <h2:live-demo>

#dropcap-par[The following overview illustrates the interaction between two-column lines and dialog macros in multilingual typesetting:] <p:demo-1>

#two-column-row(label: [*Autor*])[Write the German source text once using fixed labels.] <row:demo-1>

#two-column-row(label: [*Tool*])[Extracts all segments losslessly into standardized  `.properties`  files.] <row:demo-2>

#v(5mm)

#speaker(big-indent: true)[Author:] <spk:author>

#dropcap-par[I just added a new paragraph in the third chapter. Do I have to reorder all the translations now?] <p:dlg-1>

#speaker(big-indent: true)[Translator:] <spk:translator>

#dropcap-par[No, thanks to the fixed labels, all existing sentences are retained in the translation memory.] <p:dlg-2>

#small-note[Note: All blocks shown are taken directly from the template library located at  `docs/lib/` .] <note:demo>

#align-right[As of November 2026 — Open-Source Reference] <right:date>

= Troubleshooting and Tips for Everyday Bookwork <h1:troubleshooting>

#dropcap-par[In your day-to-day work with growing book manuscripts, the following tips will help you quickly resolve common challenges:] <p:ts-1>

-  *Subsequent corrections in the original* : If a sentence in the German source text changes, simply export it again. In the CAT tool, all unmodified sentences are retained as exact matches thanks to the translation memory, so that only the modified sentence needs to be translated anew. <p:ts-list-1>

-  *Missing translation in the target document* : The placeholder  `DE_TRANSLATION_MISSING`  appears in the reconstructed Typst document; either the corresponding entry in the CAT tool has not yet been translated, or the target file has not yet been rewritten after translation. <p:ts-list-2>

-  *Special Characters and Formatting* : Inline formatting such as  `*bold*` ,  `_italic_` , or cross-references ( `#link(...)` ) are recognized by the parser and passed to the CAT tool as protected tags. When translating, be sure to keep these tags in the appropriate places in the target sentence. <p:ts-list-3>

== Setting Up Protected Tags in OmegaT <h2:omegat-tags>

#dropcap-par[To ensure that inline formatting and code snippets enclosed in backticks, such as  `.typ` , as well as internal Typst references, are not accidentally altered during translation, they should be protected as custom tags in OmegaT.] <p:ot-tags-1>

To do this, open the following menu in OmegaT:  *Options*  ->  *Settings*  ->  *Tag Processing* , and enter the following regular expression in the  *Regular Expression for User-Defined Tags*  field: <p:ot-tags-2>

#layout-regex-box()

When pasting, make sure there are no accidental spaces at the beginning or end of the line, as these will otherwise be interpreted as an empty tag. Then refresh the project by pressing the  `F5`  key to make the new tags visible immediately. <p:ot-tags-3>

Also select the checkbox “Translated tags may be arranged differently.” <p:ot-tags-4>