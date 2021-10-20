# Pipeline runlog

For comparison the run directories and the resulting output are saved with 
the date of the next run (for example green.2021-10-20 would be the green in 
situ from 4/10 when the run on 20/10 was started. Bit weird, just easy)

* Green: w/c 4/10 - ran for testing
* Blue: w/c 18/10 - ran for further testing, shuffling properly, issues 
encountered:
  * 4b349c0 Limiting to a single job, memory limit on node. Review job limits 
  with HPC team, physical memory isn't an issue based on usage mainly being I/O 
  bound
  * 9137e74 Memory scuppers run, but not physically so raising limit. Review 
 optimisations
  * 30d5038 Multi-GPU validation seems to be problematic, review
* Green 20/10 - running for seed comparison
  * running with 176gb mem
  * running dual jobs
  * TODO: SEEDS should result in identical networks
* Blue .... - ran to incorporate Toms changes, CLI changes 