#!/usr/bin/env sysbench

-- Description: Establishes many SSL connections and runs SELECT 1
-- Usage: sysbench --db-driver=mysql --mysql-host=... --mysql-port=... \
--   --mysql-user=... --mysql-password=... --mysql-ssl=on --mysql-ssl-ca=... \
--   --threads=100 --time=60 connections.lua run

sysbench.cmdline.options = {
    frequency =
        {"Freq", 1000},
    tables =   
        {"Number of tables", 1},
    table_size =
        {"Number of rows per table", 10000}, 
    mysql_storage_engine =
        {"Storage engine, if MySQL is used", "innodb"}    
} 


function thread_init()
   drv = sysbench.sql.driver()
end


local query_count = 0

function event()
    con = drv:connect()
    local res, err = con:query("SELECT 1")
    local thread_id = sysbench.tid % sysbench.opt.threads 

    if not res then
        error("Query failed: " .. tostring(err))
    end

    -- Process the first row
    local row = res:fetch_row()
    if not row then
        error("No rows returned from query")
    end

    local value = tonumber(row[1])  -- Convert to number

    if value ~= 1 then
        error("Query result mismatch: expected 1, got " .. tostring(value))
    end


    query_count = query_count + 1

    if ((query_count % sysbench.opt.frequency) == 0) then
        -- print(string.format("thread_id=%d query_count=%d", thread_id, query_count))
        con:query("ALTER INSTANCE RELOAD TLS")
        --con:disconnect()
        --con = drv:connect()
    end   

    con:disconnect()
end


function thread_done()
end
