# Watercooler
This is a way to set up random groups of three people from an org group for discussions. Will pull users from the graph, create random pairings and then email them via ADF pipelines and connected Logic Apps. The solution needs the SQL bacpac to be deployed which will house the tables used, as well as the SQL Stored Procedures that are run to create the random user pairings of three. The requirement is to run the Logic app that will get the users under a certain manager in AAD, this JSON output is then saved to a blob location.


# The Logic App
## la-watercooler2








# SQL Stored Proc

The dbo.writeemployees.sql SP is used to take the JSON file that is in Blob and create a table of users using OPENJSON
```SQL
CREATE   PROCEDURE [dbo].[writeemployees]
(
        @json NVARCHAR(MAX)
)

AS
BEGIN

INSERT INTO [dbo].[WaterCoolerListFinnes]
(
    [GraphID],[DisplayName],[GivenName],[Surname],[JobTitle],[OfficeLocation],[UPN]
)
SELECT 
[GraphID]
,[DisplayName]
,[GivenName]
,[Surname]
,[JobTitle]
,[OfficeLocation]
,[UPN]
FROM OPENJSON(@json)
WITH (
    [GraphID] nvarchar(500) '$.id',
    [DisplayName] nvarchar(200) '$.displayName',
    [GivenName] nvarchar(200) '$.givenName',
    [Surname] nvarchar(200) '$.surname',
    [JobTitle] nvarchar(200) '$.jobTitle',
    [OfficeLocation] nvarchar(200) '$.officeLocation',
    [UPN] nvarchar(200) '$.userPrincipalName')
END
```
The dbo.AddSeedandRank.sql Stored Proc is used to create the pairings of employees in groups. By default the groups are in 3's but the parameter can be modified as needed.
```SQL
CREATE   PROCEDURE [dbo].[AddSeedandRank]
AS
BEGIN
--TRUNCATE TABLE  [dbo].[RankTable];

UPDATE  [dbo].[WaterCoolerList]
SET RandomSeedNumber = RAND(HASHBYTES('md5',CONCAT(RAND(),convert(varchar,[graphid]))))
WHERE [TableDate]= (SELECT MAX([TableDate]) FROM [dbo].[WaterCoolerList] wcl1 WHERE [graphid] = wcl1.[graphid]);

DECLARE @TotalNumberofGroups AS int
SET @TotalNumberofGroups =  (SELECT COUNT(*)/3 FROM [dbo].[WaterCoolerList] 
WHERE [TableDate]= (SELECT MAX([TableDate]) FROM [dbo].[WaterCoolerList] wcl1 WHERE [graphid] = wcl1.[graphid]))
INSERT INTO [dbo].[RankTable] (
[graphid]
,[displayName]
,[givenName]
,[surname]
,[jobTitle]
,[officeLocation]
,[UPN]
,[accountEnabled]
,[TableDate]    
,[Rank]
,[GroupAssigned]
,[AssignmentDate]
)
SELECT [graphid]
,[displayName]
,[givenName]
,[surname]
,[jobTitle]
,[officeLocation]
,[UPN]
,[accountEnabled]
,[TableDate]
,RANK() OVER (ORDER BY RandomSeedNumber) AS [Rank]
,NTILE(@TotalNumberofGroups) OVER(ORDER BY RandomSeedNumber) as [GroupAssigned]
--,CURRENT_TIMESTAMP as [AssignmentDate]
,GETDATE() as AssignmentDate
-- INTO [RankTable]
FROM [dbo].[WaterCoolerList]
WHERE [TableDate]= (SELECT MAX([TableDate]) FROM [dbo].[WaterCoolerList] wcl1 WHERE [graphid] = wcl1.[graphid]);
INSERT INTO [dbo].[WaterCoolerEmailGroupings] 
    (
    [GroupAssigned]
    ,[emailchain]
    ,[AssignmentDate]
    )
SELECT [GroupAssigned]
      ,STRING_AGG(UPN,';') as [emailchain]
      ,[AssignmentDate]
      FROM [dbo].[RankTable]
WHERE [TableDate] = (SELECT MAX([TableDate]) FROM [dbo].[RankTable] wcl1 WHERE [graphid] = wcl1.[graphid])
GROUP BY [GroupAssigned], [AssignmentDate];
END
```
