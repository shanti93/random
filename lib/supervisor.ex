defmodule BossModule do

def callWorker(x,y) do
  {:ok, pid} = Task.Supervisor.start_link(strategy: :one_for_one)
 
 cores = if (x>19), do: 20, else: 1

  childChunk = div(x, cores)
  chunks = Enum.to_list 1..x |> Enum.take_every(childChunk)
 
    
  output = chunks
  |> Enum.map(&Task.Supervisor.async_nolink(pid,fn -> Script.worker(&1,y,childChunk,x) end))
  |> Enum.map(&Task.await(&1, 200000)) 

  end




end