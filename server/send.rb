class Send

	@@mutex = nil
	def self.reset
		@@mutex = Mutex.new
	end
	
	def initialize(client)
		@client = client
	end

	def send(message)
	@@mutex.synchronize {
		@client.socket.send(message + "\n", 0)
	}
	end
	
end