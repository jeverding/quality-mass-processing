# quality-mass-processing
Dynamic SQL script to pull and process **German hospital quality reports** from XML files. 

For instance, the single queries pull the number of ops codes, vavu info, and hospital admissions. 

The **main file** is the sql query [`hqr_full2014.sql`](./hqr_full2014.sql), which shows how to scrape comprehensive information from the 2014 hospital quality reports, including hospital characteristics at the ward level as well as geographic information from separte 
XML files. 

The queries are mainly from late 2016 and used to process data for my [master thesis](https://github.com/jeverding/GoogleSite/blob/master/research-papers/Everding_Masterthesis_2016.pdf) on the effects of a policy reform in the German hospital market.

## Information and access to the German hospital quality reports 
The annual reports comprise information from each German hospital and are available from the Gemeinsamer Bundesausschuss (GBA). 
See general information on the reports here: https://www.g-ba.de/themen/qualitaetssicherung/datenerhebung-zur-qualitaetssicherung/datenerhebung-qualitaetsbericht/ 

To browse reports (i.e. aggregated data) in pdf format online, see: https://www.g-ba-qualitaetsberichte.de/#/search 

Full information is provided in XML files. See here how to apply for the data: https://www.g-ba.de/downloads/17-98-2740/2015-01-22_Auftragsformular-ANB_Qb-R.pdf

The data can be accessed free of charge. 
For details on the terms of use, see: https://www.g-ba.de/downloads/17-98-2742/2015-01-22_Allgemeine-Nutzungsbedingungen.pdf 
