USE tempdb;

--wird hier eigentlich nicht weiter benötigt
--aber evtl. hilfreich zum Überprüfen der Ordnerstruktur 
IF OBJECT_ID('tempdb..#subfolders') IS NOT NULL DROP TABLE #subfolders
CREATE TABLE #subfolders (
	[SubFolderName] VARCHAR(500),
	depth int, 
	isfile bit
)
		insert #subfolders
		exec master..xp_dirtree  'D:\Dropbox\Data\16_GBA\',2,1;
		--delete null values
		DELETE #subfolders WHERE [SubFolderName] IS NULL
		-- Delete all folders
		DELETE #subfolders WHERE isfile = 1
		--used to loop over the table (outer loop)
		--not used
		alter table #subfolders add id_sub int identity
		go
		select * from #subfolders

IF OBJECT_ID('tempdb..#tempList') IS NOT NULL DROP TABLE #tempList
CREATE TABLE #tempList (
	[FileName] VARCHAR(500),
	depth int, 
	isfile bit
) 
		insert #tempList
		exec master..xp_dirtree  'D:\Dropbox\Data\16_GBA\',2,1;
		--delete null values
		DELETE #tempList WHERE [FileName] IS NULL
		-- Delete all folders (= non-files)
		DELETE #tempList WHERE isfile = 0
		-- Delete all files that don't have xml extension
		DELETE #tempList WHERE [FileName] NOT LIKE '%-xml.xml'
		-- Delete all files that are sums of other files (EntOrt=99)
		DELETE #tempList WHERE [FileName] LIKE '%-99-%'
		--used to loop over the table (inner loop)
		alter table #tempList add id int identity
		go
		select * from #tempList

--Tabelle mit Spalten für die relevanten Daten anlegen 
IF OBJECT_ID('tempdb..table1') IS NOT NULL DROP TABLE table1
create table table1 (
	AbtSchlüssel int,
	AbtNummer int, 
	Fallzahl_Vollstat_KH int,
	Vollstat_Faelle_Abt int,
	Berichtsjahr int, 
	ik int,
	EntOrt int
) ON [PRIMARY] 
GO

IF OBJECT_ID('tempdb.dbo.XMLImport') IS NOT NULL DROP TABLE dbo.XMLImport
CREATE TABLE [dbo].[XMLImport](
	[filename] [VARCHAR](500) NULL,
	[timecreated] [DATETIME] NULL,
	[xmldata] [xml] NULL
) ON [PRIMARY]
GO

		declare @Directory varchar(200)
		select @Directory = 'D:\Dropbox\Data\16_GBA\'
		declare @FileExist int
		DECLARE @FileName varchar(500),@DeleteCommand varchar(1000),@FullFileName varchar(500)
		DECLARE @SQL NVARCHAR(1000),@xml xml
 
		--This is so that we know how long the INNER loop lasts
		declare @LoopID int, @MaxID int
		SELECT @LoopID = min(id),@MaxID = max(ID)
		FROM #tempList

		WHILE @LoopID <= @MaxID
		BEGIN
 
			SELECT @FileName = [filename]
			from #tempList
			where id = @LoopID

			truncate table XMLImport 
			SELECT @FullFileName = @Directory + substring(@FileName,14,4) + '\' + @FileName 
			exec xp_fileexist @FullFileName , @FileExist output
			if @FileExist =1 
			begin
				SELECT @SQL = N'select @xml = xml 
					FROM OPENROWSET(BULK ''' + @FullFileName +''' ,Single_BLOB) as TEMP(xml)'
				EXEC SP_EXECUTESQL @SQL, N'@xml xml OUTPUT', @xml OUTPUT
				INSERT XMLImport ([filename],timecreated,xmldata)
				SELECT @FileName,getdate(),@xml
				SET @DeleteCommand = 'del ' +  @Directory + @FileName 
				end
 
			--Get the next (existing) id
			SELECT @LoopID = min(id)
			FROM #tempList
			where id > @LoopID

			DECLARE @hdoc int
			EXEC sp_xml_preparedocument @hdoc OUTPUT, @xml
				if substring(@FileName,14,4) <= 2008 begin 
					SELECT *
					INTO dummy0
					FROM OPENXML (@hdoc, '/Qualitaetsbericht/Organisationseinheiten_Fachabteilungen/Organisationseinheit_Fachabteilung/Fachabteilungsschluessel', 2)
					WITH (
						AbtSchlüssel int 'FA_Schluessel',
						AbtNummer int '../Gliederungsnummer', 
						Fallzahl_Vollstat_KH int '../../../Fallzahlen/Vollstationaere_Fallzahl',
						Vollstat_Faelle_Abt int '../Stationaere_Fallzahl'
					) 
				end 
				else if substring(@FileName,14,4) = 2010 begin 
					SELECT *
					INTO dummy0
					FROM OPENXML (@hdoc, '/Qualitaetsbericht/Organisationseinheiten_Fachabteilungen/Organisationseinheit_Fachabteilung/Fachabteilungsschluessel', 2)
					WITH (
						AbtSchlüssel int 'FA_Schluessel',
						AbtNummer int '../Gliederungsnummer', 
						Fallzahl_Vollstat_KH int '../../../Fallzahlen/Vollstationaere_Fallzahl',
						Vollstat_Faelle_Abt int '../Vollstationaere_Fallzahl'
					) 
				end 
				else
					SELECT *
					INTO dummy0
					FROM OPENXML (@hdoc, '/Qualitaetsbericht/Organisationseinheiten_Fachabteilungen/Organisationseinheit_Fachabteilung/Fachabteilungsschluessel', 2)
					WITH (
						AbtSchlüssel int 'FA_Schluessel',
						AbtNummer int '../Gliederungsnummer', 
						Fallzahl_Vollstat_KH int '../../../Fallzahlen/Vollstationaere_Fallzahl',
						Vollstat_Faelle_Abt int '../Fallzahlen_OE/Vollstationaere_Fallzahl'
					) 
			EXEC sp_xml_removedocument @hdoc

			ALTER TABLE dummy0 ADD Berichtsjahr int;
			UPDATE dummy0 SET Berichtsjahr = substring(@FileName,14,4);
			ALTER TABLE dummy0 ADD ik int;
			UPDATE dummy0 SET ik = substring(@FileName,1,9)
			ALTER TABLE dummy0 ADD EntOrt int;
			UPDATE dummy0 SET EntOrt = substring(@FileName,11,2)
			
			INSERT INTO table1 (AbtSchlüssel, AbtNummer, Fallzahl_Vollstat_KH, Vollstat_Faelle_Abt, Berichtsjahr, ik, EntOrt)
			SELECT AbtSchlüssel, AbtNummer, Fallzahl_Vollstat_KH, Vollstat_Faelle_Abt, Berichtsjahr, ik, EntOrt FROM dummy0;
			DROP TABLE dummy0
		END
		--ende inner loop 

--select distinct * from table1
--order by Berichtsjahr, ik, EntOrt, AbtSchlüssel
select distinct * from table1
order by Berichtsjahr, ik, EntOrt, AbtNummer