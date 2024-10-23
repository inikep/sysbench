#!/usr/bin/env sysbench
-- This test is designed for testing MariaDB's key_cache_segments for MyISAM,
-- and should work with other storage engines as well.
--
-- For details about key_cache_segments please refer to:
-- http://kb.askmonty.org/v/segmented-key-cache
--

require("oltp_common")

-- Test specific options
sysbench.cmdline.options.random_points =
   {"Number of random points in the IN() clause in generated SELECTs", 10}
sysbench.cmdline.options.hot_points =
   {"If true then use the same N adjacent values for the inlist clause", false}
sysbench.cmdline.options.reset_binlog =
   {"Number of UPDATEs to call RESET MASTER to remove binlogs", 0}

mysql_version = 7.0

function thread_init()
   drv = sysbench.sql.driver()
   con = drv:connect()

   if sysbench.tid == 1 then
      local result = con:query_row("SELECT VERSION()")
      mysql_version = tonumber(result:match("^(%d+%.%d+)"))  -- Extract major and minor version
   end

   stmt = {}
   params = {}

   for t = 1, sysbench.opt.tables do
      stmt[t] = {}
      params[t] = {}
   end

   if sysbench.opt.hot_points then
      hot_key = sysbench.opt.table_size / 2
   end

   rlen = sysbench.opt.table_size / sysbench.opt.threads
   thread_id = sysbench.tid % sysbench.opt.threads

   local points = string.rep("?, ", sysbench.opt.random_points - 1) .. "?"

   for t = 1, sysbench.opt.tables do

      stmt[t] = con:prepare(string.format([[
           UPDATE sbtest%d set c=?
           WHERE id IN (%s)
           ]], t, points))

      params[t][1] = stmt[t]:bind_create(sysbench.sql.type.CHAR, 120)

      for j = 1, sysbench.opt.random_points do
         params[t][j+1] = stmt[t]:bind_create(sysbench.sql.type.INT)
      end

      stmt[t]:bind_param(unpack(params[t]))
   end

   log_id_if_pgsql()
end

function thread_done()
   for t = 1, sysbench.opt.tables do
      stmt[t]:close()
   end
   con:disconnect()
end

event_counter = 0

function event()
   local tnum = sysbench.rand.uniform(1, sysbench.opt.tables)

   local c_value_template = "###########-###########-###########-" ..
      "###########-###########-###########-" ..
      "###########-###########-###########-" ..
      "###########"

   params[tnum][1]:set_rand_str(c_value_template)

   if sysbench.opt.hot_points then
      for i = 1, sysbench.opt.random_points do
         params[tnum][i+1]:set(hot_key+i)
      end
   else
      for i = 1, sysbench.opt.random_points do
         params[tnum][i+1]:set(sysbench.rand.default(1, sysbench.opt.table_size))
      end
   end

   stmt[tnum]:execute()

   -- Execute RESET on MySQL every 1000000 events
   if sysbench.opt.reset_binlog > 0 and sysbench.tid == 1 then
     if event_counter * sysbench.opt.threads * sysbench.opt.random_points >= sysbench.opt.reset_binlog then
       if mysql_version < 8.4 then
         reset_query = "RESET MASTER"
       else
         reset_query = "RESET BINARY LOGS AND GTIDS"
       end
       print("Executing " .. reset_query .. " for MySQL " .. mysql_version)
       con:query(reset_query)
       event_counter = 0
     end
     event_counter = event_counter + 1
   end
end
