class MyApp
  def call(env)
    if env['REQUEST_PATH'] =~ /user\/(\w*)/
      unless Subscription.exists_for($1)
        [200, {}, ["{}\n"]]
      else
        [ 301,
          {"Location" => "http://wunderpay.de"},
          ["\n"]
        ]
      end
    end
  end
end
