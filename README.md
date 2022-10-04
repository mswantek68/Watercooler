# Watercooler App
This is a way to set up random groups of three people from an org group for discussions. Will pull users from the graph, create random pairings and then email them via ADF pipelines and connected Logic Apps. The solution needs the SQL bacpac to be deployed which will house the tables used, as well as the SQL Stored Procedures that are run to create the random user pairings of three. The requirement is to run the Logic app that will get the users under a certain manager in AAD, this JSON output is then saved to a blob location.
# The ADF pipeline
ADF pipelines will do most of the work to orchestrate the solution to run. There is a recurrence trigger on the ADF Pipeline to run once a month. This will allow the organization the ability to configure it once, and the monthly trigger will call the graph api and return the current users of the manager, parse them from JSON into a SQL table, call a stored procedure to apply the ranking logic and to create random pairing of three people. Then the ADF Pipeline will call a Logic App that will create and send an outlook email to the groupings of three, CC the manager, and then will complete its run. 
*** Future updates could involve utilizing the ability to create Team Meetings, or to create a single date and time for the Watercooler, and the service could create a Meeting with specific "Breakout rooms" for the random pairings. Think of it as virtual speed networking! 

## The ADF "orchestrater" pipeline

![Alt text](/images/ADFOrchestrator.png?raw=true "Get graph info Logic App")


# The Logic Apps

## la-watercooler2
![Alt text](/images/la-watercooler2.png?raw=true "Get graph info Logic App")

This is the view of the Logic App that will get the users from the manager in the MSFT Graph. This is called from the ADF orchestrator pipeline.

## SendWCMessages Logic App

### Get the list of emails for the dynamic email

![Alt text](/images/SendWCMessagesSQLQuery.png?raw=true "image showing the first two steps of the SendWCMessages Logic App")

These are the first two steps of the Logic App to send the dynamic emails. The SQL step will get the groupings that were created via the Stored Procedure.The Where statement makes sure that this is the same day data.
#### Code:
```
SQL
SELECT [GroupAssigned]
      ,[emailchain]
      ,CONVERT(DATE, [AssignmentDate]) AS [UPDATEDATE]
  FROM [dbo].[WaterCoolerEmailGroupings]
  WHERE DATEDIFF(DAY,[AssignmentDate],GETDATE()) = 0
  
  ```
  ### Send the Outlook messages
 This is the image showing the Outlook connector in the Logic App. This step will create and send the groupings of people, along with the current month.
 
![Alt text](/images/SendWCMessagesOutlookMail.png?raw=true "image showing the send mail section of the SendWCMessages Logic App")

#### Outlook Connector Email Body example:

```
Welcome to the next round of our networking pods.  We have a number of new members on the team, and this is a good opportunity to make connections as members of the same team.  As a reminder, the goal of this is to have a casual meeting to get to know others on the team better.   While this is not mandatory, I do hope that you take this opportunity to network!  

The Ask:  One of you take the initiative and find a 30 minute time slot on your schedules to connect in the next two weeks.

Enjoy the conversation!

*** This was a completely automated task. Apologies if things don't seem 'human'.
```

## Subject Line Expression
This creates the dynamic month in the subject line of the email
#### Expression Code:
```
On Behalf of [Enter name]: @{formatDateTime(body('Parse_JSON')?['UPDATEDATE'], 'MMMM')} Watercooler pairings
```

#### To: line Expression Code:

This will take the semi-colon delimited grouping of three and use it as the email To: line

```
@{body('Parse_JSON')?['emailchain']}
```
### HTTP request to tell the ADF pipeline it is complete
![Alt text](/images/SendWCMessagesHTTP.png?raw=true "image showing the HTTP response back to the ADF call")



# SQL Stored Procs
These stored procedures will perform the logic that creates the random groupings of three users for the water cooler.

### The dbo.writeemployees.sql SP is used to take the JSON file that is in Blob and create a table of users using OPENJSON

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
