defmodule Gossip do
 use GenServer



def main(args) do
    case length(args) do
      3 -> 
        [numNodes_, topology, algorithm] = args
        {numNodes,_} = Integer.parse(numNodes_)
        percentage = 0 
        main_(numNodes, topology, algorithm, percentage)
      4 ->
        [numNodes_, topology, algorithm, percentage_ ] = args        
        {numNodes,_} = Integer.parse(numNodes_)       
        {percentage,_} = Integer.parse(percentage_)
        main_(numNodes, topology, algorithm, percentage)
      _ -> IO.puts("please recheck your entry")
    end
  end


 ##Main function to handle input arguments - for now implementing gossip line!

def main_(numNodes, topology, algorithm, percentage) do
 size =  round(Float.ceil(:math.sqrt(numNodes)))
 Gossip.boss(size)
 
case algorithm do
  "gossip" ->
  case topology do
    "line" -> LineTopology.createTopology(numNodes, 0)
              deactivate(percentage)
              GenServer.cast(LineTopology.actor_name(round(1)),{:message_gossip, :_sending})
    "grid"   -> GridTopology.createTopology(size,false, 0)
                    deactivate(percentage)
                    GenServer.cast(GridTopology.actor_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
    "full"   -> FullTopology.createTopology(numNodes, 0)
                    deactivate(percentage)
                    GenServer.cast(FullTopology.actor_name(round(numNodes/2)),{:message_gossip, :_sending})
    "imperfectline" -> ImperfectLineTopology.createTopology(numNodes, 0)
              deactivate(percentage)
              GenServer.cast(ImperfectLineTopology.actor_name(round(1)),{:message_gossip, :_sending})
    "threed"   -> ThreeDTopology.createTopology(size,false, 0)
                    deactivate(percentage)
                    GenServer.cast(ThreeDTopology.actor_name(round(size/2),round(size/2),round(size/2)),{:message_gossip, :_sending})
    "torus"   ->  TorusTopology.createTopology(size,false, 0)
                    deactivate(percentage)
                    GenServer.cast(TorusTopology.actor_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
    
    end
    "pushsum" -> 
        case topology do
          "line"   -> LineTopology.createTopology(numNodes, 1)
                      deactivate(percentage)
                      GenServer.cast(LineTopology.actor_name(round(numNodes/2)),{:message_push_sum, { 0, 0}})
          "grid"   -> GridTopology.createTopology(size,false, 1)
                      deactivate(percentage)
                      GenServer.cast(GridTopology.actor_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          "full"   -> FullTopology.createTopology(numNodes, 1)
                      deactivate(percentage)
                      GenServer.cast(FullTopology.actor_name(round(numNodes/2)),{:message_push_sum, { 0, 0}})
          "imperfectline" -> ImperfectLineTopology.createTopology(numNodes, 0)
                      deactivate(percentage)
                      GenServer.cast(ImperfectLineTopology.actor_name(round(numNodes/2)),{:message_push_sum, { 0, 0}})  
          "threed"   -> ThreeDTopology.createTopology(size,false, 1)
                      deactivate(percentage)
                      GenServer.cast(ThreeDTopology.actor_name(round(size/2),round(size/2),round(size/2)),{:message_push_sum, {0,0}}) 
          "torus"   -> TorusTopology.createTopology(size,false, 1)
                      deactivate(percentage)
                      GenServer.cast(TorusTopology.actor_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})         
        end

#Process.sleep(:infinity)
end



 end
 def boss(nodesize) do
    GenServer.start_link(Gossip,nodesize, name: Master)
end

def deactivate(percentage) do
    case percentage do
      0 -> ""
      num -> GenServer.cast(Master,{:deactivate, percentage})
    end
  end


 def init(size) do
    # runs in the server context 
    {:ok, [1,[],[],[{1,1}],[{1,1}],0,0,size,1,0,[],[] ]}
  end




  def handle_cast({:deactivate, percentage }, [_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,size, _draw_every,_init_time, actors, dead_actors]) do
    num_deactivate = round(size*size*percentage / 100)
    to_deactivate = Enum.take_random(actors,num_deactivate)
    IO.puts("deactivated: #{inspect to_deactivate} ")
    Enum.each to_deactivate, fn( actor ) -> 
      GenServer.cast(actor,{:deactivate, :you_are_getting_deactivated })
    end
    {:noreply,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,size,_draw_every,_init_time,actors, dead_actors]}
  end

   # NETWORK - update state with the active actors
  def handle_cast({:actors_update, actors_update }, [_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size, _draw_every,_init_time, actors, dead_actors]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size,_draw_every,_init_time,actors_update,dead_actors]}
  end

  # HANDLE FAILURE - updating the actors that received the message
  def handle_cast({:received, actor }, [cast_num,received, hibernated, prev_actor, prev_actor_2,r_count, h_count,size, draw_every,init_time,_actors ,dead_actors]) do
    init_time_ = 
      case cast_num do
        1 -> DateTime.utc_now()
        _ -> init_time 
      end
    draw_every_=
      case cast_num == draw_every * 10 do
        true-> draw_every * 5
        false -> draw_every
      end
    case rem(cast_num,draw_every)==0 do
      true -> Task.start(Gossip,:draw_image,[received,hibernated,0,actor,prev_actor,prev_actor_2,size,cast_num,dead_actors])
      false-> ""
    end
    {:noreply,[cast_num+1,received ++ actor, hibernated, actor, prev_actor, r_count + 1,h_count,size,draw_every_,init_time_,_actors, dead_actors]}
  end

  # HANDLE FAILURE - updating the messages that received the message
  def handle_cast({:hibernated, actor }, [cast_num,received, hibernated,prev_actor, prev_actor_2, r_count, h_count,size, draw_every,init_time, actors,dead_actors]) do
    draw_image(received,hibernated,1,actor,prev_actor, prev_actor_2,size,cast_num,dead_actors)
    end_time = DateTime.utc_now
    convergence_time=DateTime.diff(end_time,init_time,:millisecond)
    IO.puts("Convergence time: #{convergence_time} ms")
    draw_image(received,hibernated,1,actor,prev_actor, prev_actor_2,size,cast_num, dead_actors)
    {:noreply,[cast_num+1,received, hibernated ++ actor,actor, prev_actor, r_count, h_count + 1,size,draw_every,init_time,actors,dead_actors]}
  end


  # NODE - provide new neighbor to node that lost one neighbor due to failure
  def handle_call(:handle_node_failure, {pid,_} ,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size, _draw_every,_init_time, actors,dead_actors]) do
    #IO.puts("inspecting #{inspect _from}")
    new_actor = Enum.random(actors)
    case :erlang.whereis(new_actor) do
      ^pid -> new_actor = List.delete(actors,new_actor) |> Enum.random
      _ -> ""
    end
    {:reply,new_actor,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size,_draw_every,_init_time,actors,dead_actors]}
  end

  # NETWORK - update network with to highlight the inactive actors
  def handle_cast({:actor_inactive, actor },[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size, _draw_every,_init_time, actors,dead_actors]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_actor, _prev_actor_2, _r_count, _h_count,_size,_draw_every,_init_time,List.delete(actors,actor),dead_actors ++ actor]}
  end

    # plots diagram at given instants of the whole network
  def draw_image(received, hibernated, terminated,actor,prev_actor, prev_actor_2, size,cast_num, dead_actors) do
    IO.puts('Reacehd this')
    image = :egd.create(8*(size+1), 8*(size+1))
    fill1 = :egd.color({250,70,22})
    fill2 = :egd.color({0,33,164})
    fill3 = :egd.color({255,0,0})  
    fill4 = :egd.color({0,0,0})    
    Enum.each received, fn({first,second}) ->
      :egd.rectangle(image, {first*8-2, second*8-2},{first*8,second*8}, fill1)
    end

    [{ first, second }] = prev_actor_2
    :egd.filledEllipse(image,{first*8-2,second*8-2},{first*8,second*8}, fill2)
    [{ first, second }] = prev_actor
    :egd.filledEllipse(image,{first*8-3,second*8-3},{first*8+1,second*8+1}, fill2)
    case terminated do
      0 -> 
        [{ first, second }] = actor
        :egd.filledEllipse(image,{first*8-4,second*8-4},{first*8+2,second*8+2}, fill2)
      1 ->
        [{ first, second }] = actor
        :egd.filledEllipse(image,{first*8-6,second*8-6},{first*8+4,second*8+4}, fill3)
    end

    Enum.each dead_actors, fn({first,second}) ->
      :egd.filledRectangle(image, {first*8-3, second*8-3},{first*8+1,second*8+1}, fill4)
    end

    
    rendered_image = :egd.render(image)
    File.write("live.png",rendered_image)
    File.write("SS/snap#{cast_num}.png",rendered_image)
  end


  

 end