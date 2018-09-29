defmodule ThreeDTopology do
use GenServer

##Initiate Gossip or pushsum based on SecondArgument
  def init([x,y,z,n, gossipOrpushSum]) do
    neighbors = actorNeighbors(x,y,z,n)
    case gossipOrpushSum do
      0 -> {:ok, [Active,0, 0, n*n, x, y, z | neighbors] } #Denotes [ Status of an Actor, received count, sent count, n, self_number_id-x,y,z | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n*n , x, y, z| neighbors] } #Denotes [STatus of an Actor, received count,streak,prev_s_w,to_terminate, s, w, n, self_number_id-x,y,z | neighbors ]
    end
  end


#Creating Network ThreeDTopology
  def createTopology(n ,imperfect \\ false, gossipOrpushSum \\ 0) do
    actors =
      for x <- 1..n, y<- 1..n,z<- 1..n do
        name = actorName(x,y,z)
        GenServer.start_link(ThreeDTopology, [x,y,z,n, gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
  end

  # Providing a name to the Node
  def actorName(x,y,z) do
    a = x|> Integer.to_string |> String.pad_leading(4,"0")
    b = y|> Integer.to_string |> String.pad_leading(4,"0")
    c = z|> Integer.to_string |> String.pad_leading(4,"0")
    "Elixir.D"<>a<>""<>b<>""<>c
    |>String.to_atom
  end

  # Neighbor definition and choosing a randam neighbor to send the rumour
  def chooseNeighborRandom(neighbors) do
    Enum.random(neighbors)
  end

  def actorNeighbors(nodeX,nodeY,nodeZ,n) do
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
    [p,q] =
        case nodeZ do
          1 -> [n, 2]
          ^n -> [n-1, 1]
          _ -> [nodeZ-1, nodeZ+1]
        end
    [actorName(l,nodeY,nodeZ),actorName(r,nodeY,nodeZ),actorName(nodeX,t,nodeZ),actorName(nodeX,b,nodeZ),actorName(nodeX,nodeY,p),actorName(nodeX,nodeY,q)]
  end

  # Gossip Algorithm for information propagation

  # # Receiving
  def handle_cast({:message_gossip, _received}, [status,count,sent,size,x,y,z| neighbors ] = state ) do
    case count < 100 do
      true ->
        GenServer.cast(Master,{:received, [{x,y,z}]})
        gossip(x,y,z,neighbors,self())
      false ->
        GenServer.cast(Master,{:hibernated, [{x,y,z}]})
    end
    {:noreply,[status,count+1 ,sent,size, x , y,z | neighbors]}
  end

  def gossip(x,y,z,neighbors,actorId) do
    chosen = chooseNeighborRandom(neighbors)
    #IO.puts(chosen)
    GenServer.cast(chosen, {:message_gossip, :_sending})
  end

    # Handling failure scenario - Retry sending
    def handle_cast({:retry_gossip, {actorId}}, [status,count,sent,size,x,y,z| neighbors ] = state ) do
      gossip(x,y,z,neighbors,actorId)
      {:noreply,state}
    end

  #  Push-Sum algorithm for sum computation

  # Receiving
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x, y,z | neighbors ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    GenServer.cast(Master,{:received, [{x,y,z}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,neighbors,self(),x,y,z)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x, y,z  | neighbors]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{x,y,z}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x, y,z  | neighbors]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,neighbors,self(),x,y,z)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x, y,z  | neighbors]}
          end
        end
  end

  #Sending
  def push_sum(s,w,neighbors,actorId ,x,y,z) do
    chosen = chooseNeighborRandom(neighbors)
    case GenServer.call(chosen,:is_active) do
      Active -> GenServer.cast(chosen,{:message_push_sum,{ s,w}})
      ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                  new_mate = GenServer.call(Master,:handle_node_failure)
                  GenServer.cast(self(),{:remove_mate,chosen})
                  GenServer.cast(self(),{:add_new_mate,new_mate})
                  GenServer.cast(new_mate,{:add_new_mate,actorName(x,y,z)})
                  GenServer.cast(self(),{:retry_push_sum,{s,w,actorId}})
    end
  end

  # Handling failure scenario - Retry sending
  def handle_cast({:retry_push_sum, {rec_s, rec_w,actorId} }, [status,count,streak,prev_s_w,term, s ,w, n, x, y,z | neighbors ] = state ) do
    push_sum(rec_s,rec_w,neighbors,actorId ,x,y,z)
    {:noreply,state}
  end

  # The status of the node is checked if its active or not
  def handle_call(:is_active,_from, state) do
    {status,x,y,z} =
      case state do
        [status,count,streak,prev_s_w,0, s ,w, n, x, y,z | neighbors ] -> {status,x,y,z}
        [status,count,sent,size,x,y,z| neighbors ] -> {status,x,y,z}
      end
    case status == Active do
      true -> {:reply, status, state }
      false -> {:reply, [{x,y,z}], state }
    end
  end

   # Failure Node scenario
   def handle_cast({:failNodes, _},[ status |tail ] ) do
    {:noreply,[ Inactive | tail]}
  end

  # The inactive node is removed from the network
  def handle_cast({:remove_mate, actor}, state ) do
    new_state = List.delete(state,actor)
    {:noreply,new_state}
  end

  # To replace an inactive node, a new node is introduced
  def handle_cast({:add_new_mate, actor}, state ) do
    {:noreply, state ++ [actor]}
  end


end
