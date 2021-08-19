#!/usr/bin/env sysbench

-- Command line options
sysbench.cmdline.options = {
   tables =
      {"Number of tables", 1},
   mysql_storage_engine =
      {"Storage engine, if MySQL is used", "innodb"}
}

function thread_init()
   drv = sysbench.sql.driver()
   con = drv:connect()
end

function prepare()
   local drv = sysbench.sql.driver()
   local con = drv:connect()

   local table_num

   for table_num = 1, sysbench.opt.tables do
      index_start = os.time()
      print(string.format("Creating a secondary index on 'sbtest%d'...",
                          table_num))
      con:query(string.format("CREATE INDEX k_%d ON sbtest%d(k)",
                              table_num, table_num))
      index_finish = os.time()
      print(string.format("Create a secondary index on 'sbtest%d' is %d seconds", table_num, index_finish - index_start))
   end
end

function event()
end

function thread_done()
   con:disconnect()
end

function cleanup()
end
