# Provisioning for Dummies

## Teaser

Good evening! I would like to thank everyone who made it to my talk and I hope you'll enjoy it. I decided to not talk about me patching PGBouncer, because provisioning seems like more relevant topic to me. Today I'm talking about my latest adventures in operations land. I'll explain how I happily replaced Chef with wake.

This is the number of files in each project and it is an indicator for its complexity. I'm happy with it so far since I've shrinked the project by ~88%.

```
$ find chef-repo/ | wc -l
2008
$ find wake/ | wc -l
237
```

You might think: NOT INVENTED HERE. But bear with me, it'll make sense.


## Intro

Before we get started, let me introduce myself. 

* twitter.com/i0rek github.com/i0rek
* working at 6Wunderkinder

## Story

### Chef

Until last month we've used Chef for our server provisioning. This first time I used it was in 2011 and I was amazed. I've used it since then whenever I needed to automate infrastructure.
For those who don't know what Chef is: automated configuration management tool. It gives you a DSL to write down you system configuration. You can even have a chef server where the chef clients can pull updates from. Chef supports multiple operating systems, different cloud providers and so on. 

Lately I wondered if we need all these features. I never really got how to do stuff with chef, there are environments, receipes, cookbooks, attributes, default attributes, overwrite attributes, BLA BLA. I'm lost, I never know where to put stuff. Or why do I need a receipe, a template and a yaml file in order to ship a config file?

### Infrastructure at 6W

Lets keep that stuff in mind while I explain, how we do our infrastructure at 6W. The essence is: we throw away a lot servers each day. Everytime we deploy new code we use fresh servers and throw the old ones away. We use aws, but there are other solutions with the same possibilities. You might've heard Chad talking about immutable infrastructure. Thats part of it, we do not change an existing server. We rather rebuild it from scratch every time.

I've already mentioned that we use aws, and I say it again, we use it exclusively. All our servers running on ubuntu, we aim for the latest version. We also try to keep things small, we rather have a more little services than some big ones. 

### Conclusion

So it appeared to me, that we might not need Chef because we run on a single platform, we don't update the servers and we only have small nodes. Chef is complicated, but I wondered if provisioning needs to be complicated for us?! Chef comes with lots of abstractions and I wondered if we need them? They're bothering me since day one, I think there is nothing as intention revealing as `mkdir -p /opt/your/app`. Whatever you come up with is more complicated. 

### Wake

If I can roll my own, what do I want?

1. SIMPLE - if possible no abstractions
2. AWS and Vagrant Support (I know Chef is a supported vagrant provisioner, but it never worked out for me)


#### Simple (KISS image)

What is the simplest thing you can think of in order to provision servers? Its bash for me. I choosed that intentionally because I also don't know anything about it. Everytime I have to do something conditionally I have to look it up. Because I'm so bad at it, I cannot do crazy things, I can only most basic stuff you can think of which is great! Assuming I've got access to a machine there are two things happening:

1. copy an script and a bunch of assets to the machine
2. start the script

On the server itself the script now extracts the assets calls out to other scripts. Config files for example are shipped as it is to the server. Thats all. 

The init script is ~50 lines long, the rails script is ~60 lines long. This is all it takes to fully boot any of our rails apps!!! 110 lines of bash! This is almost a valid class size according to Sandi Metz!

Unfortunately counting the lines it takes in to do the same in our Chef setup is beyond my abilities. :(

#### AWS and Vagrant

Having AWS and Vagrant support from day one was very important to me. The way I do the provisioning itself - with bash scripts - makes it really simple to use vagrant. I just execute it from the shared folder, done.

But I've never did the interaction with AWS myself and didn't know how to approach it. Fortunately I found two great tools: the aws cli and jq. AWS cli returns json data, which can be parsed and used by jq. Thats all I need to boot ec2 machines, attach them to the elb, terminate them, whatever. I've created some scripts for it and it works like a charm. These scripts are a mess, honestly. But I don't care. They are small, they do what they are supposed to do. Some are bash, some are ruby. 

I can now comfortable provision a vagrant machine, start an ec2 instance or create an ami from a provisioned ec2 instance or create servers from an ami and attach them to our elb. Or whatever I need to do.

Having control is extremely satisfying.

## The End (of Chef at 6W)

It is amazing how the immutable infrastructure enabled us to simplify our provisioning. So one improvement leads to another, which you haven't thought of initially.

I also want to say that aws cli and jq are awesome, wake wouldn't exist without them. 


## Refs

http://en.wikipedia.org/wiki/Chef_(software)