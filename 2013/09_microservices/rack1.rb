require 'sequel'
class Database
  def self.connection
    @connection ||= Sequel.connect(
      'mysql://root@localhost/wunderpay_development'
    )
  end
end
class Subscription
  def self.exists_for(user_id)
    Database.connection[
      "SELECT 1
       FROM Subscriptions
       WHERE user_id = '#{user_id}'
       LIMIT 1"
    ].count > 0
  end
end
