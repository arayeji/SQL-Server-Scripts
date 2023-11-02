
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ahmad Raeiji
-- Create date: 2021-06-01
-- Description:	Decreasing SQL Server Engine Memory Usage
-- =============================================
create PROCEDURE AR_DecreaseSQLServerUsedMemory
	@DesiredMaxMemory bigint, -- Desired Max Memory (MB)
	@DecreaseBy int = 1024 -- The memory amount (MB) that will decrease in each step.
AS
BEGIN
	declare @CurrentMaxMemory bigint
	declare @CurrentUsedMemory bigint
	
	SELECT @CurrentUsedMemory=(total_physical_memory_kb-available_physical_memory_kb)/1024 FROM sys.dm_os_sys_memory -- Calculating the amount of memory used by the SQL Server engine.
	
	SELECT @CurrentMaxMemory=cast([value_in_use] as bigint) FROM sys.configurations WHERE [name] = 'max server memory (MB)' -- Getting current max server memory

	declare @LoopDetection int = ((@CurrentMaxMemory-@DesiredMaxMemory)/@DecreaseBy)+2 -- Calculating the maximum number of steps for loop prevention.

	if @DesiredMaxMemory>@CurrentUsedMemory
		begin
			RAISERROR ('The current used memory is already lower than the desired maximum memory.',16,1)
			RETURN
		end
	else
	if @DesiredMaxMemory<@CurrentMaxMemory
		begin
			RAISERROR ('The current max server memory is already lower than the desired maximum memory.',16,1)
			RETURN
		end
	
	EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
	
	while @CurrentMaxMemory>@DesiredMaxMemory and @LoopDetection>0
		begin
		    if @CurrentMaxMemory>@CurrentUsedMemory
				Set @CurrentMaxMemory=@CurrentUsedMemory
			Set @CurrentMaxMemory=@CurrentMaxMemory-@DecreaseBy
			EXEC sys.sp_configure N'max server memory (MB)', @CurrentMaxMemory
			RECONFIGURE WITH OVERRIDE
			waitfor delay '00:00:05' -- You can make changes to reduce interruptions caused by the SQL Server engine.
			SELECT @CurrentMaxMemory=cast([value_in_use] as bigint) FROM sys.configurations WHERE [name] = 'max server memory (MB)'
			Set @LoopDetection=@LoopDetection-1
		end

	EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
END
GO
