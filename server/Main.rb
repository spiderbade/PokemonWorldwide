RUBY_VERSION =~ /(\d+.\d+)/
version = $1

require 'socket'
require 'net/smtp'
require "./bin/#{version}/mysql_api"
require './server.rb'
require './mysql.rb'
require './client.rb'
require './clienthandler.rb'
require './send.rb'
require './smtp.rb'


IP = 127.0.0.1
PORT = 3306
SQLHOST = "127.0.0.1"
SQLUSR = "root"
SQLPASS = "eX4rJSQ2jU56hn" 
SQLDBASE = "peo"
GMAILUSER = "spiderrbade@gmail.com"
GMAILPASS = "GMAILPASSWORD" 
GAMENAME = "Game.exe" 
VERSION = 1
MAXIMUM_CONNECTIONS = 20
TRADETIMEOUT = 30
BATTLETIMEOUT = 30



	def main
		while true
		Client.reset
		Send.reset
		$clients = ClientHandler.new
		@server = Server.new
		@server.run
		end
	end
	
#begin
	print "Starting Server on #{IP}:#{PORT}\n"
	main
#rescue Interrupt
#end