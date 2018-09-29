defmodule GridTopology do
use GenServer

##Initiate Gossip or pushsum based on SecondArgument
  def init([x,y,n, gossipOrpushSum]) do
    neighbors = actorNeighbors(x,y,n)
    case gossipOrpushSum do
      0 -> {:ok, [Active,0, 0, n*n, x, y | neighbors] } #Denotes [Status of the Actor, received count, sent count, n, NodeIDsx,y | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n*n , x, y| neighbors] } #Denotes [ Status of the Actor, received count,pushsumStreak,prevousSW,to_terminate, s, w, n, NodeIDsx,y | neighbors ]
    end
  end

#Creating Network GridTopology
  def createTopology(n ,imperfect \\ false, gossipOrpushSum \\ 0) do
    actors =
      for x <- 1..n, y<- 1..n do
        name = actorName(x,y)
        GenServer.start_link(GridTopology, [x,y,n, gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
    case imperfect do
      true -> randomify_neighbors( Enum.shuffle(actors) )
              "Imperfect Grid: #{inspect actors}"
      false -> "2D Grid: #{inspect actors}"
    end
  end

  # Adding random neighbors
  def randomify_neighbors([a,b|actors]) do
    case actors do
      [] -> ""
      [_] -> ""
      _ -> GenServer.cast(a,{:add_random_neighbor, b})
           GenServer.cast(b,{:add_random_neighbor, a})
           randomify_neighbors(actors)
    end
  end

  def handle_cast({:add_random_neighbor, new_mate}, state ) do
    {:noreply,state ++ [new_mate]}
  end

  # Providing a name to the Node
  def actorName(x,y) do
    a = x|> Integer.to_string |> String.pad_leading(4,"0")
    b = y|> Integer.to_string |> String.pad_leading(4,"0")
    "Elixir.D"<>a<>""<>b
    |>String.to_atom
  end

  # Neighbor definition and choosing a randam neighbor to send the rumour
  def chooseNeighborRandom(neighbors) do
    Enum.random(neighbors)
  end

  def actorNeighbors(nodeX,nodeY,n) do   #where n is length of grid / sqrt of size of network
    [l,r] =
        case nodeX do
          1 -> [n, 2]
          ^n -> [n-1, 1]
          _ -> [nodeX-1, nodeX+1]
        end
    [t,b] =
        case nodeY do
          1 -> [n, 2]
          ^n -> [n-1, 1]
          _ -> [nodeY-1, nodeY+1]
        end
    [actorName(l,nodeY),actorName(r,nodeY),actorName(t,nodeX),actorName(b,nodeX)]
  end

# Gossip Algorithm for information propagation

# # Receiving
def handle_cast({:message_gossip, _received}, [status,count,sent,size,x,y| neighbors ] = state ) do
  case count < 100 do
    true ->
      GenServer.cast(Master,{:received, [{x,y}]})
      gossip(x,y,neighbors,self())
    false ->
      GenServer.cast(Master,{:hibernated, [{x,y}]})
  end
  {:noreply,[status,count+1 ,sent,size, x , y | neighbors]}
end

def gossip(x,y,neighbors,actorId) do
  chosen = chooseNeighborRandom(neighbors)
  ##IO.puts(chosen)
  GenServer.cast(chosen, {:message_gossip, :_sending})
end

  # Handling failure scenario - Retry sending
  def handle_cast({:retry_gossip, {actorId}}, [status,count,sent,size,x,y| neighbors ] = state ) do
    gossip(x,y,neighbors,actorId)
    {:noreply,state}
  end

  # Push-Sum algorithm for sum computation

  # Receiving
  def handle_cast({:message_push_sum, {receive_s, receive_w} }, [status,count,pushsumStreak,prevousSW,term, s ,w, n, x, y | neighbors ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    GenServer.cast(Master,{:received, [{x,y}]})
      case abs(((s+receive_s)/(w+receive_w))-prevousSW) < :math.pow(10,-10) do
        false ->push_sum((s+receive_s)/2,(w+receive_w)/2,neighbors,self(),x,y)
                {:noreply,[status,count+1, 0, (s+receive_s)/(w+receive_w), term, (s+receive_s)/2, (w+receive_w)/2, n, x, y  | neighbors]}
        true ->
          case pushsumStreak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{x,y}]})
                      {:noreply,[status,count+1, pushsumStreak+1, (s+receive_s)/(w+receive_w), 1, (s+receive_s), (w+receive_w), n, x, y  | neighbors]}
            false -> push_sum((s+receive_s)/2,(w+receive_w)/2,neighbors,self(),x,y)
                      {:noreply,[status,count+1, pushsumStreak+1, (s+receive_s)/(w+receive_w), 0, (s+receive_s)/2, (w+receive_w)/2, n, x, y  | neighbors]}
          end
        end
  end

  # Handling failure scenario - Retry sending
  def handle_cast({:retry_push_sum, {receive_s, receive_w,actorId} }, [status,count,pushsumStreak,prevousSW,term, s ,w, n, x, y | neighbors ] = state ) do
    push_sum(receive_s,receive_w,neighbors,actorId ,x,y)
    {:noreply,state}
  end

  #Sending
  def push_sum(s,w,neighbors,actorId ,x,y) do
    chosen = chooseNeighborRandom(neighbors)
    case GenServer.call(chosen,:is_active) do
      Active -> GenServer.cast(chosen,{:message_push_sum,{ s,w}})
      ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                  new_mate = GenServer.call(Master,:handle_node_failure)
                  GenServer.cast(self(),{:remove_mate,chosen})
                  GenServer.cast(self(),{:add_new_mate,new_mate})
                  GenServer.cast(new_mate,{:add_new_mate,actorName(x,y)})
                  GenServer.cast(self(),{:retry_push_sum,{s,w,actorId}})
    end
  end


  # The status of the node is checked if its active or not
  def handle_call(:is_active,_from, state) do
    {status,x,y} =
      case state do
        [status,count,pushsumStreak,prevousSW,0, s ,w, n, x, y | neighbors ] -> {status,x,y}
        [status,count,sent,size,x,y| neighbors ] -> {status,x,y}
      end
    case status == Active do
      true -> {:reply, status, state }
      false -> {:reply, [{x,y}], state }
    end
  end

   # Failure Node Scenario
   def handle_cast({:failNodes, _},[ status |tail ] ) do
    {:noreply,[ Inactive | tail]}
  end

  #The inactive node is removed from the network
  def handle_cast({:remove_mate, actor}, state ) do
    new_state = List.delete(state,actor)
    {:noreply,new_state}
  end

  # To replace an inactive node, a new node is introduced
  def handle_cast({:add_new_mate, actor}, state ) do
    {:noreply, state ++ [actor]}
  end
end
