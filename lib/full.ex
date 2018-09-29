defmodule FullTopology do
use GenServer
##Initiate Gossip or pushsum based on SecondArgument
  def init([x,n, gossipOrpushSum]) do
    case gossipOrpushSum do
      0 -> {:ok, [Active,0,0, n, x ] } #[ Status of Actor, received count, sent count, numNodes, nodeID | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n, x] } #[ Status of Actor, received count,streak,prev_s_w,to_terminate, s, w, n, nodeID | neighbors ]
    end
  end
  def createTopology(n, gossipOrpushSum \\ 0) do
    actors =
      for x <- 1..n do
        name = actor_name(x)
            #IO.puts(name)
        GenServer.start_link(FullTopology, [x,n,gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
  end
  # Naming the actor
  def actor_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end
  # NETWORK : Choosing a neigbor randomly to send message to
  def chooseNeighborRandom(neighbors) do
    :rand.uniform(neighbors)
    |> actor_name()
  end
  # Gossip Algorithm for information propagation ###################################################################################
  # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,n,x ] =state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    case count < 100 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,self(),n,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,n, x  ]}
  end
  # GOSSIP  - SEND Main
  def gossip(x,pid, n,i,j) do
    the_one = chooseNeighborRandom(n)
    IO.puts(the_one)
    case the_one == actor_name(x) do
      true -> gossip(x,pid, n,i,j)
      false ->
        case GenServer.call(the_one,:is_active) do
          Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
                    ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                    gossip(x,pid, n,i,j)
        end
      end
  end
  # GOSSIP - SEND retry in case the Node is inactive
  # ~ Not Necessary for full network
  # NODE
  # NODE : Checking status - Alive or Not
  def handle_call(:is_active , _from, state) do
    {status,n,x} =
      case state do
        [status,count,streak,prev_s_w,0, s ,w, n, x ] -> {status,n,x}
        [status,count,sent,n,x ] -> {status,n,x}
      end
    case status == Active do
      true -> {:reply, status, state }
      false ->
        length = round(Float.ceil(:math.sqrt(n)))
        i = rem(x-1,length) + 1
        j = round(Float.floor(((x-1)/length))) + 1
        {:reply, [{i,j}], state }
    end
  end

  # NODE : Deactivation
  def handle_cast({:deactivate, _},[ status |tail ] ) do
    {:noreply,[ Inactive | tail]}
  end

  # Push-Sum algorithm for sum computation
  # PUSHSUM - RECEIVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,x,n,i,j)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x ]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x ]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,x,n,i,j)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x ]}
          end
        end
  end

  # PUSHSUM  - SEND MAIN
  def push_sum(s,w,x,n,i,j) do
    the_one = chooseNeighborRandom(n)
    case the_one == actor_name(x) do
      true -> push_sum(s,w,x,n,i,j)
      false ->
        case GenServer.call(the_one,:is_active) do
          Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
          ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                    push_sum(s,w,x,n,i,j)
        end
    end
  end
  # PUSHSUM - SEND retry - in case the Node is inactive
  # ~ Not necessary for Full
end
