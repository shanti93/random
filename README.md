Group Info:

Santhi Sushma Katragadda ñ UFID: 1748 9431
Keerthana Bhuthala ñ UFID: 5251 1292
------------------------------------------------
Instructions:
For Mac/Linux machine
1) Navigate to the project folder
2) Enter command "mix run proj1.exs <arg1> <arg2>"

Input format:
n is arg1
k is arg2

Output format:
First number of sequence for all perfect squares are printed in no definite order as it runs in multiple cores


------------------------------------------------
No.of Machines:
1



-------------------------------------------------

Size of the work Unit: (n/number of cores) - Size of the work unit depends on the given n value and number of cores. For n<14 number of cores is chosen to be 2 for ideal performance and 15 is chosen for n>14 and based on that work unit size varies.

For example - for n = 60, number of cores = 15 => size of work unit = 4

The result of running your program for - mix run proj1.exs 1000000 4 : 

Nothing is displayed


The running time for the above: 

real	0m2.809s
user	0m9.251s
sys	  0m0.181s

The Largest problem we managed to solve: 
Efficiency is achieved by selecting ideal number of cores.
Largest n value - 10000000 k - 2

Result ->
Santhis-MacBook-Air:keerthana_santhi santhisushma$ time mix run proj1.exs 10000000 2
3
20
119
696
4059
23660
137903
4684659
803760

real	0m26.378s
user	1m31.446s
sys	0m0.400s

