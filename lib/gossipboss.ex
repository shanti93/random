defmodule Gossip do
 use GenServer

def handlefailure(args) do
    case length(args) do
      3 ->
        [numNodes_, topology, algorithm] = args
        {numNodes,_} = Integer.parse(numNodes_)
        percentage = 0
        mainfunction_(numNodes, topology, algorithm, percentage)
      4 ->
        [numNodes_, topology, algorithm, percentage_ ] = args
        {numNodes,_} = Integer.parse(numNodes_)
        {percentage,_} = Integer.parse(percentage_)
        mainfunction_(numNodes, topology, algorithm, percentage)
      #Other scenario enter message and return
      _ -> IO.puts("please enter correct number of arguments")
    end
  end


 ##Main function to handle input arguments - for now implementing gossip line!

def mainfunction_(numNodes, topology, algorithm, percentage) do
 size =  round(Float.ceil(:math.sqrt(numNodes)))
 Gossip.boss(size)

case algorithm do
  "gossip" ->
  case topology do
    "line" -> LineTopology.createTopology(numNodes, 0)
              failNodes(percentage)
              GenServer.cast(LineTopology.actorName(round(1)),{:message_gossip, :_sending})
    "rand2D"   -> GridTopology.createTopology(size,false, 0)
                    failNodes(percentage)
                    GenServer.cast(GridTopology.actorName(round(size/2),round(size/2)),{:message_gossip, :_sending})
    "full"   -> FullTopology.createTopology(numNodes, 0)
                    failNodes(percentage)
                    GenServer.cast(FullTopology.actorName(round(numNodes/2)),{:message_gossip, :_sending})
    "imp2D" -> ImperfectLineTopology.createTopology(numNodes, 0)
              failNodes(percentage)
              GenServer.cast(ImperfectLineTopology.actorName(round(1)),{:message_gossip, :_sending})
    "3D"   -> ThreeDTopology.createTopology(size,false, 0)
                    failNodes(percentage)
                    GenServer.cast(ThreeDTopology.actorName(round(size/2),round(size/2),round(size/2)),{:message_gossip, :_sending})
    "torus"   ->  TorusTopology.createTopology(size,false, 0)
                    failNodes(percentage)
                    GenServer.cast(TorusTopology.actorName(round(size/2),round(size/2)),{:message_gossip, :_sending})

    end
    "pushsum" ->
        case topology do
          "line"   -> LineTopology.createTopology(numNodes, 1)
                      failNodes(percentage)
                      GenServer.cast(LineTopology.actorName(round(numNodes/2)),{:message_push_sum, { 0, 0}})
          "rand2D"   -> GridTopology.createTopology(size,false, 1)
                      failNodes(percentage)
                      GenServer.cast(GridTopology.actorName(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          "full"   -> FullTopology.createTopology(numNodes, 1)
                      failNodes(percentage)
                      GenServer.cast(FullTopology.actorName(round(numNodes/2)),{:message_push_sum, { 0, 0}})
          "imp2D" -> ImperfectLineTopology.createTopology(numNodes, 0)
                      failNodes(percentage)
                      GenServer.cast(ImperfectLineTopology.actorName(round(numNodes/2)),{:message_push_sum, { 0, 0}})
          "3D"   -> ThreeDTopology.createTopology(size,false, 1)
                      failNodes(percentage)
                      GenServer.cast(ThreeDTopology.actorName(round(size/2),round(size/2),round(size/2)),{:message_push_sum, {0,0}})
          "torus"   -> TorusTopology.createTopology(size,false, 1)
                      failNodes(percentage)
                      GenServer.cast(TorusTopology.actorName(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
        end

end
 end



 def boss(nodesize) do
    GenServer.start_link(Gossip,nodesize, name: Master)
end

def failNodes(percentage) do
    case percentage do
      0 -> ""
      num -> GenServer.cast(Master,{:failNodes, percentage})
    end
  end


 def init(size) do
    # runs in the server context
    {:ok, [1,[],[],[{1,1}],[{1,1}],0,0,size,1,0,[],[] ]}
  end




  def handle_cast({:failNodes, percentage }, [_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,size,_init_time, actors, dead_actors]) do
    num_failNodes = round(size*size*percentage / 100)
    to_failNodes = Enum.take_random(actors,num_failNodes)
    IO.puts("failNodesd: #{inspect to_failNodes} ")
    Enum.each to_failNodes, fn( actor ) ->
      GenServer.cast(actor,{:failNodes, :you_are_getting_failNodesd })
    end
    {:noreply,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,size,_init_time,actors, dead_actors]}
  end

   # NETWORK - update state with the active actors
  def handle_cast({:actors_update, actors_update }, [_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size,_init_time, actors, dead_actors]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size,_init_time,actors_update,dead_actors]}
  end

  # HANDLE FAILURE - updating the actors that received the message
  def handle_cast({:received, actor }, [cast_num,received, hibernated, prev_actor, prev_actor_2,r_count, h_count,size, init_time,_actors ,dead_actors]) do
    init_time_ =
      case cast_num do
        1 -> DateTime.utc_now()
        _ -> init_time
      end
    {:noreply,[cast_num+1,received ++ actor, hibernated, actor, prev_actor, r_count + 1,h_count,size,init_time_,_actors, dead_actors]}
  end

  # HANDLE FAILURE - updating the messages that received the message
  def handle_cast({:hibernated, actor }, [cast_num,received, hibernated,prev_actor, prev_actor_2, r_count, h_count,size, init_time, actors,dead_actors]) do
    end_time = DateTime.utc_now
    convergence_time=DateTime.diff(end_time,init_time,:millisecond)
    IO.puts("Convergence time: #{convergence_time} ms")
    
  end


  # NODE - provide new neighbor to node that lost one neighbor due to failure
  def handle_call(:handle_node_failure, {actorId,_} ,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size, _init_time, actors,dead_actors]) do
    #IO.puts("inspecting #{inspect _from}")
    new_actor = Enum.random(actors)
    case :erlang.whereis(new_actor) do
      ^actorId -> new_actor = List.delete(actors,new_actor) |> Enum.random
      _ -> ""
    end
    {:reply,new_actor,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size,_init_time,actors,dead_actors]}
  end

  # NETWORK - update network with to highlight the inactive actors
  def handle_cast({:actor_inactive, actor },[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size, _init_time, actors,dead_actors]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size,_init_time,List.delete(actors,actor),dead_actors ++ actor]}
  end

   




 end
