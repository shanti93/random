defmodule ImperfectLineTopology do
use GenServer


##Initiate Gossip or pushsum based on SecondArgument
  def init([x,n, gossipOrpushSum]) do
    mates = actor_mates(x,n)
    case gossipOrpushSum do
      0 -> {:ok, [Active,0,0, n, x | mates] } #[ status of actor, received count, sent count, numNodes, NOdeID | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n, x| mates] } #[status of actor, received count,streak,prev_s_w,to_terminate, s, w, n, NOdeID | neighbors ]
    end
  end


def createTopology(n, gossipOrpushSum) do
    actors =
      for x <- 1..n do
        name = actor_name(x)
        #IO.puts(name)
        GenServer.start_link(ImperfectLineTopology, [x,n, gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
    #IO.puts(n)
    #IO.puts(gossipOrpushSum)
end


#NETWORK : Naming Actor
  def actor_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end


#Defining neighbors
  def actor_mates(self,n) do
    case self do
      1 -> [actor_name(n), actor_name(2),Enum.random(3..n-1)]
      ^n -> [actor_name(n-1), actor_name(1),Enum.random(2..n-2)]
      _ -> [actor_name(self-1), actor_name(self+1),Enum.random([Enum.random(0..self-2),Enum.random(self+2..n)])]
    end
  end

   # NETWORK : Choosing a neigbor randomly to send message to
  def chooseNeighborRandom(neighbors) do
    Enum.random(neighbors)
  end



  ##### GOSSIP ALGORITHM
#SEND Main
  def gossip(x,mates,pid, n,i,j) do
    the_one = chooseNeighborRandom(mates)
    #IO.puts(x)
    #IO.puts(the_one )
    #GenServer.cast(the_one, {:message_gossip, :_sending})
    case GenServer.call(the_one,:is_active) do
      Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
      ina_xy -> GenServer.cast(Master,{:actor_inactive, ina_xy})
                new_mate = GenServer.call(Master,:handle_node_failure)
                GenServer.cast(self(),{:remove_mate,the_one})
                GenServer.cast(self(),{:add_new_mate,new_mate})
                GenServer.cast(new_mate,{:add_new_mate,actor_name(x)})
                GenServer.cast(self(),{:retry_gossip,{pid,i,j}})
    end
  end

#RECIEVE Main
 def handle_cast({:message_gossip, _received}, [status,count,sent,n,x| mates ] =state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    IO.puts(x)
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    #IO.puts(count)
    case count < 200 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,mates,self,n,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,n, x  | mates]}
 end


# GOSSIP - HANDLE FAILURE SEND retry in case the Node is inactive
  def handle_cast({:retry_gossip, {pid,i,j}}, [status,count,sent,n,x| mates ] =state ) do
    gossip(x,mates,pid, n,i,j)
    {:noreply,state}
  end

  # PUSHSUM #######################################################################################

  # PUSHSUM - RECIEVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x | mates ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum(x,(s+rec_s)/2,(w+rec_w)/2,mates,self(),i,j)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x  | mates]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x  | mates]}
            false -> push_sum(x,(s+rec_s)/2, (w+rec_w)/2, mates, self(), i, j)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x  | mates]}
          end
      end
  end

  # PUSHSUM  - SEND MAIN
  def push_sum(x,s,w,mates,pid ,i,j) do
    the_one = chooseNeighborRandom(mates)
    IO.puts(the_one)
GenServer.cast(the_one,{:message_push_sum,{ s,w}})
  end



  ###random
  # NODE : Checking status - Alive or Not
  def handle_call(:is_active , _from, state) do
    {status,n,x} =
      case state do
        [status,count,streak,prev_s_w,0, s ,w, n, x | mates ] -> {status,n,x}
        [status,count,sent,n,x| mates ] -> {status,n,x}
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

  # NODE : REMOVE inactive node from network
  def handle_cast({:remove_mate, actor}, state ) do
    new_state = List.delete(state,actor)
    {:noreply,new_state}
  end

  # NODE : ADD another node to replace inactive node
  def handle_cast({:add_new_mate, actor}, state ) do
    {:noreply, state ++ [actor]}
  end

end
