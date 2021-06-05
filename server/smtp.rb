class SMTP

	def initialize
		@smtp = Net::SMTP.new 'smtp.gmail.com', 587
		@smtp.enable_starttls
		@smtp.start('gmail.com', GMAILUSER, GMAILPASS, :login)
		@mutex = Mutex.new
	end
	
	def send(recepient, subject, message)
		print 'test'
		msg = "From: " + GAMENAME + " Suppport Team\nSubject: #{subject}\n\n#{message}"
		@mutex.synchronize{
			@smtp.send_message(msg, GMAILUSER, recepient)
		}
	end
	
	def close
		@smtp.finish
	end
	
end