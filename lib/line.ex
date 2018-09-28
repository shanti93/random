defmodule Line do
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
        GenServer.start_link(Line, [x,n, gossipOrpushSum], name: name)
        name
      end
    GenServer.cast(Master,{:actors_update,actors})
    #IO.puts(n)
    #IO.puts(gossipOrpushSum)
end


 # NETWORK : Naming Actor
  def actor_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end


# Defining neighbors

  def actor_mates(self,n) do
    case self do
      1 -> [actor_name(n), actor_name(2)] 
      ^n -> [actor_name(n-1), actor_name(1)]
      _ -> [actor_name(self-1), actor_name(self+1)]
    end
  end

   # NETWORK : Choosing a neigbor randomly to send message to
  def chooseNeighborRandom(neighbors) do
    Enum.random(neighbors)
  end



  ##### GOSSIP ALGORITHM

  #SEND Main
  def gossip(mates) do
    the_one = chooseNeighborRandom(mates)
    IO.puts(the_one)
    GenServer.cast(the_one, {:message_gossip, :_sending})
      
    
  end


   #RECIEVE Main 
  def handle_cast({:message_gossip, _received}, [status,count,sent,n,x| mates ] =state ) do   
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    #IO.puts(count)
    case count < 200 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]}) 
               gossip(mates)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end 
    {:noreply,[status,count+1 ,sent,n, x  | mates]}  
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
GenServer.cast(the_one,{:message_push_sum,{ s,w}})
  end

end