defmodule Script do
use GenServer

def start_link() do
     # runs in the caller context
    GenServer.start_link(__MODULE__, [])
  end


  def init(_) do
    # runs in the server context 
    {:ok, 1}
  end


def worker(x,y,size,maxX) do
    #IO.puts(maxX)
    #IO.puts(size)
    Enum.reduce(x..x+size-1,y, fn(n,k) ->
      res = Enum.reduce(n..n+k-1, 0, fn(x, accum) ->
        (x*x + accum)
        end)
        ressr = :math.sqrt(res)
  if ressr == Float.floor(ressr) do
  IO.puts(n)
  end
  k
     end)
    end

end

