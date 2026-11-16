= An environment for creating and translating PDF documents <h1_id_1>

== Objective <h2_id_2>

- The PDF documents generated should be fully controllable and customizable down to the finest detail. <p_id_3>

- The environment should enable the efficient delivery of documents in multiple languages. <p_id_4>

\n- The focus is on text content; mathematical formulas are not supported. <p_id_5>

- A future expansion to enable the automated generation of alternative formats, such as HTML or Obisian Markdown, should be possible with a reasonable amount of effort. <p_id_6>

- Only open-source components should be used. <p_id_7>

== History and Architecture <h2_id_8>

\nAt first, I assumed that the EPUB 3 standard might be a good starting point, so I tried using all kinds of PDF generators to create a more complex format. I was only able to do this reasonably well using the Prince Generator, which, unfortunately, is not open source and can also be very time-consuming when the specifications are complex. I found the idea appealing—a single source of truth in the EPUB 3 format, from which the PDF files would be generated. \nA book would automatically be available both as a print publication and as an ePub. Since an ePub uses HTML internally, the integration of OmegaT as a translation environment was well supported. At some point, I had to conclude that this approach had failed, since the open-source PDF generators available to me did not support precise formatting of PDF files. <p_id_9>

So I focused my attention on identifying which environments actually exist that allow for the efficient and precise implementation of PDF formats. In the process, I came across Typst, which is mostly used in academic settings and, among other things, allows for the display of mathematical formulas. In any case, Typst does an excellent job of converting text to PDF—you don't have to use the full range of features. Another major advantage of Typst is its ability to standardize and unify formats. When translating an entire book series with similar or identical formats, you can use a single library of formatting functions, and all books in the series will be formatted identically in all languages, provided those languages are written from left to right and top to bottom. <p_id_10>

However, at first I was unable to use my OmegaT translation environment with Typst files; there were no filters with sufficient functionality. So I wrote a program that converts Typst files into a format that OmegaT can read. \nIn this process, each paragraph in Typst is assigned a label with an ID, and this ID then serves as the key to the texts in OmegaT. A separate program takes the translated texts and uses the original document and these texts to create a translated document that is formatted exactly like the original. <p_id_11>

\nThis makes the original Typst document my “single source of truth” and defines the structure and format for all translated documents. <p_id_12>

Since I'm quite familiar with the language features I use in Typst, I could optionally generate other formats instead of key-value pairs—for example, HTML or Obisian Markup. <p_id_13>