CREATE PROCEDURE [dbo].[CreateOrUpdateException] 
	@LoadID int,
	--Source parameters
	@Source varchar(100),
	@SourceItemID int, --if @SourceItemID is null then it means there is no ability to update Exception later
	
	--Accession parameters
	@AccessionNumber varchar(50),
	@DateOfService datetime,

	--Exception parameters
	@Status varchar(100),
	@Reason varchar(100),
	@Note varchar(250),
	@Signer varchar(100),

	--Test Codes
	@TestCodes varchar(max),

	--Order parameters
	@SpmOrderNumber varchar(50),
	@OvOrderNumber varchar(50),
	@AccountNumber varchar(50),
	@PatientName varchar(250),
	@PatientDOB datetime,
	@PhysicianName varchar(250),
	@CollectionDate datetime
AS
BEGIN

--Check "LoadID"
if not exists (select * from LabExceptionLoad where LoadID = @LoadID)
begin
	raiserror('Specified "LabExceptionLoad" does not exist.', 16, 1);
end

--Set "SourceID"
declare @SourceID int
select @SourceID = SourceID from LabExceptionSource where Name = @Source
if @SourceID is null
begin
	raiserror('Specified "LabExceptionSource" does not exist.', 16, 1);
end

--Set "StatusID"
declare @StatusID int
select @StatusID = LabExceptionStatusID from LabExceptionStatus where Name = @Status

--Set "ReasonID"
declare @ReasonID int
select @ReasonID = LabExceptionReasonID from LabExceptionReason 
where Name = @Reason and (
		(@SourceID = 1 and LabExceptionReasonID > 0 and LabExceptionReasonID <= 100) or -- Incident Tracking
		(@SourceID = 3 and LabExceptionReasonID > 100 and LabExceptionReasonID <= 200) or -- Tech Service Dashboard
		(@SourceID = 2 and LabExceptionReasonID > 200 and LabExceptionReasonID <= 300) or -- GRE
		(@SourceID = 4 and LabExceptionReasonID > 300 and LabExceptionReasonID <= 400) -- Reporting TNP/QNS
	)

--Check & Set "SourceItemID"
if @SourceItemID is null --if @SourceItemID is null then it means there is no ability to update Exception later
begin
	declare @MaxSourceItemID int
	select @MaxSourceItemID = max(SourceItemID) from LabException where SourceID = @SourceID
	if @MaxSourceItemID is null
	begin
		set @SourceItemID = 1
	end
	else
	begin
		set @SourceItemID = @MaxSourceItemID + 1
	end
end
else
begin
	if exists(
		select 1 from LabException lx
		inner join 
			LabExceptionEvent lxv on lxv.LabExceptionID = lx.LabExceptionID
		where 
				lx.SourceID = @SourceID and 
				lx.SourceItemID = @SourceItemID and
				lxv.LabExceptionStatusID = @StatusID)
	begin
		print 'No updates on exisitng "LabException" item'
		return
	end
end

--Insert a new "LabExceptionStatus" item if "SourceID" is null
if @StatusID is null
begin
	insert into LabExceptionStatus(Name, CreatedByLoadID) 
	values (@Status, @LoadID)
	select @StatusID = SCOPE_IDENTITY()
	print 'The new "LabExceptionStatus" item (ID:' + convert(varchar(4),@StatusID) + ', Name:' + @Status + ') has been created.'
end

--Insert a new "LabExceptionReason" item if "ReasonID" is null
if @ReasonID is null
begin

	declare @MaxReasonID int
	select @MaxReasonID = max(LabExceptionReasonID) from LabExceptionReason
	where
		(@SourceID = 1 and LabExceptionReasonID > 0 and LabExceptionReasonID <= 100) or -- Incident Tracking
		(@SourceID = 3 and LabExceptionReasonID > 100 and LabExceptionReasonID <= 200) or -- Tech Service Dashboard
		(@SourceID = 2 and LabExceptionReasonID > 200 and LabExceptionReasonID <= 300) or -- GRE
		(@SourceID = 4 and LabExceptionReasonID > 300 and LabExceptionReasonID <= 400) -- Reporting TNP/QNS

	if @MaxReasonID is null
	begin
		set @ReasonID = 1
	end
	else
	begin
		set @ReasonID = @MaxReasonID + 1
	end

	insert into LabExceptionReason(LabExceptionReasonID, Name, CreatedByLoadID) 
	values (@ReasonID, @Reason, @LoadID)

	print 'The new "LabExceptionReason" item (ID:' + convert(varchar(4),@ReasonID) + ', Name:' + @Reason + ') has been created.'
end

--Insert a new "LabException" item if it is a new exception
declare @ExceptionID int
declare @EventID int
select 
	@ExceptionID = LabExceptionID, 
	@EventID = 2 --UpdateExisitng
from LabException where SourceID = @SourceID and SourceItemID = @SourceItemID
if @ExceptionID is null
begin
	insert into LabException(LabExceptionReasonID,SourceID,SourceItemID,AccessionNumber,DateOfService,CreatedByLoadID,IsInvisible)
	values (@ReasonID, @SourceID, @SourceItemID, @AccessionNumber, @DateOfService, @LoadID, 0)

	set @ExceptionID = SCOPE_IDENTITY()
	set @EventID = 1 --CreateNew
end

--Insert a new "LabExceptionEvent" item
insert into LabExceptionEvent(LabExceptionID,LabExceptionStatusID,EventTypeID,Note,IsRead,Signer,CreatedByLoadID)
values(@ExceptionID, @StatusID, @EventID, @Note, 0, @Signer, @LoadID)

--Insert a new "LabExceptionOrder" item
insert into LabExceptionOrder(LabExceptionID,SpmOrderNumber,OvOrderNumber,AccountNumber,PatientName,PatientDOB,PhysicianName,CollectionDate,CreatedByLoadID)
values (@ExceptionID,@SpmOrderNumber,@OvOrderNumber,@AccountNumber,@PatientName,@PatientDOB,@PhysicianName,@CollectionDate,@LoadID)

--Insert a new "LabExceptionTestCode" items
if @TestCodes is not null
begin
	insert into LabExceptionTestCode(LabExceptionID, TestCode,CreatedByLoadID)
	select @ExceptionID, Code, @LoadID from dbo.fn_ParseToTable(@TestCodes, ',')
end

END