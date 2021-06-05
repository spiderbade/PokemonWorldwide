Thank you for downloading beta 2.

If you have modified any of the online scripts, please use http://www.quickdiff.com/ to generate a difference file against beta 2's scripts to see what has been modified.

If you are using this download to update from a previous version, then please navigate to the database folder and using HeidiSQL or another MySQL manager, use 'beta1 to beta2.sql' to update the database (you will not lose any of your data)

This update includes SMTP functions, this allows the server to communicate with clients who have registered. In particular, this is used in PE O to send the player a code by email for them to reset their password. The chosen SMTP server is gmail, you can edit the settings in Main.rb (If you wish to use a different SMTP host, edit the connection settngs). The GAMENAME constant is, as written on the tin, is the name of your game and will be used in emails sent to players. Please be aware that if the server is hosted on a computer different from the one you usually use to sign into your gmail account, gmail will deny access to the server. You will ahve to log onto your google account and allow access to the server.
