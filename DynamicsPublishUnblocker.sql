SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ahmad Raeiji
-- Create date: 2022-03-22
-- Description:	Microsoft Dynamics Publish Unblocker in Distributed Deployments
-- =============================================
CREATE PROCEDURE AR_DynamicsPublishUnblocker
AS
BEGIN
    DECLARE @UnblockingQuery NVARCHAR(MAX) = ''

    -- Construct the query to kill blocking sessions
    SELECT @UnblockingQuery = (
        SELECT DISTINCT 'KILL ' + CAST([dtst].session_id AS NVARCHAR(MAX)) + ' '
        FROM sys.dm_tran_database_transactions [dtdt]
        INNER JOIN sys.dm_tran_session_transactions [dtst] ON [dtst].[transaction_id] = [dtdt].[transaction_id]
        INNER JOIN sys.dm_exec_sessions [des] ON [des].[session_id] = [dtst].[session_id]
        INNER JOIN sys.dm_exec_connections [dec] ON [dec].[session_id] = [dtst].[session_id]
        LEFT OUTER JOIN sys.dm_exec_requests [der] ON [der].[session_id] = [dtst].[session_id]
        CROSS APPLY sys.dm_exec_sql_text([dec].[most_recent_sql_handle]) AS [dest]
        WHERE SUBSTRING(
            [dest].text,
            [der].statement_start_offset / 2 + 1,
            (CASE WHEN [der].statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), [dest].text)) * 2 ELSE [der].statement_end_offset END - [der].statement_start_offset) / 2
        ) = 'xp_userlock'
        AND [der].total_elapsed_time > 100000
        FOR XML PATH('')
    )

    -- Execute the unblocking query
    EXEC (@UnblockingQuery)
END
