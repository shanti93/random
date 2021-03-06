defmodule ImperfectLineTopology do
use GenServer


##Initiate Gossip or pushsum based on SecondArgument
  def init([x,n, gossipOrpushSum]) do
    neighbors = actorNeighbors(x,n)
    case gossipOrpushSum do
      0 -> {:ok, [Active,0,0, n, x | neighbors] } #Denotes [status of actor, received count, sent count, numNodes, NOdeID | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n, x| neighbors] } #Denotes [status of actor, received count,pushsumStreak,prevousSW,to_terminate, s, w, n, NOdeID | neighbors ]
    end
  end

#Creating Network ImperfectLineTopology
def createTopology(n, gossipOrpushSum) do
    actors =
      for x <- 1..n do
        name = actorName(x)
        ##IO.puts(name)
        GenServer.start_link(ImperfectLineTopology, [x,n, gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
    ##IO.puts(n)
    ##IO.puts(gossipOrpushSum)
end


#Providing a name to the Node
  def actorName(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end


  # Neighbor definition and choosing a randam neighbor to send the rumour
  def actorNeighbors(self,n) do
    case self do
      1 -> [actorName(n), actorName(2),Enum.random(3..n-1)]
      ^n -> [actorName(n-1), actorName(1),Enum.random(2..n-2)]
      _ -> [actorName(self-1), actorName(self+1),Enum.random([Enum.random(0..self-2),Enum.random(self+2..n)])]
    end
  end

  def chooseNeighborRandom(neighbors) do
    Enum.random(neighbors)
  end



  ## Gossip Algorithm for information propagation
# Sending
  def gossip(x,neighbors,actorId, n,i,j) do
    chosen = chooseNeighborRandom(neighbors)
    ##IO.puts(x)
    ##IO.puts(chosen )
    #GenServer.cast(chosen, {:message_gossip, :_sending})
    case GenServer.call(chosen,:is_active) do
      Active -> GenServer.cast(chosen, {:message_gossip, :_sending})
      ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                new_mate = GenServer.call(Master,:handle_node_failure)
                GenServer.cast(self(),{:remove_mate,chosen})
                GenServer.cast(self(),{:add_new_mate,new_mate})
                GenServer.cast(new_mate,{:add_new_mate,actorName(x)})
                GenServer.cast(self(),{:retry_gossip,{actorId,i,j}})
    end
  end

# Receiving
 def handle_cast({:message_gossip, _received}, [status,count,sent,n,x| neighbors ] =state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    #IO.puts(x)
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    ##IO.puts(count)
    case count < 200 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,neighbors,self,n,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,n, x  | neighbors]}
 end


# Handling failure scenario - Retry sending
  def handle_cast({:retry_gossip, {actorId,i,j}}, [status,count,sent,n,x| neighbors ] =state ) do
    gossip(x,neighbors,actorId, n,i,j)
    {:noreply,state}
  end

  # Push-Sum algorithm for sum computation

  # Receiving
  def handle_cast({:message_push_sum, {receive_s, receive_w} }, [status,count,pushsumStreak,prevousSW,term, s ,w, n, x | neighbors ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+receive_s)/(w+receive_w))-prevousSW) < :math.pow(10,-10) do
        false ->push_sum(x,(s+receive_s)/2,(w+receive_w)/2,neighbors,self(),i,j)
                {:noreply,[status,count+1, 0, (s+receive_s)/(w+receive_w), term, (s+receive_s)/2, (w+receive_w)/2, n, x  | neighbors]}
        true ->
          case pushsumStreak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, pushsumStreak+1, (s+receive_s)/(w+receive_w), 1, (s+receive_s), (w+receive_w), n, x  | neighbors]}
            false -> push_sum(x,(s+receive_s)/2, (w+receive_w)/2, neighbors, self(), i, j)
                      {:noreply,[status,count+1, pushsumStreak+1, (s+receive_s)/(w+receive_w), 0, (s+receive_s)/2, (w+receive_w)/2, n, x  | neighbors]}
          end
      end
  end

  #Sending
  def push_sum(x,s,w,neighbors,actorId ,i,j) do
    chosen = chooseNeighborRandom(neighbors)
    ##IO.puts(chosen)
GenServer.cast(chosen,{:message_push_sum,{ s,w}})
  end

  # The status of the node is checked if its active or not
  def handle_call(:is_active , _from, state) do
    {status,n,x} =
      case state do
        [status,count,pushsumStreak,prevousSW,0, s ,w, n, x | neighbors ] -> {status,n,x}
        [status,count,sent,n,x| neighbors ] -> {status,n,x}
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

   # Failure Node scenario
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
