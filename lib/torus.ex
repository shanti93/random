defmodule TorusTopology do
use GenServer

##Initiate Gossip or pushsum based on SecondArgument
  def init([x,y,n, gossipOrpushSum]) do
    neighbors = actorNeighbors(x,y,n)
    case gossipOrpushSum do
      0 -> {:ok, [Active,0, 0, n*n, x, y | neighbors] } #Denotes [Status of the actor, received count, sent count, numNodes, NodeIDs x,y | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n*n , x, y| neighbors] } #Denotes [Status of the Actor, received count,streak,prev_s_w,ToTerminate, s, w, n, NodeIDs x,y | neighbors ]
    end
  end

  ## Network ##

#Creating Network TorusTopology
  def createTopology(n ,imperfect \\ false, gossipOrpushSum \\ 0) do
    actors =
      for x <- 1..n, y<- 1..n do
        name = actorName(x,y)
        GenServer.start_link(TorusTopology, [x,y,n, gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
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

  # NETWORK : Choosing a neigbor randomly to send message to
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

  # PUSHSUM

  # PUSHSUM - RECIEVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x, y | neighbors ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    GenServer.cast(Master,{:received, [{x,y}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,neighbors,self(),x,y)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x, y  | neighbors]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{x,y}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x, y  | neighbors]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,neighbors,self(),x,y)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x, y  | neighbors]}
          end
        end
  end

  ## Gossip Algorithm for information propagation

  # GOSSIP - RECIEVE Main
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

  def gossip(x,y,neighbors,pid) do
    the_one = chooseNeighborRandom(neighbors)
    IO.puts(the_one)
    GenServer.cast(the_one, {:message_gossip, :_sending})
  end

    # GOSSIP - HANDLE FAILURE SEND retry in case the Node is inactive
    def handle_cast({:retry_gossip, {pid}}, [status,count,sent,size,x,y| neighbors ] = state ) do
      gossip(x,y,neighbors,pid)
      {:noreply,state}
    end

  # NODE 

  # NODE : Checking status - Alive or Not
  def handle_call(:is_active,_from, state) do
    {status,x,y} =
      case state do
        [status,count,streak,prev_s_w,0, s ,w, n, x, y | neighbors ] -> {status,x,y}
        [status,count,sent,size,x,y| neighbors ] -> {status,x,y}
      end
    case status == Active do
      true -> {:reply, status, state }
      false -> {:reply, [{x,y}], state }
    end
  end

   # NODE : Deactivation
   def handle_cast({:deactivate, _},[ status |tail ] ) do
    {:noreply,[ Inactive | tail]}
  end

  # NODE : REMOVE inactive node from network
  def handle_cast({:remove_mate, actor}, state ) do
    new_state = List.delete(state,actor)
    {:noreply,new_state}
  end

  # NODE : ADD another node to replace inactive node
  def handle_cast({:add_new_mate, actor}, state ) do
    {:noreply, state ++ [actor]}
  end

##Push-Sum algorithm for sum computation

  # PUSHSUM  - SEND MAIN
  def push_sum(s,w,neighbors,pid ,x,y) do
    the_one = chooseNeighborRandom(neighbors)
    case GenServer.call(the_one,:is_active) do
      Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
      ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                  new_mate = GenServer.call(Master,:handle_node_failure)
                  GenServer.cast(self(),{:remove_mate,the_one})
                  GenServer.cast(self(),{:add_new_mate,new_mate})
                  GenServer.cast(new_mate,{:add_new_mate,actorName(x,y)})
                  GenServer.cast(self(),{:retry_push_sum,{s,w,pid}})
    end
  end

  # PUSHSUM - HANDLE FAILURE SEND retry - in case the Node is inactive
  def handle_cast({:retry_push_sum, {rec_s, rec_w,pid} }, [status,count,streak,prev_s_w,term, s ,w, n, x, y | neighbors ] = state ) do
    push_sum(rec_s,rec_w,neighbors,pid ,x,y)
    {:noreply,state}
  end


end
