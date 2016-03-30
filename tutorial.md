#Multi-Node Elixir

Erlang, and therefor Elixir, are built on a foundation made for building distributed systems.

"Any sufficiently complicated distributed program in another language contains an ad hoc, informally-specified, bug-ridden, slow implementation of half of Erlang."

# Connecting some nodes
The project repo contains a vanilla phoenix app, with a docker-compose config to run it in two containers.
Erlang gives us the ability to connect nodes by default, but it is manual. We need to explicity tell our nodes the address of the
other nodes. Let's see how this default 'manual' way works:

First, create a docker-compose alias to save some typing:

```
alias dc="docker-compose"
```

Fire up a bash console on node1:

```
dc run node1 /bin/bash
```

In there, we start iex. However, for distributed erlang, our nodes need a name, the hostname/IP, and a cookie.
```
iex --name multinode@$(ifconfig | awk '/inet addr/{print substr($2,6)}' | head -1) --cookie monster -S mix
```

Do the same for node 2 in a new terminal window, so we have an iex console to both instances of our app.

One any node, let's see what other nodes it knows about:

```
:erlang.nodes
# => []
```

An empty list, they don't know about each other yet. Let's ping one from the other:

```
Node.ping :"multinode@172.18.0.5"
# => :pong
```

Now, listing nodes from either node shows us the other node:

```
:erlang.nodes
# => [:"multinode@172.18.0.5"]
```
Note that this only shows us nodes other than the current node.

# Running functions distributed
The most basic thing we can do is run some code on another node. Let's try it:

```
Node.spawn :"multinode@172.18.0.5", fn -> IO.puts :erlang.node end
```

`:erlang.node` gets the name of the current node. You should see that the name of the target node is printed. You'll notice though
that it is printed on the current terminal, rather than the terminal of the other host. This happens because the process spawned on the
other node has the current node as its IO group leader - you can find out more about group leaders here: http://elixir-lang.org/getting-started/io-and-the-file-system.html#processes-and-group-leaders

In general, processes can communicate each other just the same whether they are local or on a remote machine - assuming you have a PID. Digging into this further
is a topic for a another day.

# Autodiscovery
So we can connect nodes, and run remote code, and talk to processes on other nodes. But having to statically connect our nodes doesn't seem
very flexible. Let's see if our nodes can autodiscover each other, so new nodes are automatically part of the group.

There is a library, 'nodefinder', that will do this for us. Add it as a dependency in mix.exs:

```
  defp deps do
    [{:phoenix, "~> 1.1.4"},
     ...
     {:nodefinder, github: 'okeuday/nodefinder'}
     ...
```

And add it the applications list:
```
     applications: [:phoenix, :phoenix_html, :cowboy, :logger, :gettext,
                    :phoenix_ecto, :postgrex, :nodefinder]]
```
I also found I had to add the package `erlang-xmerl` to the Dockerfile.

And rebuild the docker container and run the app:

```
dc build; dc up
```
Fire up the iex console as before and run:
```
:nodefinder.multicast_start
:erlang.nodes
# => [:"multinode@172.18.0.5"]
```
Voila, our other node has been discovered and is in our nodes list, automatically. We could easily add the `multicast_start` call to the start-up
of our app, so that any node to start just joins the cluster.

#Process Groups

Alright, we have a cluster of nodes, but this is just the start of building a useful distributed system.
Erlang privides a stardard module `pg2` for managing "process groups".

see http://erlang.org/doc/man/pg2.html

The basic idea is just a way to advertise and discover processes of a particular type...
e.g. "I'm a background job process" or "Give me all the video encoding processes".

Note, a single node can run many processes in different groups of course. Let's try it out.

```
:pg2.create "rockstars"
```
Now, on the other node, let's see if it knows about our group:
```
:pg2.which_groups
```
On any node, let's join the group with our current process.
```
:pg2.join "rockstars", self
```
And on the other node, let's see who's in the group:
```
:pg2.get_members "rockstars"
```
That's really all there is to `pg2`. There is a range
of useful functions in the `pg2` for dealing with groups, such as:
 - get_local_members: Only get processes on local node in a group
 - get_closest_pid: Get a process on the local if one exists, or choose one at random

This is a building block for many other useful things.

# Phoenix PubSub
Phoenix PubSub is a library which is part of phoenix which allows multiple nodes in a
phoenix app to communicate via pub/sub messaging.

Phoenix PubSub supports different backends that enable the actual communication between nodes - the default of which is
`pg2`, which we've just looked at. In some environments using distributed erlang is not possible,
due to network restrictions between nodes, e.g. Heroku. In this case, you can plug in another adapter.

Phoenix ships with the `pg2` and Redis adapers, but 3rd party ones exist for:
 - postgres
 - rabbitmq
 - vernemq

The beautiful thing about the erlang ecosytem, is that in many cases you don't need external technologies
to provide these services. Many Rails app that depend on tools like Memcache, Redis, Rabbitmq, various database
technologies etc etc, could be build in Elixir/Erlang with no dependencies...except maybe one database for persistence,
and acheive much greater performance.

## Channels on PubSub
The main thing PubSub is used for inside phoenix, is channels (Websockets). Channels are generally
a persistent connection from the client to an instance of the application. In order for data sent
to that instance to be available to clients connected to other instances of our app, they need to talk.

To demonstrate this, I'm going to follow the basic chat tutorial here:
http://www.phoenixframework.org/docs/channels

As one tiny extra step, I'm gonna add `:nodefinder.multicast_start` to the app start up, in
`lib/multi_node.ex`, somewhere in `def start_link`:
```
:nodefinder.multicast_start
```

Another thing, we need to remember to provide a node name and cookie to Phoexix when we start the app, just as did for our iex session:
```
elixir --name multinode@$(ifconfig | awk '/inet addr/{print substr($2,6)}' | head -1) --cookie monster -S mix phoenix.server
```

After following the steps in the guide, I'm gonna connect one browser tab to one instance (port 4000)
and another tab to the other (port 4001).

With that, I should be able to post messages from one chat window...which appear in my other tab, connected to a different
instance of my app.

Awesome Stuff. Distributed.
