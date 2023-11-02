SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

-- =============================================
-- Author:		Ahmad Raeiji
-- Create date: 2021-06-01
-- Description:	Releasing SQL Server Engine Used Memory
-- =============================================

-- Create the stored procedure
CREATE PROCEDURE AR_DecreaseSQLServerUsedMemory
	@DesiredMaxMemory bigint, -- Desired Max Memory (MB)
	@DecreaseBy int = 1024 -- The memory amount (MB) that will decrease in each step.
AS
BEGIN
	-- Declare variables to hold current memory values
	declare @CurrentMaxMemory bigint
	declare @CurrentUsedMemory bigint
	
	-- Calculate the amount of memory used by the SQL Server engine
	SELECT @CurrentUsedMemory = (total_physical_memory_kb - available_physical_memory_kb) / 1024 FROM sys.dm_os_sys_memory
	
	-- Get the current max server memory value
	SELECT @CurrentMaxMemory = cast([value_in_use] as bigint) FROM sys.configurations WHERE [name] = 'max server memory (MB)'
	
	-- Calculate the maximum number of steps for loop prevention
	declare @LoopDetection int = ((@CurrentMaxMemory - @DesiredMaxMemory) / @DecreaseBy) + 2
	
	-- Check if the desired max memory is already lower than the current used memory
	if @DesiredMaxMemory > @CurrentUsedMemory
		begin
			RAISEERROR ('The current used memory is already lower than the desired maximum memory.', 16, 1)
			RETURN
		end
	else
	-- Check if the desired max memory is already lower than the current max memory
	if @DesiredMaxMemory < @CurrentMaxMemory
		begin
			RAISEERROR ('The current max server memory is already lower than the desired maximum memory.', 16, 1)
			RETURN
		end
	
	-- Enable advanced options
	EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
	
	-- Start the memory adjustment loop
	while @CurrentMaxMemory > @DesiredMaxMemory and @LoopDetection > 0
		begin
		    if @CurrentMaxMemory > @CurrentUsedMemory
				Set @CurrentMaxMemory = @CurrentUsedMemory
			Set @CurrentMaxMemory = @CurrentMaxMemory - @DecreaseBy
			EXEC sys.sp_configure N'max server memory (MB)', @CurrentMaxMemory
			RECONFIGURE WITH OVERRIDE
			waitfor delay '00:00:05' -- You can make changes to reduce interruptions caused by the SQL Server engine.
			SELECT @CurrentMaxMemory = cast([value_in_use] as bigint) FROM sys.configurations WHERE [name] = 'max server memory (MB)'
			Set @LoopDetection = @LoopDetection - 1
		end

	-- Disable advanced options
	EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
END
GO
