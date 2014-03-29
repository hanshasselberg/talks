require 'sequel'
class MyApp
  MIME_JS =  "application/javascript"
  def call(env)
    if env['REQUEST_PATH'] =~ /user\/(\w*)/
      unless Subscription.exists_for($1)
        [200, {"Content-Type" => MIME_JS }, ["{}\n"]]
      else
        [301, {"Content-Type" => MIME_JS, "Location" => "http://wunderpay.com"}, ["1\n"]]
      end
    end
  end
end
class Database
  def self.connection
    @connection ||= Sequel.connect('mysql://root@localhost/wunderpay_development')
  end
end
class Subscription
  def self.exists_for(user_id)
    Database.connection["select 1 from subscriptions where user_id = '#{user_id}' limit 1"].count > 0
  end
end
