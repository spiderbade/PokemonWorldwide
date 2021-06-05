class ClientHandler

	def initialize
		@mutex = Mutex.new
		self.clear
	end

	def clear
		@clients = []
		@unknown_clients = []
	end
	
	def add(client)
		@mutex.synchronize {
			@unknown_clients.push(client)
		}
	end
	
	def delete(client)
		@mutex.synchronize {
			index = @unknown_clients.index(client)
			if index != nil
				@unknown_clients.delete_at(index)
				return
			end
			index = @clients.index(client)
			if index != nil
				@clients.delete_at(index)
			end
		}
	end
	
	def login(client)
		@mutex.synchronize {
			@unknown_clients.delete(client)
			@clients.push(client)
		}
	end
	
	def get(current = nil)
		@mutex.synchronize {
			clients = @clients.clone
			clients.delete(current) if current != nil
			return clients
		}
	end
	
	def get_all(current = nil)
		@mutex.synchronize {
			clients = @unknown_clients + @clients
			clients.delete(current) if current != nil
			return clients
		}
	end
	
	def get_unknown
		@mutex.synchronize {
			return @unknown_clients.clone
		}
	end
	
	def get_by_name(username)
		@mutex.synchronize {
			@clients.each {|client| return client if client.username.downcase == username.downcase}
			return nil
		}
	end
	
	def get_by_id(user_id)
		@mutex.synchronize {
			@clients.each {|client| return client if client.user_id == user_id}
			return nil
		}
	end
	
end