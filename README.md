0Project 2
Keerthana  Bhuthala. 				Santhi  Sushma  Katragadda
5251-1292 						1748-9431



Algorithms: 
Gossip, Push-Sum

Topologies:  
Line, Full, Random 2D, Imperfect Line, Torus, 3D


How to run?

<<<<<<< HEAD
“mix run proj2.exs <numNodes“
=======
“mix run proj2.exs  <numNodes>  <topology>  <algorithm>"
>>>>>>> c5f03e8190a6205ed56e2e3dcc0bbfdf6bb48a15


Bonus - Failure Scenario

“mix run proj2.exs  <numNodes>  <topology>  <algorithm> <percentageOfFailedNodesOfFailedNodesFailed>“

Here we considered failedPercent to be percentageOfFailedNodesOfFailedNodes of inactive nodes – where the status of nodes is inactive and cannot start transmission. failedPercent can be given as input by the user and as we enter the failedPercent some of the nodes become inactive and cannot transmit. This mixed topology is given as input to the algorithm.






Maximum manageable network for various topologies

	            Gossip	        Push-Sum
Line	           1024	        512
Full	          100000	        2048
Random 2D Grid	100000	        4096
3D	            100000	        2048
Torus	        100000	        4096
Imperfect Line	1024	        512















