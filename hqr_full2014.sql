USE [Masterarbeit 1];
			-- PART 1 Des Beispiels 
--DROP TABLE XMLImport

IF OBJECT_ID('tempdb..#tempList') IS NOT NULL
DROP TABLE #tempList
 
CREATE TABLE #tempList ([FileName] VARCHAR(500))
 
--plain vanilla dos dir command with /B switch (bare format)
INSERT INTO #tempList
EXEC MASTER..XP_CMDSHELL 'DIR C:\Test_loop_code /B'
 
 
--delete the null values
DELETE #tempList WHERE [FileName] IS NULL
 
-- Delete all the files that don't have xml extension
DELETE #tempList WHERE [FileName] NOT LIKE '%-xml.xml'
 
--this will be used to loop over the table
alter table #tempList add id int identity
go

select * from #tempList

			-- PART 2 Des Beispiels 

--Tabelle mit Spalten für die relevanten Daten anlegen 
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
----on primary evtl. weglassen, Funktion überprüfen! 
--GO

--CREATE TABLE [dbo].[XMLImport](
--    [filename] [VARCHAR](500) NULL,
--    [timecreated] [DATETIME] NULL,
--    [xmldata] [xml] NULL
--) ON [PRIMARY]
--GO

			 -- PART 3 Des Beispiels 
truncate table KH_MainData
truncate table XMLImport --in case you want to rerun just this codeblock
declare @Directory varchar(200)
select @Directory = 'C:\Test_loop_code\'
 
declare @FileExist int
DECLARE @FileName varchar(500),@DeleteCommand varchar(1000),@FullFileName varchar(500)
 
DECLARE @SQL NVARCHAR(1000),@xml xml
 
--This is so that we know how long the loop lasts
declare @LoopID int, @MaxID int
SELECT @LoopID = min(id),@MaxID = max(ID)
FROM #tempList
 
 
 
WHILE @LoopID <= @MaxID
BEGIN
 
    SELECT @FileName = filename
    from #tempList
    where id = @LoopID
 
    SELECT @FullFileName = @Directory + @FileName 
    
    exec xp_fileexist @FullFileName , @FileExist output
    if @FileExist =1 --sanity check in case some evil person removed the file
    begin
    SELECT @SQL = N'select @xml = xml 
        FROM OPENROWSET(BULK ''' + @FullFileName +''' ,Single_BLOB) as TEMP(xml)'
     
    -- Just like in the bedroom, this is where the magic happens
    -- We use the output functionality to fill the xml variable for later use
    EXEC SP_EXECUTESQL @SQL, N'@xml xml OUTPUT', @xml OUTPUT
     
    
    --The actual insert happens here, as you can see we use the output value (@xml)
    INSERT XMLImport ([filename],timecreated,xmldata)
    SELECT @FileName,getdate(),@xml
    
    SET @DeleteCommand = 'del ' +  @Directory + @FileName 
    --maybe you want to delete or move the file to another directory
    -- ** here is how to delete the files you just imported
    -- uncomment line below to delete the file just inserted
    --EXEC MASTER..XP_CMDSHELL @DeleteCommand
    -- ** end of here is how to delete the files
    end
 
    --Get the next id, instead of +1 we grab the next value in case of skipped id values
    SELECT @LoopID = min(id)
    FROM #tempList
    where id > @LoopID


	--Hier NEUER PART: In SQL geladene XMLs richtig öffnen bzw. filtern 
	--aber weiterhin in der Schleife, damit für jede aus dem Ordner geladene Datei auch eine 
	--Zeile in KH_test4 geschrieben wird 

	
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

ALTER TABLE dummytemp1 ADD Berichtsjahr int;
UPDATE dummytemp1 SET Berichtsjahr = 2014;
--fügt der Tabelle für aktuelle xml datei das Berichtsjahr zu, 
--das müsste mit diesem Code für die einzelnen Jahre noch händisch angepasst werden 

DELETE FROM dummytemp1
WHERE Fachabteilungsschluessel!=2900 AND Fachabteilungsschluessel!=3000 AND Fachabteilungsschluessel!=3100 AND Fachabteilungsschluessel!=2928 AND Fachabteilungsschluessel!=2930 AND Fachabteilungsschluessel!=2931 AND Fachabteilungsschluessel!=2950 AND Fachabteilungsschluessel!=2951 AND Fachabteilungsschluessel!=2952 AND Fachabteilungsschluessel!=2953 AND Fachabteilungsschluessel!=2954 AND Fachabteilungsschluessel!=2955 AND Fachabteilungsschluessel!=2956 AND Fachabteilungsschluessel!=2960 AND Fachabteilungsschluessel!=2961 AND Fachabteilungsschluessel!=3060 AND Fachabteilungsschluessel!=3061 AND Fachabteilungsschluessel!=3160 AND Fachabteilungsschluessel!=3161; 
-- Sind alles psychiatrische und psychosomatische FA
DELETE FROM dummytemp1 
WHERE Fachabteilungsschluessel IS NULL; 

INSERT INTO KH_MainData (Traegerschaft, Institutionskennzeichen, Fachabteilungsschluessel, Fallzahl_Vollstat_KH, Fallzahl_Teilstat_KH, Fallzahl_Ambul_KH, Bettenzahl_KH, LehrKH , PsyVersorgPfl, Vollstat_Faelle_Abt, Teilstat_Faelle_Abt, Aerzte_Abt_ohne_Belegaerzte, Fachaerzte_Abt_ohne_Belegaerzte, Berichtsjahr)
SELECT Traegerschaft, Institutionskennzeichen, Fachabteilungsschluessel, Fallzahl_Vollstat_KH, Fallzahl_Teilstat_KH, Fallzahl_Ambul_KH, Bettenzahl_KH, LehrKH , PsyVersorgPfl, Vollstat_Faelle_Abt, Teilstat_Faelle_Abt, Aerzte_Abt_ohne_Belegaerzte, Fachaerzte_Abt_ohne_Belegaerzte, Berichtsjahr FROM dummytemp1;

