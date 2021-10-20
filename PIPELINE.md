# Pipeline runlog

* Green: w/c 4/10 - ran for testing
* Blue: w/c 18/10 - ran for further testing, shuffling properly, issues 
encountered:
  * 4b349c0 Limiting to a single job, memory limit on node. Review job limits 
  with HPC team, physical memory isn't an issue based on usage mainly being I/O 
  bound
  * 9137e74 Memory scuppers run, but not physically so raising limit. Review 
 optimisations
  * 30d5038 Multi-GPU validation seems to be problematic, review
* Green ??? - ran to incorporate Toms changes, CLI changes 