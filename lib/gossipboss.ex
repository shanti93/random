defmodule Gossip do
 use GenServer

 def init(_) do
    # runs in the server context 
    {:ok, 1}
  end




def boss(nodesize) do
    GenServer.start_link(Gossip,nodesize, name: Master)
end

 ##Main function to handle input arguments - for now implementing gossip line!

def mainfunction(numNodes,topology,algorithm) do
  
  #size =  round(Float.ceil(:math.sqrt(numNodes))) 
  ##Starting boss/hypervisor
  Gossip.boss(numNodes)
 
 case algorithm do
 "gossip" ->
 case topology do
 "line" -> 
 Line.createTopology(numNodes, 0)
 GenServer.cast(Line.actor_name(round(2)),{:message_gossip, :_sending})

 end
 end



 end


  

 end