DROP TABLE dummytemp1

END

--			!!! Ab hier BUNDESLAND !!! 

--DROP TABLE XMLImport

IF OBJECT_ID('tempdb..#tempList') IS NOT NULL
DROP TABLE #tempList
 
CREATE TABLE #tempList ([FileName] VARCHAR(500))
 
--plain vanilla dos dir command with /B switch (bare format)
INSERT INTO #tempList
EXEC MASTER..XP_CMDSHELL 'DIR C:\Test_loop_code /B'
 
 
--delete the null values
DELETE #tempList WHERE [FileName] IS NULL
 
-- Delete all the files that don't have xml extension
DELETE #tempList WHERE [FileName] NOT LIKE '%-land.xml'
 
--this will be used to loop over the table
alter table #tempList add id int identity
go

select * from #tempList

			-- PART 2 Des Beispiels 

--Tabelle mit Spalten für die relevanten Daten anlegen 
--drop table KH_Land
--create table KH_Land (
--Bundesland varchar(100),
--Institutionskennzeichen2 int
--) ON [PRIMARY] 
----on primary evtl. weglassen, Funktion überprüfen! 
--GO

--CREATE TABLE [dbo].[XMLImport](
--    [filename] [VARCHAR](500) NULL,
--    [timecreated] [DATETIME] NULL,
--    [xmldata] [xml] NULL
--) ON [PRIMARY]
--GO

			 -- PART 3 Des Beispiels 
truncate table KH_Land
truncate table XMLImport --in case you want to rerun just this codeblock
declare @Directory varchar(200)
select @Directory = 'C:\Test_loop_Code\'
 
declare @FileExist int
DECLARE @FileName varchar(500),@DeleteCommand varchar(1000),@FullFileName varchar(500)
 
DECLARE @SQL NVARCHAR(1000),@xml xml
 
--This is so that we know how long the loop lasts
declare @LoopID int, @MaxID int
SELECT @LoopID = min(id),@MaxID = max(ID)
FROM #tempList
 
 
 
WHILE @LoopID <= @MaxID
BEGIN
 
    SELECT @FileName = filename
    from #tempList
    where id = @LoopID
 
    SELECT @FullFileName = @Directory + @FileName 
    
    exec xp_fileexist @FullFileName , @FileExist output
    if @FileExist =1 --sanity check in case some evil person removed the file
    begin
    SELECT @SQL = N'select @xml = xml 
        FROM OPENROWSET(BULK ''' + @FullFileName +''' ,Single_BLOB) as TEMP(xml)'
     
    -- Just like in the bedroom, this is where the magic happens
    -- We use the output functionality to fill the xml variable for later use
    EXEC SP_EXECUTESQL @SQL, N'@xml xml OUTPUT', @xml OUTPUT
     
    
    --The actual insert happens here, as you can see we use the output value (@xml)
    INSERT XMLImport ([filename],timecreated,xmldata)
    SELECT @FileName,getdate(),@xml
    
    SET @DeleteCommand = 'del ' +  @Directory + @FileName 
    --maybe you want to delete or move the file to another directory
    -- ** here is how to delete the files you just imported
    -- uncomment line below to delete the file just inserted
    --EXEC MASTER..XP_CMDSHELL @DeleteCommand
    -- ** end of here is how to delete the files
    end
 
    --Get the next id, instead of +1 we grab the next value in case of skipped id values
    SELECT @LoopID = min(id)
    FROM #tempList
    where id > @LoopID


	--Hier NEUER PART: In SQL geladene XMLs richtig öffnen bzw. filtern 
	--aber weiterhin in der Schleife, damit für jede aus dem Ordner geladene Datei auch eine 
	--Zeile in KH_test4 geschrieben wird 

	
DECLARE @hdoc int

EXEC sp_xml_preparedocument @hdoc OUTPUT, @xml

SELECT *
INTO dummytemp2
FROM OPENXML (@hdoc, '/Externe_Qualitaetssicherung/Land', 2)

WITH (

Bundesland varchar(100) '../Land', 
Institutionskennzeichen2 int '../IK_Krankenhaus')
--ModifiedDate datetime


EXEC sp_xml_removedocument @hdoc

INSERT INTO KH_Land (Bundesland, Institutionskennzeichen2)
SELECT Bundesland, Institutionskennzeichen2 FROM dummytemp2;

DROP TABLE dummytemp2

END


--			!!! Zusammenführen aller Daten in eine Tabelle !!! 

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
----on primary evtl. weglassen, Funktion überprüfen! 
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
----on primary evtl. weglassen, Funktion überprüfen! 
--GO

INSERT INTO KH_2014Distinct (Traegerschaft, Institutionskennzeichen, Fachabteilungsschluessel, Fallzahl_Vollstat_KH, Fallzahl_Teilstat_KH, Fallzahl_Ambul_KH, Bettenzahl_KH, LehrKH, Vollstat_Faelle_Abt, Teilstat_Faelle_Abt, Aerzte_Abt_ohne_Belegaerzte, Fachaerzte_Abt_ohne_Belegaerzte, Berichtsjahr,Bundesland)
SELECT DISTINCT * FROM KH_2014

SELECT * FROM KH_2014Distinct
