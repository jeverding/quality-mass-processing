# quality-mass-processing
Dynamic SQL script to pull and process German hospital quality reports from XML files. 

For instance, the single queries pull the number of ops codes, vavu info, and hospital admissions. 

The main file is the sql query [hqr_full2014.sql](./hqr_full2014.sql), which shows how to scrape comprehensive information from the 2014 hospital quality reports, including hospital characteristics at the ward level as well as geographic information from separte 
XML files. 

The queries are mainly from late 2016 and used to process data for my [master thesis](https://github.com/jeverding/GoogleSite/blob/master/research-papers/Everding_Masterthesis_2016.pdf) on the effects of a policy reform in the German hospital market.
