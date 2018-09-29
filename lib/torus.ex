defmodule TorusTopology do
use GenServer

##Initiate Gossip or pushsum based on SecondArgument
  def init([x,y,n, gossipOrpushSum]) do
    mates = actor_mates(x,y,n)
    case gossipOrpushSum do
      0 -> {:ok, [Active,0, 0, n*n, x, y | mates] } #[ rec_count, sent_count, n, self_number_id-x,y | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n*n , x, y| mates] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id-x,y | neighbors ]
    end
  end

  def createTopology(n ,imperfect \\ false, gossipOrpushSum \\ 0) do
    actors =
      for x <- 1..n, y<- 1..n do
        name = actor_name(x,y)
        GenServer.start_link(TorusTopology, [x,y,n, gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
  end

  # NETWORK : Changing Network for Imperfect Grid
  def randomify_mates([a,b|actors]) do
    case actors do
      [] -> ""
      [_] -> ""
      _ -> GenServer.cast(a,{:add_random_neighbor, b})
           GenServer.cast(b,{:add_random_neighbor, a})
           randomify_mates(actors)
    end
  end

  # NETWORK : Changing Network for Imperfect Grid continued : Adding Random Neighbors
  def handle_cast({:add_random_neighbor, new_mate}, state ) do
    {:noreply,state ++ [new_mate]}
  end

  # NETWORK : Naming the node
  def actor_name(x,y) do
    a = x|> Integer.to_string |> String.pad_leading(4,"0")
    b = y|> Integer.to_string |> String.pad_leading(4,"0")
    "Elixir.D"<>a<>""<>b
    |>String.to_atom
  end

  # NETWORK : Defining and assigning Neighbors
  def chooseNeighborRandom(neighbors) do
    Enum.random(neighbors)
  end

  # NETWORK : Choosing a neigbor randomly to send message to
  def actor_mates(self_x,self_y,n) do   #where n is length of grid / sqrt of size of network
    [l,r] =
        case self_x do
          1 -> [n, 2]
          ^n -> [n-1, 1]
          _ -> [self_x-1, self_x+1]
        end
    [t,b] =
        case self_y do
          1 -> [n, 2]
          ^n -> [n-1, 1]
          _ -> [self_y-1, self_y+1]
        end
    [actor_name(l,self_y),actor_name(r,self_y),actor_name(t,self_x),actor_name(b,self_x)]
  end

  # PUSHSUM

  # PUSHSUM - RECIEVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x, y | mates ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    GenServer.cast(Master,{:received, [{x,y}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,mates,self(),x,y)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x, y  | mates]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{x,y}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x, y  | mates]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,mates,self(),x,y)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x, y  | mates]}
          end
        end
  end

  # GOSSIP

  # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,size,x,y| mates ] = state ) do
    case count < 100 do
      true ->
        GenServer.cast(Master,{:received, [{x,y}]})
        gossip(x,y,mates,self())
      false ->
        GenServer.cast(Master,{:hibernated, [{x,y}]})
    end
    {:noreply,[status,count+1 ,sent,size, x , y | mates]}
  end

  def gossip(x,y,mates,pid) do
    the_one = chooseNeighborRandom(mates)
    IO.puts(the_one)
    GenServer.cast(the_one, {:message_gossip, :_sending})
  end

    # GOSSIP - HANDLE FAILURE SEND retry in case the Node is inactive
    def handle_cast({:retry_gossip, {pid}}, [status,count,sent,size,x,y| mates ] = state ) do
      gossip(x,y,mates,pid)
      {:noreply,state}
    end

  # NODE ##########################################################################################

  # NODE : Checking status - Alive or Not
  def handle_call(:is_active,_from, state) do
    {status,x,y} =
      case state do
        [status,count,streak,prev_s_w,0, s ,w, n, x, y | mates ] -> {status,x,y}
        [status,count,sent,size,x,y| mates ] -> {status,x,y}
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


  # PUSHSUM  - SEND MAIN
  def push_sum(s,w,mates,pid ,x,y) do
    the_one = chooseNeighborRandom(mates)
    case GenServer.call(the_one,:is_active) do
      Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
      ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                  new_mate = GenServer.call(Master,:handle_node_failure)
                  GenServer.cast(self(),{:remove_mate,the_one})
                  GenServer.cast(self(),{:add_new_mate,new_mate})
                  GenServer.cast(new_mate,{:add_new_mate,actor_name(x,y)})
                  GenServer.cast(self(),{:retry_push_sum,{s,w,pid}})
    end
  end

  # PUSHSUM - HANDLE FAILURE SEND retry - in case the Node is inactive
  def handle_cast({:retry_push_sum, {rec_s, rec_w,pid} }, [status,count,streak,prev_s_w,term, s ,w, n, x, y | mates ] = state ) do
    push_sum(rec_s,rec_w,mates,pid ,x,y)
    {:noreply,state}
  end


end
