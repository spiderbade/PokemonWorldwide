class Client

	@@login_mutex = nil
	@@register_mutex = nil
	@@trade_mutex = nil
	@@battle_mutex = nil
	@@manage_mutex = nil
	def self.reset
		@@login_mutex = Mutex.new
		@@register_mutex = Mutex.new
		@@trade_mutex = Mutex.new
		@@battle_mutex = Mutex.new
		@@manage_mutex = Mutex.new
	end
	
	attr_accessor :message
	attr_accessor :login_timeout
	attr_reader   :socket
	attr_reader   :sender
	attr_accessor :user_id
	attr_accessor :username
	attr_accessor :waitingfortrade
	attr_accessor :waitingforbattle
	attr_accessor :trainer
	attr_accessor :seed
	attr_accessor :turncount
	
	def initialize(socket)
		@message = ''
		@socket = socket
		@mutex = Mutex.new
		@login_timeout = 120
		@user_id = -1
		@username = ''
		@sender=Send.new(self)
		@waitingfortrade=""
		@tradeparty=""
		@offer = ""
		@tradeaccepted=false
		@tradedeclined=false
		@tradedead=false
		@waitingforbattle=""
		@trainer=nil
		@battler=nil
		@seed=0
		@turncount=0
	end
	
	def disconnect
		@socket.close rescue nil
		$clients.delete(self)
	end
	
	def terminate
	
	end
	
	def connected?
		return !@socket.closed?
	end
	
	def login(username,password)
		@@login_mutex.synchronize {
			check = $mysql.query("SELECT user_id, usergroup, banned, password FROM users WHERE username = '#{$mysql.escape_string(username)}'")
			return @sender.send("<LOG result=0>") if check.num_rows == 0
			hash = check.fetch_hash
			return @sender.send("<LOG result=1>") if hash['password'] != password
			return @sender.send("<LOG result=2>") if hash['banned'] != '0'
			user_id = hash['user_id'].to_i
			ip = @socket.peeraddr[3]
			check = $mysql.query("SELECT DISTINCT users.user_id FROM users JOIN ips ON users.user_id = ips.user_id " +"WHERE banned = 1 AND ips.ip = '#{ip}'")
			return @sender.send("<LOG result=3>") if check.num_rows > 0
			client = $clients.get_by_id(user_id)
			return @sender.send("<LOG result=5>") if client != nil
			self.set_user_data(user_id, username, hash['usergroup'].to_i)
			$mysql.query("UPDATE user_data SET lastlogin = '#{$mysql.get_sqltime(Time.now.getutc)}' WHERE user_id = #{user_id}")
			$mysql.query("REPLACE INTO ips(user_id, ip) VALUES (#{user_id}, '#{ip}')")
			$clients.login(self)
			@sender.send("<LOG result=4>")
		}
	end
	
	def register(user,pass,email)
		@@register_mutex.synchronize {
			check = $mysql.query("SELECT COUNT(*) AS count FROM users WHERE username = '#{$mysql.escape_string(user)}'")
			hash = check.fetch_hash
			return @sender.send("<REG result=0>") if hash['count'].to_i > 0
			check = $mysql.query("SELECT COUNT(*) AS count FROM users WHERE email = '#{$mysql.escape_string(email)}'")
			hash = check.fetch_hash
			return @sender.send("<REG result=1>") if hash['count'].to_i > 0
			check = $mysql.query("SELECT COUNT(*) AS count FROM users")
			hash = check.fetch_hash
			$mysql.query("START TRANSACTION")
			group = (hash['count'].to_i == 0 ? 10 : 0)
			$mysql.query("INSERT INTO users (username, password, email, usergroup) VALUES ('#{$mysql.escape_string(user)}', '#{$mysql.escape_string(pass)}', '#{$mysql.escape_string(email)}', #{group})")
			check = $mysql.query("SELECT user_id FROM users WHERE username = '#{$mysql.escape_string(user)}'")
			hash = check.fetch_hash
			user_id = hash['user_id'].to_i
			$mysql.query("INSERT INTO user_data (user_id, lastlogin) VALUES (#{user_id}, '#{$mysql.get_sqltime(Time.now.getutc)}')")
			ip = @socket.peeraddr[3]
			$mysql.query("REPLACE INTO ips(user_id, ip) VALUES (#{user_id}, '#{$mysql.escape_string(ip)}')")
			$mysql.query("COMMIT")
			@sender.send("<REG result=2>")
		}
	end
	
	def attempt_trade(player)
		@@trade_mutex.synchronize {
			check = $mysql.query("SELECT COUNT(*) AS count FROM users WHERE username = '#{$mysql.escape_string(player)}'")
			hash = check.fetch_hash
			return @sender.send("<TRA user=#{player} result=0>") if hash['count'].to_i == 0
			check = $mysql.query("SELECT banned FROM users WHERE username = '#{$mysql.escape_string(player)}'")
			hash = check.fetch_hash
			return @sender.send("<TRA user=#{player} result=1>") if hash['banned'] != '0'
			client = $clients.get_by_name(player)
			return @sender.send("<TRA user=#{player} result=2>") if client == nil
			Thread.start {
				wait_trade(player)
				@waitingfortrade=""
				@tradeparty=""
				@offer = ""
				@tradeaccepted=false
				@tradedeclined=false
				@tradedead=false
			}
			
		}
	end
	
	def wait_trade(player)
		t = Time.now.to_i
		@waitingfortrade = player.to_s
		loop do
			break if Time.now.to_i - t >= TRADETIMEOUT || $clients.get_by_name(player).waitingfortrade == "#{@username}"
		end
		if $clients.get_by_name(player).waitingfortrade == "#{@username}" and Time.now.to_i - t <= TRADETIMEOUT
			@sender.send("<TRA user=#{player} result=4>")
		else
			@waitingfortrade = ""
			return @sender.send("<TRA user=#{player} result=3>")
		end
		execute_trade(player)
	end
	
	def execute_trade(player)
		loop do
			if !$clients.get_by_name(@waitingfortrade).connected?
				$clients.get_by_name(player).sender.send("<TRA dead>")
				break
			end
			if @tradedeclined == true
				$clients.get_by_name(player).sender.send("<TRA declined>")
				@tradedeclined = false
				@tradeparty=""
				@offer=""
				@tradeaccepted=false
			end
			if @tradedead == true
				$clients.get_by_name(player).sender.send("<TRA dead>")
				break
			end
		end
	end

	def attempt_battle(player,trainer)
		@@battle_mutex.synchronize {
			check = $mysql.query("SELECT COUNT(*) AS count FROM users WHERE username = '#{$mysql.escape_string(player)}'")
			hash = check.fetch_hash
			return @sender.send("<BAT user=#{player} result=0 trainer=nil>") if hash['count'].to_i == 0
			check = $mysql.query("SELECT banned FROM users WHERE username = '#{$mysql.escape_string(player)}'")
			hash = check.fetch_hash
			return @sender.send("<BAT user=#{player} result=1 trainer=nil>") if hash['banned'] != '0'
			client = $clients.get_by_name(player)
			return @sender.send("<BAT user=#{player} result=2 trainer=nil>") if client == nil
			Thread.start {
				wait_battle(player,trainer)
				@waitingforbattle=""
				@trainer=nil
			}
			
		}
	end
	
	def wait_battle(player,trainer)
		t = Time.now.to_i
		@waitingforbattle = player.to_s
		@trainer=trainer
		loop do
			break if Time.now.to_i - t >= BATTLETIMEOUT || $clients.get_by_name(player).waitingforbattle == "#{@username}"
		end
		if $clients.get_by_name(player).waitingforbattle == "#{@username}" and Time.now.to_i - t <= BATTLETIMEOUT
			@sender.send("<BAT user=#{player} result=4 trainer=#{$clients.get_by_name(player).trainer}>")
		else
			@waitingforbattle = ""
			return @sender.send("<BAT user=#{player} result=3 trainer=nil>")
		end
		execute_battle(player)
	end
	
		
	def execute_battle(player)
		loop do
			if !$clients.get_by_name(@waitingforbattle).connected?
				@sender.send("<BAT dead>")
				@seed = nil
				@waitingforbattle = ""
				@turncount=nil
				break
			end
		end
	end
	
	def change_password(old,new)
		@@manage_mutex.synchronize{
			check = $mysql.query("SELECT password FROM users WHERE user_id = #{self.user_id}")
			hash = check.fetch_hash
			return @sender.send("<MAN password result=0>") if old != hash['password']
			$mysql.query("UPDATE users SET password = '#{$mysql.escape_string(new)}' WHERE user_id = #{self.user_id}")
			@sender.send("<MAN password result=1>")
		}
	end
	
	def change_email(new)
		@@manage_mutex.synchronize{
			check = $mysql.query("SELECT COUNT(*) AS count FROM users WHERE email = '#{$mysql.escape_string(new)}'")
			hash = check.fetch_hash
			return @sender.send("<MAN email result=0>") if hash['count'].to_i > 0
			$mysql.query("UPDATE users SET email = '#{$mysql.escape_string(new)}' WHERE user_id = #{self.user_id}")
			@sender.send("<MAN email result=1>")
		}
	end
	
	def handle(message)
		@message=message
		case @message
			when /<CON version=(.*)>/ then self.connection_request($1.to_i)
			when /<REG user=(.*) pass=(.*) email=(.*)>/ then self.register($1.to_s,$2.to_s,$3.to_s)
			when /<LOG user=(.*) pass=(.*)>/ then self.login($1.to_s,$2.to_s)
			when /<TRA user=(.*)>/ then self.attempt_trade($1.to_s)
			when /<TRA start>/ then $clients.get_by_name(@waitingfortrade).sender.send("<TRA start>")
			when /<TRA party=(.*)>/ then $clients.get_by_name(@waitingfortrade).sender.send("<TRA party=#{$1.to_s}>")
			when /<TRA offer=(.*)>/ then $clients.get_by_name(@waitingfortrade).sender.send("<TRA offer=#{$1.to_s}>")
			when /<TRA accepted>/ then $clients.get_by_name(@waitingfortrade).sender.send("<TRA accepted>")
			when /<TRA declined>/ then @tradedeclined = true
			when /<TRA dead>/ then @tradedead=true
			when /<BAT user=(.*) trainer=(.*)>/ then self.attempt_battle($1.to_s,$2.to_s)
			when /<BAT choices=(.*)>/ then $clients.get_by_name(@waitingforbattle).sender.send("<BAT choices=#{$1.to_s}>")
			when /<BAT new=(.*)>/ then $clients.get_by_name(@waitingforbattle).sender.send("<BAT new=#{$1.to_s}>")
			when /<BAT damage=(.*) state=(.*)>/ then $clients.get_by_name(@waitingforbattle).sender.send("<BAT damage=#{$1.to_s} state=#{$2.to_s}>")
			when /<BAT seed turn=(.*)>/
				@turncount =$1.to_i
				if @turncount > $clients.get_by_name(@waitingforbattle).turncount
					@seed = Time.now.to_i
				elsif @turncount == $clients.get_by_name(@waitingforbattle).turncount
					@seed = $clients.get_by_name(@waitingforbattle).seed
				end
				if @turncount == 0 and $clients.get_by_name(@waitingforbattle).seed == 0
					@seed = Time.now.to_i
				end
				@sender.send("<BAT seed=#{@seed}>")
			when /<MAN old=(.*) new=(.*)>/ then change_password($1.to_s,$2.to_s)
			when /<MAN email=(.*)>/ then change_email($1.to_s)
			when /<MAN forgot user=(.*) email=(.*)>/ then forgot_check($1.to_s,$2.to_s)
			when /<MAN forgot user=(.*) code=(.*)>/ then forgot_code($1.to_s,$2.to_s)
			when /<MAN forgot user=(.*) pass=(.*)>/ then forgot_pass($1.to_s,$2.to_s)
			when /<DSC>/ then self.disconnect
			else print "#{self} has sent an abnormal message"
		end
	end
	
	def forgot_check(user,email)
		@@manage_mutex.synchronize{
			check = $mysql.query("SELECT email FROM users WHERE username = '#{$mysql.escape_string(user)}'")
			return @sender.send("<MAN forgot user=#{user} result=0>") if check.num_rows == 0
			hash = check.fetch_hash
			return @sender.send("<MAN forgot user=#{user} result=1>") if hash['email'] != email
			@sender.send("<MAN forgot user=#{user} result=2>")
			code = Array.new(8){[*'0'..'9', *'a'..'z', *'A'..'Z'].sample}.join
			$mysql.query("UPDATE users SET uniquecode = '#{$mysql.escape_string(code)}' WHERE username = '#{$mysql.escape_string(user)}'")
			$smtp.send(email,"Reset Password request","Dear #{user},\nA password reset request was recently sent for this account. Your reset code is #{code}.\nIf it was not you who requested this, you can safely ignore this email.\n\nRegards,\nthe " + GAMENAME + " support team.")
		}
	end
	
	def forgot_code(user,code)
		@@manage_mutex.synchronize{
			check = $mysql.query("SELECT uniquecode FROM users WHERE username = '#{$mysql.escape_string(user)}'")
			return @sender.send("<MAN forgot user=#{user} result=0>") if check.num_rows == 0
			hash = check.fetch_hash
			return @sender.send("<MAN forgot user=#{user} result=3>") if hash['uniquecode'] != code
			@sender.send("<MAN forgot user=#{user} result=4>")
		}
	end
	
	def forgot_pass(user,pass)
		@@manage_mutex.synchronize{
			$mysql.query("UPDATE users SET password = '#{$mysql.escape_string(pass)}' WHERE username = '#{$mysql.escape_string(user)}'")
			$mysql.query("UPDATE users SET uniquecode = '' WHERE username = '#{$mysql.escape_string(user)}'")
		}
	end
	
	def set_user_data(user_id, username, usergroup)
		@mutex.synchronize {
			@user_id = user_id
			@username = username
			@usergroup = usergroup
		}
	end
	
	def connection_request(version)
		if version < VERSION
			result = 0
		elsif $clients.get.size >= MAXIMUM_CONNECTIONS
			result = 1
		else
			result = 2
		end
		@sender.send("<CON result=#{result}>")
	end
end