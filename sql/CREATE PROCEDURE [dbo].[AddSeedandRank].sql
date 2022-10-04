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