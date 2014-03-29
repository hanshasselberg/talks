# Microservices

## Teaser

Good evening folks, I'm humbled that so many came to listen to my talk! I'm going to talk about an idea of mine which I call microservices. I had a problem: one of our services was slowing down our system. There are many ways to fix this problem, I made the service faster:

[graph]

## Intro

But before we dig into it, let me introduce myself.

* twitter.com/i0rek github.com/i0rek
* working at 6Wunderkinder
* OOS Typhoeus

I gave a talk last year about Typhoeus and Polyphasic sleep. The new Typhoeus version I talked about is released and I sleep normal again. Mostly because you need to be motivated and have support of the people living together with you.

## Disclaimer

I don't say ruby is slow. I don't shy away from problems.
Benchmarking is hard! Whatever I show is only an indicator and not the best
benchmark in the world!

## Story

### Fred George

There is a conference talk with the very same name - Micro Service Architecture - from Fred George at Baruco 2012 [1].
This talk is awesome and you should watch it. He talls his story how he started working on an enourmous single app and how he came to the conclusion over the years that mulitple small services are much easier to everything. In the end he advertised very small services like less 100lines of code.  Although this is related to what I'm talking about today it is not the same.

### Subject: Wunderpay

At 6W we have a very simple nameing schema: prefix everything with 'wunder'. We have a wunderboard, wunderapi, wundercloud, wunderadmin, and so on.  When we launched Pro accounts earlier this year we had a performance problem with our new and important wunderpay service. It was slow and impacting the whole system.

Wunderpay does two things:

1) create subscriptions
2) get subscriptions for a user

We don't need to look at 1) because buying happens only once in a while - even with great conversion rates. So the problem was 2) - we are calling that quite often internally.  There are two possible outcomes: a) the user is pro and it returns a subscription or b) he is not pro and nothing is returned.  Since we just launched the vast majority of these requests returned nothing.  The solution is a fast way to determine that the user has not paid a pro account.
Lets have a look at the code.

```ruby
# app/controllers/subscriptions_controller.rb
class SubscriptionController < ApplicationController
  def show
    if subscription = current_user.subscription
      render json: subscription.as_json
    else
      render json: {}
    end
  end
end
```

How fast is rails?

```
$ ab -n 1000 http://127.0.0.1:3000/user/123A/subscription
Requests per second:    177.88 [#/sec] (mean)
Time per request:       5.622 [ms] (mean)
```

When I was thinking about what might be the bottleneck I assumed the db call is the limiting factor. And then I could've been done with the problem.  Because the db won't get any faster, the query is simple, indexes were created.
But I questioned my assumption and wanted to proof it. I couldn't imagine to do it in rails, b/c it cannot get any simpler from a rails perspective. I choosed rack for my experiment.

### First approach: Rack

```ruby
require 'sequel'

class MyApp
  MIME_JS =  "application/javascript"
  def call(env)
    if env['REQUEST_PATH'] =~ /user\/(\w*)\/subscription/
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
```

How fast is it?

```
$ ab -n 1000 http://127.0.0.1:9292/user/123A/subscription
Requests per second:    856.72 [#/sec] (mean)
Time per request:       1.167 [ms] (mean)
```

OH. Thats interesting. My assumption was wrong! The Rack approach is 5 times faster! Lets look at the implementation again - what is happening?

1) query for existence
2) if not -> return immideately
3) if there is something FORWARD TO WUNDERPAY

3) is very important because thats the meat of this little service: whenever there is real work to do forward to the real service. Answer only the one thing you can: when a user has no subscription.

I can transparently deploy this service without changing wunderpay or changing wunderapi! This is a big thing b/c I can remove it as simple as that too. I call this service a microservice because it isn't even doing one thing - it only can do a quarter of one thing.
But it still provides great value because it makes the majority of wunderpay responses 5 times faster.

Another way to look at this is as an optimization. I'm afraid of optimizations! 'Premature optimization is the root of all evil'. I don't want to be that guy, which made the code unreadable, introduced several bugs and corrupted the data! But I've no problem deploying this service. It is easy to understand, you can throw it away whenever you want. That makes me happy!

### Second approach: Nginx

Ok, back to the roots. I've discovered that for my problem, Rack is faster than Rails. But can we get any faster?
I know Lua can be embedded inside of nginx - that sounds pretty fast to me!

```
worker_processes  1;
error_log logs/error.log;
events {
  worker_connections 1024;
}
http {
  server {
    listen 8080;
    location ~ /user/(\w*)/subscription {
      set $user_id $1;
      content_by_lua '
        local mysql = require "resty.mysql"
        local db, err = mysql:new()
        db:set_timeout(1000)

        local ok, err, errno, sqlstate = db:connect{
          host = "127.0.0.1",
          port = 3306,
          database = "wunderpay_development",
          user = "root"
        }

        res, err, errno, sqlstate = db:query("select 1 from subscriptions where user_id = \'" .. ngx.var.user_id .."\'")
        if next(res) == nil then
          ngx.say("{}")
        else
          ngx.redirect("http://wunderpay.org")
        end
      ';
    }
  }
}
```

This is a nginx configuration containing our little service. You can see the content_by_lua, the db connection and query and the response. Easy!

Give me AB:

```
$ ab -n 1000 http://127.0.0.1:8080/user/123A/subscription
Requests per second:    1752.04 [#/sec] (mean)
Time per request:       0.571 [ms] (mean)
```

Thats more than 2 times faster than the Rack implementation and 10 times faster
than the original Rails app.

### Resources

We've only looked at speed. But there is more! Lets have a look at how much memory each implementation uses. This is a quiz:

a) 5MB
b) 70MB
c) 400MB

1) Rails
2) Nginx & Lua
3) Rack

Solution: The nginx uses 5MB. This is 1/80th of Rails and also siginificantly less then Rack. That means nginx uses 1/80 * 1/10 = 1/800 of the resources compared to Rails. Thats huge. Again we are comparing a full Rails app to a microservice, but still - can you imagine the impact? For us that means we can serve everything from a single server instead of 3.
1/3 of the costs. #kthanksbye

## Q & A

## Refs

[1] Fred George: Micro Service Architecture: https://www.youtube.com/watch?v=2rKEveL55TY
