class Server

	attr_reader :running
	attr_reader :tcp
	
	def initialize
		@running = true
		@tcp = nil
	end
	
	def run
	print "Opening TCP Server\n"
	@tcp = TCPServer.new(IP,PORT)
	print "Connecting to MySQL Server\n"
	$mysql = SQL.new(SQLHOST,SQLUSR,SQLPASS,SQLDBASE)
	print "Connecting to the SMTP server\n"
	$smtp = SMTP.new
	self.run_thread_maintenance
		while @running
			begin
				connection = @tcp.accept_nonblock
			rescue
				sleep(0.1)
				next
			end
			Thread.start(connection) {|socket|
			buffer = ''
			client = Client.new(socket)
			$clients.add(client)
			while @running and client.connected?
				buffer += socket.recv(0xFFFF)
				messages = buffer.split("\n", -1)
				buffer = messages.pop
				messages.each {|message|
				client.handle(message)
				}
			end
			}
		end
	end
	
	def run_thread_maintenance
			time = Time.now
			t = Thread.start {
				i = 0
				while @running
					if i % 10 == 0
						$clients.get_unknown.each {|client|
							client.login_timeout -= Time.now - time
							if client.login_timeout < 0
								client.disconnect
							elsif i % 50 == 0
								begin
									client.sender.send("<PNG>")
								rescue
									client.disconnect
								end
							end
						}
						time = Time.now
					end
					if i % 50 == 0
						$clients.get.each {|client|
							begin
								client.sender.send("<PNG>")
							rescue
								client.disconnect
							end
						}
					end
					i = (i + 1) % 50
					sleep(0.1)
				end
			}
			t.priority = -10
		end
	
	end