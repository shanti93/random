defmodule FullTopology do
use GenServer
##Initiate Gossip or pushsum based on SecondArgument
  def init([x,n, gossipOrpushSum]) do
    case gossipOrpushSum do
      0 -> {:ok, [Active,0,0, n, x ] } #Denotes [Status of Actor, received count, sent count, numNodes, nodeID | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n, x] } #Denotes [Status of Actor, received count,pushsumStreak,prevousSW,to_terminate, s, w, n, nodeID | neighbors ]
    end
  end

  #Creating Network FullTopology
  def createTopology(n, gossipOrpushSum \\ 0) do
    actors =
      for x <- 1..n do
        name = actorName(x)
            ##IO.puts(name)
        GenServer.start_link(FullTopology, [x,n,gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
  end
  # Providing a name to the Node
  def actorName(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end
    # Neighbor definition and choosing a randam neighbor to send the rumour
  def chooseNeighborRandom(neighbors) do
    :rand.uniform(neighbors)
    |> actorName()
  end
  # Gossip Algorithm for information propagation
  # # Receiving
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
  # Sending
  def gossip(x,actorId, n,i,j) do
    chosen = chooseNeighborRandom(n)
    #IO.puts(chosen)
    case chosen == actorName(x) do
      true -> gossip(x,actorId, n,i,j)
      false ->
        case GenServer.call(chosen,:is_active) do
          Active -> GenServer.cast(chosen, {:message_gossip, :_sending})
                    ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                    gossip(x,actorId, n,i,j)
        end
      end
  end

  # Push-Sum algorithm for sum computation
  # Receiving
  def handle_cast({:message_push_sum, {receive_s, receive_w} }, [status,count,pushsumStreak,prevousSW,term, s ,w, n, x] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+receive_s)/(w+receive_w))-prevousSW) < :math.pow(10,-10) do
        false ->push_sum((s+receive_s)/2,(w+receive_w)/2,x,n,i,j)
                {:noreply,[status,count+1, 0, (s+receive_s)/(w+receive_w), term, (s+receive_s)/2, (w+receive_w)/2, n, x ]}
        true ->
          case pushsumStreak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, pushsumStreak+1, (s+receive_s)/(w+receive_w), 1, (s+receive_s), (w+receive_w), n, x ]}
            false -> push_sum((s+receive_s)/2,(w+receive_w)/2,x,n,i,j)
                      {:noreply,[status,count+1, pushsumStreak+1, (s+receive_s)/(w+receive_w), 0, (s+receive_s)/2, (w+receive_w)/2, n, x ]}
          end
        end
  end

  # Sending
  def push_sum(s,w,x,n,i,j) do
    chosen = chooseNeighborRandom(n)
    case chosen == actorName(x) do
      true -> push_sum(s,w,x,n,i,j)
      false ->
        case GenServer.call(chosen,:is_active) do
          Active -> GenServer.cast(chosen,{:message_push_sum,{ s,w}})
          ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                    push_sum(s,w,x,n,i,j)
        end
    end
  end

  # The status of the node is checked if its active or not
  def handle_call(:is_active , _from, state) do
    {status,n,x} =
      case state do
        [status,count,pushsumStreak,prevousSW,0, s ,w, n, x ] -> {status,n,x}
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

  # # Failure Node scenario
  def handle_cast({:failNodes, _},[ status |tail ] ) do
    {:noreply,[ Inactive | tail]}
  end

end
