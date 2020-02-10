---------------------------------------------------------------------------------------------------------------------------
--
-- Title: German hospital quality reports, year 2014 
-- Author: Jakob Everding 
-- Date: 17.09.2016 
-- 
-- This query scrapes various information on hospitals from the 2014 quality reports (available from the Gemeinsamer 
-- Bundesausschuss, GBA). The characteristics written to tables include ownership, type of wards, number of inpatient 
-- admissions, day care, regional mandatory psychiatric care, number of physicians, and  teaching status. 
-- Then geographical information is added to another table (federal state). 
-- For every single hospital, there exists at least one xml file per year (specifically, one for each hospital site). 
-- Both tables (main hospital and state information) are filled using a dynamic loop structure to fetch every single 
-- existing xml file and process them sequentially. That is, the query writes data from one hospital site at a time to 
-- temporary tables and, when finished with processing a file, inserts this information into the respective main table 
-- (temp. tables used in order not to overwrite data in main table when iterating through single xml files). 
-- Data is restricted to psychiatric/psychosomatic wards. The tables are joined eventually on the institution id 
-- (not ward, but hospital level here; necessary given that state info is provided in different file). 
-- 
-- For information on and access to the German hospital quality reports, please see the GBA: 
-- https://www.g-ba.de/themen/qualitaetssicherung/datenerhebung-zur-qualitaetssicherung/datenerhebung-qualitaetsbericht/ 
-- https://www.g-ba-qualitaetsberichte.de/#/search 
--
---------------------------------------------------------------------------------------------------------------------------

USE [QualiBerichte];

--
--Part 1: Hospital information, at ward level
--

IF OBJECT_ID('tempdb..#tempList') IS NOT NULL
DROP TABLE #tempList
 
CREATE TABLE #tempList ([FileName] VARCHAR(500))
 
--Simple dos dir command with /B switch (bare format)
INSERT INTO #tempList
EXEC MASTER..XP_CMDSHELL 'DIR C:\Test_loop_code /B'
 
--Delete null values
DELETE #tempList WHERE [FileName] IS NULL
 
--Keep only files of type .xml 
DELETE #tempList WHERE [FileName] NOT LIKE '%-xml.xml'
 
--Prepare code to loop over table
ALTER TABLE #tempList ADD id int identity
GO

SELECT * FROM #tempList

--Make table and define cols. (e.g. hospital ward id, number of inpatient cases at ward/hospital level, year)
--drop table KH_MainData
--create table KH_MainData (
--Traegerschaft varchar(100),
--Institutionskennzeichen int, 
--Fachabteilungsschluessel int,
--Fallzahl_Vollstat_KH int,
--Fallzahl_Teilstat_KH int,
--Fallzahl_Ambul_KH int,
--Bettenzahl_KH int,
--LehrKH varchar(100),
--PsyVersorgPfl varchar(10),
--Vollstat_Faelle_Abt int,
--Teilstat_Faelle_Abt int, 
--Aerzte_Abt_ohne_Belegaerzte nvarchar(50), 
--Fachaerzte_Abt_ohne_Belegaerzte nvarchar(50),
--Berichtsjahr int
--) ON [PRIMARY] 
--GO

--CREATE TABLE [dbo].[XMLImport](
--    [filename] [VARCHAR](500) NULL,
--    [timecreated] [DATETIME] NULL,
--    [xmldata] [xml] NULL
--) ON [PRIMARY]
--GO

truncate table KH_MainData
truncate table XMLImport --to rerun just this codeblock
declare @Directory varchar(200)
select @Directory = 'C:\Test_loop_code\'
 
DECLARE @FileExist int
DECLARE @FileName varchar(500),@DeleteCommand varchar(1000),@FullFileName varchar(500)
 
DECLARE @SQL NVARCHAR(1000),@xml xml
 
--Use this to mark how long the loop lasts
DECLARE @LoopID int, @MaxID int
SELECT @LoopID = min(id),@MaxID = max(ID)
FROM #tempList
 
 
 
