class SQL

	def initialize(host,username,password,database)
		@sql=Mysql.new(host,username,password,database)
		@sql.reconnect = true
		@mutex=Mutex.new
		self.optimise_database
	end
	
	def close
		@mutex.synchronize {
			@sql.close
			@sql = nil
		}
	end
	
	def optimise_database
		@mutex.synchronize {
			print "Optimising MySQL Database\n"
			tables = @sql.list_tables
			tables.each{|table|
				@sql.query("OPTIMIZE TABLE #{table}")
			}
		}
	end
	
	def query(query)
		@mutex.synchronize {
			return @sql.query(query)
		}
	end
	
	def escape_string(sql)
		return @sql.escape_string(sql)
	end
	
	def get_sqltime(time)
		return time.strftime('%Y-%m-%d %H-%M-%S')
	end
	
end
	