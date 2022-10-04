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