WHILE @LoopID <= @MaxID
BEGIN
 
    SELECT @FileName = filename
    FROM #tempList
    WHERE id = @LoopID
 
    SELECT @FullFileName = @Directory + @FileName 
    
    exec xp_fileexist @FullFileName , @FileExist output
    IF @FileExist = 1 --sanity check if file actually exists
    BEGIN
    SELECT @SQL = N'select @xml = xml 
        FROM OPENROWSET(BULK ''' + @FullFileName +''' ,Single_BLOB) as TEMP(xml)'
     
    --Use output functionality to fill xml variable for later use
    EXEC SP_EXECUTESQL @SQL, N'@xml xml OUTPUT', @xml OUTPUT
     
    --Insert happens here, using the output value (@xml)
    INSERT XMLImport ([filename],timecreated,xmldata)
    SELECT @FileName,getdate(),@xml
    
    SET @DeleteCommand = 'del ' +  @Directory + @FileName 
    --To delete/move imported files to another directory: Uncommenting line below deletes file
    --EXEC MASTER..XP_CMDSHELL @DeleteCommand
    END
 
    --Get next id, instead of simple +1 directly get next available value (robust against skipped id values)
    SELECT @LoopID = min(id)
    FROM #tempList
    WHERE id > @LoopID

	
DECLARE @hdoc int

EXEC sp_xml_preparedocument @hdoc OUTPUT, @xml

SELECT *
INTO dummytemp1
FROM OPENXML (@hdoc, '/Qualitaetsbericht/Organisationseinheiten_Fachabteilungen/Organisationseinheit_Fachabteilung/Fachabteilungsschluessel', 2)
WITH (
Traegerschaft varchar(100) '../../../Krankenhaustraeger/Krankenhaustraeger_Art', 
Institutionskennzeichen int '../../../Krankenhaus/Kontaktdaten/IK', 
Fachabteilungsschluessel int 'FA_Schluessel',
Fallzahl_Vollstat_KH int '../../../Fallzahlen/Vollstationaere_Fallzahl',
Fallzahl_Teilstat_KH int '../../../Fallzahlen/Teilstationaere_Fallzahl',
Fallzahl_Ambul_KH int '../../../Fallzahlen/Ambulante_Fallzahl',
Bettenzahl_KH int '../../../Anzahl_Betten',
LehrKH varchar(100) '../../../Akademisches_Lehrkrankenhaus',
PsyVersorgPfl varchar(10) '../../../Pschiatrisches_Krankenhaus/Versorgungsverpflichtung_Psychiatrie',
--Psychiatrische Pflichtversorgung funktioniert nicht als Variable
Vollstat_Faelle_Abt int '../Fallzahlen_OE/Vollstationaere_Fallzahl',
Teilstat_Faelle_Abt int '../Fallzahlen_OE/Teilstationaere_Fallzahl', 
Aerzte_Abt_ohne_Belegaerzte nvarchar(50) '../Personelle_Ausstattung/Aerztliches_Personal/Hauptabteilung/Aerzte_ohne_Belegaerzte/Anzahl', 
Fachaerzte_Abt_ohne_Belegaerzte nvarchar(50) '../Personelle_Ausstattung/Aerztliches_Personal/Hauptabteilung/Aerzte_ohne_Belegaerzte/Fachaerzte/Anzahl')

EXEC sp_xml_removedocument @hdoc

--Add current year (i.e. 2014, in this case) to table 
ALTER TABLE dummytemp1 ADD Berichtsjahr int;
UPDATE dummytemp1 SET Berichtsjahr = 2014;

