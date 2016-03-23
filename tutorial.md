#Multi-Node Elixir

Erlang, and therefor Elixir, are built on a foundation made for building distributed systems.

"Any sufficiently complicated distributed program in another language contains an ad hoc, informally-specified, bug-ridden, slow implementation of half of Erlang."

# Connecting some nodes
The project repo contains a vanilla phoenix app, with a docker-compose config to run it in two containers.
Erlang gives us the ability to connect nodes by default, but it is manual. We need to explicity tell our nodes the address of the
other nodes. Let's see how this default 'manual' way works:

First, create a docker-compose alias to save some typing:

`alias dc="docker-compose"`

Fire up a bash console on node1:

`dc run node1 /bin/bash`

In there, we start iex. However, for distributed erlang, our nodes need a name, the hostname/IP, and a cookie.
`iex --name multinode@$(ifconfig | awk '/inet addr/{print substr($2,6)}' | head -1) --cookie monster`

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

And rebuild the docker container and run the app:

```
dc build; dc up
```