--Keep only psychiatric and psychosomatic wards (for information on codes, see e.g. https://www.gkv-datenaustausch.de/media/dokumente/leistungserbringer_1/krankenhaeuser/archiv/technische_anlage_2/20120101_20120229_Anlage_2.pdf)
DELETE FROM dummytemp1
WHERE Fachabteilungsschluessel!=2900 AND Fachabteilungsschluessel!=3000 AND Fachabteilungsschluessel!=3100 AND Fachabteilungsschluessel!=2928 AND Fachabteilungsschluessel!=2930 AND Fachabteilungsschluessel!=2931 AND Fachabteilungsschluessel!=2950 AND Fachabteilungsschluessel!=2951 AND Fachabteilungsschluessel!=2952 AND Fachabteilungsschluessel!=2953 AND Fachabteilungsschluessel!=2954 AND Fachabteilungsschluessel!=2955 AND Fachabteilungsschluessel!=2956 AND Fachabteilungsschluessel!=2960 AND Fachabteilungsschluessel!=2961 AND Fachabteilungsschluessel!=3060 AND Fachabteilungsschluessel!=3061 AND Fachabteilungsschluessel!=3160 AND Fachabteilungsschluessel!=3161; 
DELETE FROM dummytemp1 
WHERE Fachabteilungsschluessel IS NULL; 

INSERT INTO KH_MainData (Traegerschaft, Institutionskennzeichen, Fachabteilungsschluessel, Fallzahl_Vollstat_KH, Fallzahl_Teilstat_KH, Fallzahl_Ambul_KH, Bettenzahl_KH, LehrKH , PsyVersorgPfl, Vollstat_Faelle_Abt, Teilstat_Faelle_Abt, Aerzte_Abt_ohne_Belegaerzte, Fachaerzte_Abt_ohne_Belegaerzte, Berichtsjahr)
SELECT Traegerschaft, Institutionskennzeichen, Fachabteilungsschluessel, Fallzahl_Vollstat_KH, Fallzahl_Teilstat_KH, Fallzahl_Ambul_KH, Bettenzahl_KH, LehrKH , PsyVersorgPfl, Vollstat_Faelle_Abt, Teilstat_Faelle_Abt, Aerzte_Abt_ohne_Belegaerzte, Fachaerzte_Abt_ohne_Belegaerzte, Berichtsjahr FROM dummytemp1;
DROP TABLE dummytemp1
END --End: Loop

--
--Part 2: Get information on federal state (similar structure as above)
-- 

--DROP TABLE XMLImport
IF OBJECT_ID('tempdb..#tempList') IS NOT NULL
DROP TABLE #tempList
 
CREATE TABLE #tempList ([FileName] VARCHAR(500))
 
--Simple dos dir command with /B switch (bare format)
INSERT INTO #tempList
EXEC MASTER..XP_CMDSHELL 'DIR C:\Test_loop_code /B'
 
--Delete null values
DELETE #tempList WHERE [FileName] IS NULL
 
--Keep only files containing federal state information and of type .xml 
DELETE #tempList WHERE [FileName] NOT LIKE '%-land.xml'
 
--Prepare code to loop over table
ALTER TABLE #tempList ADD id int identity
GO

SELECT * FROM #tempList

--Make table and define cols. (now only hospital id, federal state)
--drop table KH_Land
--create table KH_Land (
--Bundesland varchar(100),
--Institutionskennzeichen2 int
--) ON [PRIMARY] 
--GO

--CREATE TABLE [dbo].[XMLImport](
--    [filename] [VARCHAR](500) NULL,
--    [timecreated] [DATETIME] NULL,
--    [xmldata] [xml] NULL
--) ON [PRIMARY]
--GO

truncate table KH_Land
truncate table XMLImport --to rerun just this codeblock
declare @Directory varchar(200)
select @Directory = 'C:\Test_loop_Code\'
 
DECLARE @FileExist int
DECLARE @FileName varchar(500),@DeleteCommand varchar(1000),@FullFileName varchar(500)
 
DECLARE @SQL NVARCHAR(1000),@xml xml
 
--Use this to mark how long the loop lasts
DECLARE @LoopID int, @MaxID int
SELECT @LoopID = min(id),@MaxID = max(ID)
FROM #tempList
 
 
WHILE @LoopID <= @MaxID
BEGIN
 
    SELECT @FileName = filename
    FROM #tempList
    WHERE id = @LoopID
 
    SELECT @FullFileName = @Directory + @FileName 
    
    exec xp_fileexist @FullFileName , @FileExist output
    if @FileExist =1 --sanity check if file actually exists
    begin
    SELECT @SQL = N'select @xml = xml 
        FROM OPENROWSET(BULK ''' + @FullFileName +''' ,Single_BLOB) as TEMP(xml)'
     
    --Use output functionality to fill xml variable for later use
    EXEC SP_EXECUTESQL @SQL, N'@xml xml OUTPUT', @xml OUTPUT
     
    --Insert happens here, using the output value (@xml)
    INSERT XMLImport ([filename],timecreated,xmldata)
    SELECT @FileName,getdate(),@xml
    
    SET @DeleteCommand = 'del ' +  @Directory + @FileName 
    --To delete/move imported files to another directory: Uncommenting line below deletes file
    --EXEC MASTER..XP_CMDSHELL @DeleteCommand
    end
 
    --Get next id, instead of simple +1 directly get next available value (robust against skipped id values)
    SELECT @LoopID = min(id)
    FROM #tempList
    where id > @LoopID

	
DECLARE @hdoc int

EXEC sp_xml_preparedocument @hdoc OUTPUT, @xml

SELECT *
INTO dummytemp2
FROM OPENXML (@hdoc, '/Externe_Qualitaetssicherung/Land', 2)
WITH (
Bundesland varchar(100) '../Land', 
Institutionskennzeichen2 int '../IK_Krankenhaus')

EXEC sp_xml_removedocument @hdoc

INSERT INTO KH_Land (Bundesland, Institutionskennzeichen2)
SELECT Bundesland, Institutionskennzeichen2 FROM dummytemp2;

DROP TABLE dummytemp2

END --End: Loop


--
--Part 3: Join the two main tables (from part 1 and 2)
--

SELECT * 
INTO KH_Comp
FROM KH_MainData LEFT JOIN KH_Land ON KH_MainData.Institutionskennzeichen=KH_Land.Institutionskennzeichen2

TRUNCATE TABLE KH_2014
--DROP TABLE KH_2014
--CREATE TABLE KH_2014 (
--Traegerschaft varchar(100),
--Institutionskennzeichen int, 
--Fachabteilungsschluessel int,
--Fallzahl_Vollstat_KH int,
--Fallzahl_Teilstat_KH int,
--Fallzahl_Ambul_KH int,
--Bettenzahl_KH int,
--LehrKH varchar(100),
----PsyVersorgPfl varchar(10),
--Vollstat_Faelle_Abt int,
--Teilstat_Faelle_Abt int, 
--Aerzte_Abt_ohne_Belegaerzte nvarchar(50), 
--Fachaerzte_Abt_ohne_Belegaerzte nvarchar(50),
--Berichtsjahr int,
--Bundesland varchar(100)
--) ON [PRIMARY] 
--GO

INSERT INTO KH_2014 (Traegerschaft, Institutionskennzeichen, Fachabteilungsschluessel, Fallzahl_Vollstat_KH, Fallzahl_Teilstat_KH, Fallzahl_Ambul_KH, Bettenzahl_KH, LehrKH, Vollstat_Faelle_Abt, Teilstat_Faelle_Abt, Aerzte_Abt_ohne_Belegaerzte, Fachaerzte_Abt_ohne_Belegaerzte, Berichtsjahr,Bundesland)
SELECT Traegerschaft, Institutionskennzeichen, Fachabteilungsschluessel, Fallzahl_Vollstat_KH, Fallzahl_Teilstat_KH, Fallzahl_Ambul_KH, Bettenzahl_KH, LehrKH, Vollstat_Faelle_Abt, Teilstat_Faelle_Abt, Aerzte_Abt_ohne_Belegaerzte, Fachaerzte_Abt_ohne_Belegaerzte, Berichtsjahr,Bundesland FROM KH_Comp; 

DROP TABLE KH_Comp
SELECT * FROM KH_2014

TRUNCATE TABLE KH_2014Distinct
--DROP TABLE KH_2014Distinct
--CREATE TABLE KH_2014Distinct (
--Traegerschaft varchar(100),
--Institutionskennzeichen int, 
--Fachabteilungsschluessel int,
--Fallzahl_Vollstat_KH int,
--Fallzahl_Teilstat_KH int,
--Fallzahl_Ambul_KH int,
--Bettenzahl_KH int,
--LehrKH varchar(100),
----PsyVersorgPfl varchar(10),
--Vollstat_Faelle_Abt int,
--Teilstat_Faelle_Abt int, 
--Aerzte_Abt_ohne_Belegaerzte nvarchar(50), 
--Fachaerzte_Abt_ohne_Belegaerzte nvarchar(50),
--Berichtsjahr int,
--Bundesland varchar(100)
--) ON [PRIMARY] 
--GO

INSERT INTO KH_2014Distinct (Traegerschaft, Institutionskennzeichen, Fachabteilungsschluessel, Fallzahl_Vollstat_KH, Fallzahl_Teilstat_KH, Fallzahl_Ambul_KH, Bettenzahl_KH, LehrKH, Vollstat_Faelle_Abt, Teilstat_Faelle_Abt, Aerzte_Abt_ohne_Belegaerzte, Fachaerzte_Abt_ohne_Belegaerzte, Berichtsjahr,Bundesland)
SELECT DISTINCT * FROM KH_2014

SELECT * FROM KH_2014Distinct
